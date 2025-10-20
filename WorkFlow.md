# Workflow

This document describes the intended workflow and how the MCP orchestrates tasks using TDD.

## Steps

1. Run script
   - Execute `start-mcp.sh` with optional `LANGUAGE` env.
2. Discover README.md
   - If the repo has a `README.md`, the server reads it to infer the job.
   - If not present, a minimal `README.md` can be generated in future iterations.
3. Create checklist and scaffold
   - If no `.mcp/*.yaml` exists, the server generates `.mcp/checklist.yaml` based on `README.md`.
   - `CHECKLIST.md` is generated at the repo root with unchecked boxes for each task.
   - If the project is empty, code scaffolding creates `src/tasks/*` stubs and a `src/master.py` orchestrator.
   - If the project is not empty, the server avoids destructive changes and only adds `CHECKLIST.md` and safe stubs.
4. Create/update orchestration file
   - The master file `src/master.py` imports all task functions and calls them in order.
   - Each import and call is preceded by a comment with the source file path for easy RCA.
5. Unit tests per function (TDD)
   - For each function, create a failing unit test first under `tests/`.
   - Implement the function in its own file under `src/tasks/`.
   - When the test passes, wire (or confirm) the function is invoked from `src/master.py`.
6. Continuous TDD
   - The server runs dependency bootstrap and tests.
   - On failures, iterate: fix tests or implementation, then re-run.
7. Concurrency safety
   - Identify opportunities to introduce queues to prevent race conditions when tasks run concurrently.
8. Resilience
   - Add retries for transient network failures.
9. Error handling
   - Introduce exception handling and emit clear, actionable error messages that state the exact issue.
10. Completion semantics
   - A checklist item is considered complete when its unit tests pass and it is wired into `src/master.py`.

## Notes
- Modular design: one file per feature/task under `src/tasks/` improves traceability and RCA.
- Non-destructive defaults: never overwrite user code; generate stubs only when missing.
- Idempotency: re-running the script should not duplicate files or corrupt state.
- Observability: use `CHECKLIST.md` and test results as the source of truth for progress.
