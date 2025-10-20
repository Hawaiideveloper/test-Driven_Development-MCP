from fastapi import FastAPI
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import os
import subprocess
import yaml
import shutil

from pathlib import Path


app = FastAPI(title="TDD MCP Server", version="0.1.0")


class RepoRequest(BaseModel):
    repoPath: str
    dryRun: Optional[bool] = False
    language: Optional[str] = None  # e.g., python, node, go, rust, java, cpp


class MarkRequest(BaseModel):
    repoPath: str
    taskId: str
    checked: bool


class TestRequest(BaseModel):
    repoPath: str
    language: Optional[str] = None
    path: Optional[str] = None  # pytest path/nodeid
    k: Optional[str] = None     # pytest -k expression


def file_exists(path_str: str) -> bool:
    return Path(path_str).exists()


def find_checklists(repo_root: Path) -> List[Path]:
    mcp_dir = repo_root / ".mcp"
    if not mcp_dir.exists() or not mcp_dir.is_dir():
        return []
    return [p for p in mcp_dir.glob("*.y*ml") if p.is_file()]


def read_file_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except Exception:
        return ""


def extract_mcp_job_section(readme_text: str) -> str:
    if not readme_text:
        return ""
    lines = readme_text.splitlines()
    # Look for '## MCP Job' or '### MCP Job'
    start_idx = -1
    for i, line in enumerate(lines):
        lower = line.strip().lower()
        if lower.startswith("## mcp job") or lower.startswith("### mcp job"):
            start_idx = i
            break
    if start_idx != -1:
        chunk: List[str] = []
        for j in range(start_idx + 1, len(lines)):
            if lines[j].startswith("## ") or lines[j].startswith("### "):
                break
            chunk.append(lines[j])
        return "\n".join(chunk).strip()
    # Fallback: the first paragraph after title
    non_empty = [l for l in lines if l.strip()]
    if len(non_empty) > 1:
        return "\n".join(non_empty[1: min(6, len(non_empty))])
    return ""


def generate_checklist_yaml(repo_name: str, readme_description: str, language: Optional[str]) -> str:
    job_description = readme_description or f"Automated job for {repo_name}."
    data = {
        "version": 1,
        "metadata": {
            "name": f"{repo_name} Checklist",
            "description": "Tasks for the MCP agent to perform in this repository",
            "owner": "auto-generated",
            "default_branch": "main",
            "default_language": (language or "python"),
        },
        "permissions": {
            "allow_shell": True,
            "allow_git": True,
            "allow_file_edits": True,
            "shell_whitelist": ["npm", "pnpm", "yarn", "pytest", "go", "make"],
            "edit_path_allowlist": [
                "src/**",
                "tests/**",
                "README.md",
                "package.json",
                "pyproject.toml",
            ],
        },
        "tasks": [
            {
                "id": "bootstrap-deps",
                "title": "Install dependencies",
                "description": "Ensure dependencies are installed for the project language",
                "steps": [
                    {"when": "file_exists(\"package.json\")", "run": "npm ci"},
                    {
                        "when": "file_exists(\"pyproject.toml\")",
                        "run": "pip install -U pip && pip install -e .",
                    },
                    {
                        "when": "file_exists(\"requirements.txt\")",
                        "run": "pip install -U pip && pip install -r requirements.txt",
                    },
                    {"when": "file_exists(\"go.mod\")", "run": "go mod download"},
                ],
                "success_criteria": [
                    "No non-zero exit codes from install steps",
                ],
            },
            {
                "id": "run-tests",
                "title": "Run test suite",
                "description": "Execute tests to validate current state",
                "steps": [
                    {"when": "file_exists(\"package.json\")", "run": "npm test --silent"},
                    {
                        "when": "file_exists(\"pyproject.toml\") or file_exists(\"pytest.ini\")",
                        "run": "pytest -q",
                    },
                    {"when": "file_exists(\"go.mod\")", "run": "go test ./..."},
                ],
                "success_criteria": [
                    "All tests pass (zero failures)",
                    "Process exit code == 0",
                ],
            },
            {
                "id": "job-from-readme",
                "title": "Execute the primary job described in README",
                "description": job_description.replace("\n", " "),
                "steps": [
                    {"read": "README.md"},
                    {"parse": "mcp_section(\"MCP Job\")"},
                    {"run": "echo \"Executing job steps...\""},
                ],
                "success_criteria": [
                    "Marked completion condition in README achieved",
                    "Exit code == 0",
                ],
            },
        ],
    }
    return yaml.safe_dump(data, sort_keys=False)


def ensure_checklist(repo_root: Path, dry_run: bool = False, language: Optional[str] = None) -> dict:
    found = find_checklists(repo_root)
    if found:
        return {
            "created": False,
            "path": [str(p) for p in found],
            "message": f"Found {len(found)} checklist(s)",
        }
    readme = read_file_text(repo_root / "README.md")
    desc = extract_mcp_job_section(readme)
    yaml_text = generate_checklist_yaml(repo_root.name, desc, language)
    out_dir = repo_root / ".mcp"
    out_path = out_dir / "checklist.yaml"
    if dry_run:
        return {
            "created": True,
            "path": str(out_path),
            "dryRun": True,
            "content": yaml_text,
        }
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path.write_text(yaml_text, encoding="utf-8")
    return {"created": True, "path": str(out_path), "dryRun": False}


def load_checklist(repo_root: Path) -> Optional[Dict[str, Any]]:
    files = find_checklists(repo_root)
    if not files:
        return None
    # Prefer checklist.yaml
    preferred = None
    for p in files:
        if p.name == "checklist.yaml":
            preferred = p
            break
    path = preferred or files[0]
    try:
        with open(path, "r", encoding="utf-8") as f:
            return yaml.safe_load(f)
    except Exception:
        return None


def write_checklist_md(repo_root: Path, checklist: Dict[str, Any]) -> Path:
    tasks = checklist.get("tasks", [])
    lines: List[str] = []
    lines.append("# CHECKLIST")
    meta = checklist.get("metadata", {})
    if meta:
        name = meta.get("name")
        desc = meta.get("description")
        if name:
            lines.append("")
            lines.append(f"Project: {name}")
        if desc:
            lines.append("")
            lines.append(desc)
    lines.append("")
    lines.append("## Tasks")
    for t in tasks:
        tid = t.get("id", "task")
        title = t.get("title", tid)
        description = t.get("description", "")
        lines.append(f"- [ ] {title} ({tid})")
        if description:
            lines.append(f"  - {description}")
        steps = t.get("steps", [])
        if isinstance(steps, list) and steps:
            lines.append("  - Steps:")
            for s in steps:
                # Render generic summary for each step
                if isinstance(s, dict):
                    if "run" in s:
                        lines.append(f"    - run: `{s['run']}`")
                    elif "read" in s:
                        lines.append(f"    - read: `{s['read']}`")
                    elif "parse" in s:
                        lines.append(f"    - parse: `{s['parse']}`")
                    else:
                        lines.append("    - step")
                else:
                    lines.append("    - step")
    content = "\n".join(lines) + "\n"
    out_path = repo_root / "CHECKLIST.md"
    out_path.write_text(content, encoding="utf-8")
    return out_path


def regenerate_checklist(repo_root: Path, language: Optional[str]) -> Dict[str, Any]:
    readme = read_file_text(repo_root / "README.md")
    desc = extract_mcp_job_section(readme)
    yaml_text = generate_checklist_yaml(repo_root.name, desc, language)
    out_dir = repo_root / ".mcp"
    out_path = out_dir / "checklist.yaml"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path.write_text(yaml_text, encoding="utf-8")
    return {"path": str(out_path)}


def sanitize_symbol(name: str) -> str:
    out = []
    for ch in name:
        if ch.isalnum() or ch == "_":
            out.append(ch)
        elif ch in "- ":
            out.append("_")
        # else drop other chars
    sym = "".join(out)
    if sym and sym[0].isdigit():
        sym = f"task_{sym}"
    return sym or "task"


def scaffold_from_checklist(repo_root: Path) -> Dict[str, Any]:
    checklist = load_checklist(repo_root)
    if not checklist:
        return {"ok": False, "error": "No checklist loaded"}
    # Always write CHECKLIST.md
    md_path = write_checklist_md(repo_root, checklist)
    tasks = checklist.get("tasks", [])
    tasks_dir = repo_root / "src" / "tasks"
    tasks_dir.mkdir(parents=True, exist_ok=True)
    # ensure package init for tasks
    (tasks_dir / "__init__.py").write_text("", encoding="utf-8")

    created_files: List[str] = [str(md_path)]
    call_entries: List[str] = []
    call_lines: List[str] = []
    for t in tasks:
      tid = t.get("id", "task")
      title = t.get("title", tid)
      func_name = f"run_{sanitize_symbol(tid)}"
      file_name = f"{sanitize_symbol(tid)}.py"
      file_path = tasks_dir / file_name
      if not file_path.exists():
          file_content = (
              f"\"\"\"\nTask: {title}\nID: {tid}\nThis function should implement the checklist item logic.\n\"\"\"\n"
              f"def {func_name}() -> None:\n"
              f"    \"\"\"Entry point for task '{tid}'.\n"
              f"    Implement the logic and add tests under tests/.\n"
              f"    \"\"\"\n"
              f"    pass\n"
          )
          file_path.write_text(file_content, encoding="utf-8")
          created_files.append(str(file_path))
      # Master call entry with comment referencing file location
      call_entries.append(
          f"# Task {tid} implementation at src/tasks/{file_name}\nfrom tasks.{sanitize_symbol(tid)} import {func_name}"
      )
      call_lines.append(f"    # calls src/tasks/{file_name}")
      call_lines.append(f"    {func_name}()")

    # Create master file
    master_path = repo_root / "src" / "master.py"
    imports_block = "\n".join(call_entries)
    calls_block = "\n".join(call_lines)
    master_content = (
        f"# Master entrypoint that calls each task function in order.\n"
        f"{imports_block}\n\n"
        f"def run_all_tasks() -> None:\n"
        f"    \"\"\"Run all checklist tasks sequentially.\n"
        f"    Each call is preceded by a comment indicating the source file path.\n"
        f"    \"\"\"\n"
        f"{calls_block if calls_block else '    pass'}\n"
    )
    master_path.parent.mkdir(parents=True, exist_ok=True)
    master_path.write_text(master_content, encoding="utf-8")
    created_files.append(str(master_path))

    return {"ok": True, "created": created_files, "checklist_md": str(md_path)}


def mark_checklist_item(repo_root: Path, task_id: str, checked: bool) -> Dict[str, Any]:
    md_path = repo_root / "CHECKLIST.md"
    if not md_path.exists():
        return {"ok": False, "error": "CHECKLIST.md not found"}
    content = md_path.read_text(encoding="utf-8").splitlines()
    needle = f"({task_id})"
    updated = []
    changed = False
    for line in content:
        if line.strip().startswith("- [") and needle in line:
            if checked:
                newline = line.replace("- [ ]", "- [x]")
            else:
                newline = line.replace("- [x]", "- [ ]")
            if newline != line:
                changed = True
            updated.append(newline)
        else:
            updated.append(line)
    if changed:
        md_path.write_text("\n".join(updated) + "\n", encoding="utf-8")
    return {"ok": True, "changed": changed, "path": str(md_path)}


def list_task_status(repo_root: Path) -> Dict[str, Any]:
    checklist = load_checklist(repo_root) or {"tasks": []}
    ids = [t.get("id", "") for t in checklist.get("tasks", [])]
    tasks_dir = repo_root / "src" / "tasks"
    files = []
    if tasks_dir.exists():
        for p in tasks_dir.glob("*.py"):
            files.append(p.name)
    master = repo_root / "src" / "master.py"
    master_content = master.read_text(encoding="utf-8") if master.exists() else ""
    items = []
    for tid in ids:
        sym = sanitize_symbol(tid)
        file_name = f"{sym}.py"
        present = file_name in files
        imported = f"from tasks.{sym} import run_{sym}" in master_content
        called = f"run_{sym}()" in master_content
        items.append({"id": tid, "file": file_name, "present": present, "imported": imported, "called": called})
    return {"tasks": items, "masterExists": master.exists()}


def run_cmd(cmd: List[str], cwd: Path) -> dict:
    try:
        completed = subprocess.run(
            cmd,
            cwd=str(cwd),
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=900,
        )
        return {"cmd": cmd, "code": completed.returncode, "output": completed.stdout}
    except subprocess.TimeoutExpired as e:
        return {"cmd": cmd, "code": -1, "output": f"Timeout: {str(e)}"}
    except Exception as e:
        return {"cmd": cmd, "code": -1, "output": f"Error: {str(e)}"}


def command_available(command: str) -> bool:
    return shutil.which(command) is not None


def bootstrap_and_test(repo_root: Path, language: Optional[str]) -> dict:
    results: List[dict] = []
    # If language specified, prefer that flow
    lang = (language or "").lower().strip()
    if lang in {"python", "py"}:
        results.append(run_cmd(["pip", "install", "-U", "pip"], repo_root))
        # Prefer pyproject if exists; else requirements.txt
        if file_exists(repo_root / "pyproject.toml"):
            results.append(run_cmd(["pip", "install", "-e", "."], repo_root))
        elif file_exists(repo_root / "requirements.txt"):
            results.append(run_cmd(["pip", "install", "-r", "requirements.txt"], repo_root))
        if command_available("pytest"):
            results.append(run_cmd(["pytest", "-q"], repo_root))
        return {"ok": all(r.get("code", 1) == 0 for r in results) if results else True, "results": results}
    if lang in {"javascript", "node", "js"}:
        if not command_available("npm"):
            return {"ok": False, "results": results, "error": "npm not available in container"}
        if file_exists(repo_root / "package.json"):
            results.append(run_cmd(["npm", "ci"], repo_root))
            results.append(run_cmd(["npm", "test", "--silent"], repo_root))
        return {"ok": all(r.get("code", 1) == 0 for r in results) if results else True, "results": results}
    if lang in {"go", "golang"}:
        if file_exists(repo_root / "go.mod"):
            results.append(run_cmd(["go", "mod", "download"], repo_root))
            results.append(run_cmd(["go", "test", "./..."], repo_root))
        return {"ok": all(r.get("code", 1) == 0 for r in results) if results else True, "results": results}
    if lang in {"rust"}:
        if not command_available("cargo"):
            return {"ok": False, "results": results, "error": "cargo not available in container"}
        results.append(run_cmd(["cargo", "test"], repo_root))
        return {"ok": all(r.get("code", 1) == 0 for r in results) if results else True, "results": results}
    if lang in {"java"}:
        if not command_available("mvn") and not command_available("gradle"):
            return {"ok": False, "results": results, "error": "Java build tool (mvn/gradle) not available in container"}
        if file_exists(repo_root / "pom.xml"):
            results.append(run_cmd(["mvn", "-q", "-DskipTests=false", "test"], repo_root))
        elif file_exists(repo_root / "build.gradle") or file_exists(repo_root / "build.gradle.kts"):
            results.append(run_cmd(["gradle", "test"], repo_root))
        return {"ok": all(r.get("code", 1) == 0 for r in results) if results else True, "results": results}
    if lang in {"cpp", "c++"}:
        # Placeholder: requires project-specific build system
        return {"ok": False, "results": results, "error": "C++ flow not implemented in container"}

    # Fallback: auto-detect by files
    if file_exists(repo_root / "package.json") and command_available("npm"):
        results.append(run_cmd(["npm", "ci"], repo_root))
        results.append(run_cmd(["npm", "test", "--silent"], repo_root))
    if file_exists(repo_root / "pyproject.toml") or file_exists(repo_root / "requirements.txt"):
        results.append(run_cmd(["pip", "install", "-U", "pip"], repo_root))
        if file_exists(repo_root / "pyproject.toml"):
            results.append(run_cmd(["pip", "install", "-e", "."], repo_root))
        elif file_exists(repo_root / "requirements.txt"):
            results.append(run_cmd(["pip", "install", "-r", "requirements.txt"], repo_root))
        if command_available("pytest"):
            results.append(run_cmd(["pytest", "-q"], repo_root))
    if file_exists(repo_root / "go.mod"):
        results.append(run_cmd(["go", "mod", "download"], repo_root))
        results.append(run_cmd(["go", "test", "./..."], repo_root))

    overall_ok = all(r.get("code", 1) == 0 for r in results) if results else True
    return {"ok": overall_ok, "results": results}


@app.get("/health")
def health():
    return {"ok": True}


@app.get("/version")
def version():
    return {"name": "TDD MCP Server", "version": app.version}


@app.post("/introduce")
def introduce(req: RepoRequest):
    repo = Path(req.repoPath).resolve()
    found = find_checklists(repo)
    return {
        "message": "Hello from TDD MCP Server. I can manage checklists and kick off TDD.",
        "repo": str(repo),
        "checklists": [str(p) for p in found],
        "hasChecklist": len(found) > 0,
        "instructions": "Use /ensure-checklist to create one if missing, or /tdd/start to begin.",
    }


@app.post("/checklist")
def get_checklist(req: RepoRequest):
    repo = Path(req.repoPath).resolve()
    data = load_checklist(repo)
    md_path = repo / "CHECKLIST.md"
    md_exists = md_path.exists()
    md_preview = md_path.read_text(encoding="utf-8")[:2000] if md_exists else None
    return {"yaml": data, "checklistMdPath": str(md_path), "checklistMdExists": md_exists, "checklistMdPreview": md_preview}


@app.post("/checklist/refresh")
def refresh_checklist(req: RepoRequest):
    repo = Path(req.repoPath).resolve()
    regen = regenerate_checklist(repo, req.language)
    data = load_checklist(repo) or {"tasks": []}
    md = write_checklist_md(repo, data)
    return {"yamlPath": regen["path"], "checklistMd": str(md)}


@app.post("/ensure-checklist")
def ensure(req: RepoRequest):
    repo = Path(req.repoPath).resolve()
    lang = (req.language or None)
    return ensure_checklist(repo, bool(req.dryRun), lang)


@app.post("/tdd/start")
def tdd_start(req: RepoRequest):
    repo = Path(req.repoPath).resolve()
    lang = (req.language or None)
    return bootstrap_and_test(repo, lang)


@app.post("/scaffold")
def scaffold(req: RepoRequest):
    repo = Path(req.repoPath).resolve()
    return scaffold_from_checklist(repo)


@app.post("/checklist/mark")
def checklist_mark(req: MarkRequest):
    repo = Path(req.repoPath).resolve()
    return mark_checklist_item(repo, req.taskId, req.checked)


@app.post("/tasks/status")
def tasks_status(req: RepoRequest):
    repo = Path(req.repoPath).resolve()
    return list_task_status(repo)


@app.post("/tests/run")
def tests_run(req: TestRequest):
    repo = Path(req.repoPath).resolve()
    # base bootstrap
    bootstrap = bootstrap_and_test(repo, req.language)
    # focused run if provided
    if req.path or req.k:
        args: List[str] = ["pytest", "-q"]
        if req.k:
            args += ["-k", req.k]
        if req.path:
            args += [req.path]
        focused = run_cmd(args, repo)
        bootstrap["focused"] = focused
    return bootstrap


@app.post("/orchestrate/run")
def orchestrate_run(req: RepoRequest):
    repo = Path(req.repoPath).resolve()
    cmd = [
        "python",
        "-c",
        "from src.master import run_all_tasks; run_all_tasks()",
    ]
    return run_cmd(cmd, repo)


