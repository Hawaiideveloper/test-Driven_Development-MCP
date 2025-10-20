from fastapi import FastAPI
from pydantic import BaseModel
from typing import List, Optional
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


