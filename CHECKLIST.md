# CHECKLIST

Project: work Checklist

Tasks for the MCP agent to perform in this repository

## Tasks
- [ ] Install dependencies (bootstrap-deps)
  - Ensure dependencies are installed for the project language
  - Steps:
    - run: `npm ci`
    - run: `pip install -U pip && pip install -e .`
    - run: `pip install -U pip && pip install -r requirements.txt`
    - run: `go mod download`
- [ ] Run test suite (run-tests)
  - Execute tests to validate current state
  - Steps:
    - run: `npm test --silent`
    - run: `pytest -q`
    - run: `go test ./...`
- [ ] Execute the primary job described in README (job-from-readme)
  - Local TDD-focused MCP server that discovers or generates repo checklists and kicks off bootstrap/tests. ## Table of Contents - [Overview](#overview) - [Quick Start (Docker)](#quick-start-docker) - [Language Selection](#language-selection)
  - Steps:
    - read: `README.md`
    - parse: `mcp_section("MCP Job")`
    - run: `echo "Executing job steps..."`
