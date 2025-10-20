#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

function parseArgs(argv) {
  const args = { flags: {}, positionals: [] };
  for (let i = 2; i < argv.length; i += 1) {
    const token = argv[i];
    if (token.startsWith('--')) {
      const [key, value] = token.split('=');
      const normalizedKey = key.replace(/^--/, '');
      if (typeof value === 'string') {
        args.flags[normalizedKey] = value;
      } else if (normalizedKey === 'dry-run' || normalizedKey === 'dryrun') {
        args.flags['dry-run'] = true;
      } else if (normalizedKey === 'help' || normalizedKey === 'h') {
        args.flags['help'] = true;
      } else if (normalizedKey === 'repo') {
        // Value might be in the next arg
        const maybe = argv[i + 1];
        if (maybe && !maybe.startsWith('-')) {
          args.flags['repo'] = maybe;
          i += 1;
        } else {
          args.flags['repo'] = '';
        }
      } else {
        args.flags[normalizedKey] = true;
      }
    } else {
      args.positionals.push(token);
    }
  }
  return args;
}

function resolveRepoPath(args) {
  const fromFlag = args.flags.repo;
  const fromEnv = process.env.MCP_REPO_PATH;
  const fromPositional = args.positionals[0];
  const resolved = fromFlag || fromEnv || fromPositional || process.cwd();
  return path.resolve(resolved);
}

function fileExistsSync(filePath) {
  try {
    fs.accessSync(filePath, fs.constants.F_OK);
    return true;
  } catch (_) {
    return false;
  }
}

function readFileSafe(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8');
  } catch (_) {
    return '';
  }
}

function findChecklists(mcpDirPath) {
  if (!fileExistsSync(mcpDirPath)) return [];
  const entries = fs.readdirSync(mcpDirPath, { withFileTypes: true });
  const yamlFiles = entries
    .filter((d) => d.isFile())
    .map((d) => d.name)
    .filter((name) => name.endsWith('.yaml') || name.endsWith('.yml'))
    .map((name) => path.join(mcpDirPath, name));
  return yamlFiles;
}

function extractMcpJobSection(readmeContent) {
  if (!readmeContent) return '';
  const lines = readmeContent.split(/\r?\n/);
  const startIdx = lines.findIndex((l) => /^(##|###)\s+MCP\s+Job/i.test(l));
  if (startIdx !== -1) {
    let i = startIdx + 1;
    const chunk = [];
    for (; i < lines.length; i += 1) {
      if (/^##\s+|^###\s+/.test(lines[i])) break;
      chunk.push(lines[i]);
    }
    return chunk.join('\n').trim();
  }
  // Fallback: use first non-empty paragraph after title
  const nonEmpty = lines.filter((l) => l.trim().length > 0);
  if (nonEmpty.length > 1) {
    return nonEmpty.slice(1, Math.min(6, nonEmpty.length)).join('\n');
  }
  return '';
}

function generateChecklistYaml({ repoName, readmeDescription }) {
  const jobDescription = readmeDescription || `Automated job for ${repoName}.`;
  const yaml = `version: 1\n` +
`metadata:\n` +
`  name: ${repoName} Checklist\n` +
`  description: Tasks for the MCP agent to perform in this repository\n` +
`  owner: auto-generated\n` +
`  default_branch: main\n` +
`\n` +
`permissions:\n` +
`  allow_shell: true\n` +
`  allow_git: true\n` +
`  allow_file_edits: true\n` +
`  shell_whitelist:\n` +
`    - npm\n` +
`    - pnpm\n` +
`    - yarn\n` +
`    - pytest\n` +
`    - go\n` +
`    - make\n` +
`  edit_path_allowlist:\n` +
`    - src/**\n` +
`    - tests/**\n` +
`    - README.md\n` +
`    - package.json\n` +
`    - pyproject.toml\n` +
`\n` +
`tasks:\n` +
`  - id: bootstrap-deps\n` +
`    title: Install dependencies\n` +
`    description: Ensure dependencies are installed for the project language\n` +
`    steps:\n` +
`      - when: file_exists(\"package.json\")\n` +
`        run: npm ci\n` +
`      - when: file_exists(\"pyproject.toml\")\n` +
`        run: pip install -U pip && pip install -e .\n` +
`      - when: file_exists(\"requirements.txt\")\n` +
`        run: pip install -U pip && pip install -r requirements.txt\n` +
`      - when: file_exists(\"go.mod\")\n` +
`        run: go mod download\n` +
`    success_criteria:\n` +
`      - No non-zero exit codes from install steps\n` +
`\n` +
`  - id: run-tests\n` +
`    title: Run test suite\n` +
`    description: Execute tests to validate current state\n` +
`    steps:\n` +
`      - when: file_exists(\"package.json\")\n` +
`        run: npm test --silent\n` +
`      - when: file_exists(\"pyproject.toml\") or file_exists(\"pytest.ini\")\n` +
`        run: pytest -q\n` +
`      - when: file_exists(\"go.mod\")\n` +
`        run: go test ./...\n` +
`    success_criteria:\n` +
`      - All tests pass (zero failures)\n` +
`      - Process exit code == 0\n` +
`\n` +
`  - id: job-from-readme\n` +
`    title: Execute the primary job described in README\n` +
`    description: ${jobDescription.replace(/\n/g, ' ')}\n` +
`    steps:\n` +
`      - read: README.md\n` +
`      - parse: mcp_section(\"MCP Job\")\n` +
`      - run: echo \"Executing job steps...\"\n` +
`    success_criteria:\n` +
`      - Marked completion condition in README achieved\n` +
`      - Exit code == 0\n`;
  return yaml;
}

function ensureDirSync(dirPath) {
  if (!fileExistsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

function printHelp() {
  console.log(`Usage: mcp-checklist [--repo <path>] [--dry-run]\n\n` +
    `Options:\n` +
    `  --repo <path>   Absolute or relative path to repository (defaults to CWD or MCP_REPO_PATH)\n` +
    `  --dry-run       Do not write files; print intended actions\n` +
    `  --help          Show this help message\n`);
}

function main() {
  const args = parseArgs(process.argv);
  if (args.flags.help) {
    printHelp();
    process.exit(0);
  }

  const repoPath = resolveRepoPath(args);
  const dryRun = Boolean(args.flags['dry-run']);
  const mcpDir = path.join(repoPath, '.mcp');

  console.log(`[mcp-checklist] Repo: ${repoPath}`);
  const found = findChecklists(mcpDir);
  if (found.length > 0) {
    console.log(`[mcp-checklist] Found ${found.length} checklist(s):`);
    for (const file of found) {
      console.log(` - ${file}`);
    }
    process.exit(0);
  }

  console.log('[mcp-checklist] No checklist found. Generating from README.md...');
  const readmePath = path.join(repoPath, 'README.md');
  const readme = readFileSafe(readmePath);
  const readmeSection = extractMcpJobSection(readme);
  const repoName = path.basename(repoPath);
  const yaml = generateChecklistYaml({ repoName, readmeDescription: readmeSection });

  const outDir = mcpDir;
  const outPath = path.join(outDir, 'checklist.yaml');
  if (dryRun) {
    console.log('[mcp-checklist] DRY RUN: would create .mcp directory and write checklist.yaml with content:');
    console.log('---');
    console.log(yaml);
    console.log('---');
  } else {
    ensureDirSync(outDir);
    fs.writeFileSync(outPath, yaml, 'utf8');
    console.log(`[mcp-checklist] Wrote ${outPath}`);
  }

  process.exit(0);
}

main();


