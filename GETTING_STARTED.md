# Getting Started

This guide shows how to run the MCP server locally in Docker or connect to a Kubernetes deployment, and quickly bootstrap a checklist so an agent can begin TDD work.

## 🚀 Quick Start Options

### Option 1: Kubernetes (Recommended)

If you have the service deployed in Kubernetes:

```bash
# Clone repository for connection utilities
git clone https://github.com/Hawaiideveloper/test-Driven_Development-MCP.git
cd test-Driven_Development-MCP

# Use the connection script
./connect-k8-mcp-to-local.sh

# Or connect directly to NodePort
curl http://<NODE_IP>:30234/health
curl -X POST http://<NODE_IP>:30234/introduce \
  -H "Content-Type: application/json" \
  -d '{"repoPath": "/work"}'
```

The Kubernetes deployment:
- Runs on NodePort `30234` (maps to internal port `63777`)
- Uses private GHCR image with secure image pull secrets
- Accessible from any cluster node IP
- Full documentation at `http://<NODE_IP>:30234/docs`

### Option 2: Local Docker

From your repo root:

```bash
LANGUAGE=python ./start-mcp.sh .
```

What this does:
- Builds and runs a local Docker container for the FastAPI server on `http://localhost:63777`
- Mounts your repo into the container at `/work`
- Introduces itself and either creates a checklist or starts the TDD bootstrap/tests

If you omit the argument, it defaults to your current directory.

## Endpoints

- `GET /health`: health check
- `POST /introduce` with body `{ "repoPath": "/work" }`: say hello and detect checklist
- `POST /ensure-checklist` with body `{ "repoPath": "/work", "dryRun": false, "language": "python|node|go|rust|java|cpp" }`
- `POST /tdd/start` with body `{ "repoPath": "/work", "language": "python|node|go|rust|java|cpp" }`

Use any HTTP client or your editor’s HTTP tools.

## Connect from common tools

### VS Code
- Run `./start-mcp.sh` to start the server
- Use the built-in REST client extensions (e.g., REST Client) or Thunder Client to hit `http://localhost:8000`
- You can create `.http` files with requests to `/introduce`, `/ensure-checklist`, and `/tdd/start`

### Cursor
- Start the server with `LANGUAGE=python ./start-mcp.sh`
- Use Cursor’s terminal to curl the endpoints or configure a task to call `http://localhost:8000`
- Point the agent at your repo path; it will pick up checklists under `.mcp`

### Claude
- Start the server with `LANGUAGE=python ./start-mcp.sh`
- If using Claude Desktop or Web + local tools, call the endpoints via curl from your terminal and paste results back
- If using MCP tooling integration, set the base URL to `http://localhost:8000`

### Miscellaneous
- Any HTTP client (curl/httpie/Postman) can interact with the API
- Ensure Docker Desktop is running

## Script reference

The quick-start script `start-mcp.sh`:
- Builds the Docker image
- Launches the container and exposes port 63777
- Calls `/introduce` then either `/ensure-checklist` or `/tdd/start`

Usage:

```bash
chmod +x start-mcp.sh
LANGUAGE=python ./start-mcp.sh /absolute/or/relative/path/to/repo
```

If your repo already contains `.mcp/*.yaml`, the server will skip generation and begin the TDD bootstrap/tests.

## Troubleshooting

- Ensure Docker Desktop is running and port 63777 is free
- If dependencies are large, first run may take a while
- Use `docker logs tdd-mcp -f` to view server logs
- Rebuild image after code changes: `docker build -t tdd-mcp:local .`


