The object of this repo is to look at checklists and to complete those checklists using a test driven development approach.

Say, I create a new repo, and I create a master checklist and that list is 1000 items long.  I should be able to give that list to the AI the AI continuously test and implement a main entry point into multiple modules for each item on the checklist by doing so this enables both humans and the AI to troubleshoot patch and update individual files that are then called in the main entry point program instead of having a massive file with millions of lines of code.


This is useful because when you combine it with this prompt, it should be able to complete the list and if there's an issue quickly identify it and keep testing it until it passes


```text
All projects must have an env file and a template env file.  It is required that all variables be parameterized there so that adjustments can be made
Ensure that we have a dependency file that allows new users to start using one command so that the system runs on the first go
We need to use Docker so that we can test with clean instances after each run.

If a run fails the testing stops, the adjustment is made, the patch is applied and it re-runs the module.
It is preferred to use a virtual env within the docker so that things can be installed quickly using a dependency file and in some cases but not all we may need to skip a test due to a missing module which we will come back to 
1) Write a focused unit test that fails (one test per item).
2) Implement the feature in a dedicated module/file and expose it via the MCP “master” entrypoint (FastAPI/MCP server/webserver) or whatever the endpoint the user is asking for in the checklist.
3) Run the full test suite; fix until green.
4) Check off the item in MASTER_CHECKLIST.md.
5) Proceed to the next item and repeat.
* Structure:
* One file per function/feature (modular), plus a master file that imports and wires them (e.g., FastAPI endpoints and MCP tool registry).
* Keep tests atomic and fast; use offline fixtures for external pages (status/docs/OpenAPI).
* Quality gates every step:
* After checking a new box, re-run all prior tests to ensure no regressions.
Nothing is done unless our test coverage equals 100% so do not stop testing and implementating until we reach 100% coverage and nothing is left unchecked.
* Gate network calls (status, [program name here) behind preflight checks; use degraded mode when needed.
* Enforce idempotency, rate limiting, and backoff where applicable.
* Completion rule:
* An item is “done” only when its unit test(s) pass and the feature is callable through the master entrypoint (CLI/HTTP/MCP) etc.
* Continue until 100% of checklist items are checked and the full test suite passes.
After all tests are complete, a helm chart must be created so that the final product can be deployed as a microservice or api into a kubernetes cluster
```

