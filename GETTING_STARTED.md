# Getting Started

> **🎯 Local Development Focus**: TDD-MCP runs lo## API Endpoints

**Base URL:** `http://localhost:63777`

- `GET /health` - Health check
- `GET /version` - Server version
- `GET /docs` - Interactive API documentation (Swagger UI)
- `POST /introduce` - Introduce repository to server
  - Body: `{ "repoPath": "/work" }`
- `POST /ensure-checklist` - Generate or verify checklist
  - Body: `{ "repoPath": "/work", "dryRun": false, "language": "python|node|go|rust|java|cpp" }`
- `POST /tdd/start` - Begin TDD workflow
  - Body: `{ "repoPath": "/work", "language": "python|node|go|rust|java|cpp" }`

**Quick Test:**
```bash
curl http://localhost:63777/health
curl http://localhost:63777/version
```a Docker with your repository mounted as a volume. This ensures the server has direct filesystem access to read and write your files - no remote deployment complexity needed.

This guide shows how to run the MCP server locally in Docker and quickly bootstrap a checklist so you can begin TDD work.

## 🚀 Quick Start Options

### Option 1: Local Docker (Recommended)

**Simplest way to get started:**

```bash
# Clone TDD-MCP repository
git clone https://github.com/Hawaiideveloper/test-Driven_Development-MCP.git
cd test-Driven_Development-MCP

# Start server for this repository
LANGUAGE=python ./start-mcp.sh .

# Or for any other repository
LANGUAGE=python ./start-mcp.sh /path/to/your/project
```

**What happens automatically:**
- 🐳 Builds and runs Docker container on `http://localhost:63777`
- 📁 Mounts your repository at `/work` inside container
- � Server introduces itself to your repository
- � Creates checklist (if needed) or starts TDD workflow
- ✅ Server has full read/write access to your files

**Why local Docker?**
- Direct filesystem access - no remote complexity
- Isolated environment - no dependency conflicts
- Reproducible builds - same behavior everywhere
- Simple cleanup - just stop the container

### Option 2: Quick Repository Helper

For instant TDD setup in any repository:

```bash
# One-liner setup
curl -sSL https://raw.githubusercontent.com/Hawaiideveloper/test-Driven_Development-MCP/main/tdd-helper.sh -o tdd-helper.sh && chmod +x tdd-helper.sh && ./tdd-helper.sh
```

**What the helper script does:**
- 🔍 Auto-detects existing TDD-MCP Docker containers
- � Introduces your repository to TDD-MCP
- 🎯 Detects project language automatically
- 📋 Generates `CHECKLIST.md` and `.mcp/checklist.yaml`
- ⚙️ Saves configuration in `.tdd-mcp-config`

### Option 3: Manual Docker Run

Run TDD-MCP directly with Docker commands:

```bash
# From your repository directory
docker run -d -p 63777:63777 \
  -v "$(pwd):/work" \
  --name TDD-MCP \
  ghcr.io/hawaiideveloper/tdd-mcp:latest

# Server is now available at http://localhost:63777
curl http://localhost:63777/health
```

## Endpoints

- `GET /health`: health check
- `POST /introduce` with body `{ "repoPath": "/work" }`: say hello and detect checklist
- `POST /ensure-checklist` with body `{ "repoPath": "/work", "dryRun": false, "language": "python|node|go|rust|java|cpp" }`
- `POST /tdd/start` with body `{ "repoPath": "/work", "language": "python|node|go|rust|java|cpp" }`

Use any HTTP client or your editor’s HTTP tools.

## Using TDD-MCP from Your Editor

### VS Code

**Three ways to interact with TDD-MCP (no extensions required):**

1. **Integrated Terminal** (simplest):
   ```bash
   # From VS Code terminal
   curl http://localhost:63777/health
   curl -X POST http://localhost:63777/introduce \
     -H "Content-Type: application/json" \
     -d '{"repoPath": "/work"}'
   ```

2. **REST Client Extension** (optional):
   - Install REST Client extension (if desired)
   - Create `.http` file with requests:
   ```http
   ### Health Check
   GET http://localhost:63777/health
   
   ### Introduce Repository
   POST http://localhost:63777/introduce
   Content-Type: application/json
   
   {
     "repoPath": "/work"
   }
   ```

3. **Tasks Configuration**:
   - Add to `.vscode/tasks.json`:
   ```json
   {
     "version": "2.0.0",
     "tasks": [
       {
         "label": "TDD-MCP: Introduce",
         "type": "shell",
         "command": "curl -X POST http://localhost:63777/introduce -H 'Content-Type: application/json' -d '{\"repoPath\": \"/work\"}'"
       }
     ]
   }
   ```

### Cursor

- Start server: `LANGUAGE=python ./start-mcp.sh .`
- Use integrated terminal for curl commands
- Access API documentation at `http://localhost:63777/docs`

### Claude Desktop

Configure Claude Desktop to use TDD-MCP:

1. Edit `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS)
2. Add TDD-MCP configuration:
```json
{
  "mcpServers": {
    "tdd-mcp": {
      "command": "curl",
      "args": [
        "-X", "POST",
        "http://localhost:63777/mcp",
        "-H", "Content-Type: application/json",
        "-d", "@-"
      ]
    }
  }
}
```

### Any HTTP Client

TDD-MCP works with any HTTP client:
- **curl** - Command line (always available)
- **httpie** - Modern command line HTTP client
- **Postman** - GUI HTTP client
- **Insomnia** - REST client
- **Thunder Client** - VS Code extension
- **Swagger UI** - Built-in at `http://localhost:63777/docs`

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

## Script Reference

### start-mcp.sh

The main script for launching TDD-MCP locally:

```bash
# Basic usage
LANGUAGE=python ./start-mcp.sh /path/to/repo

# Interactive (prompts for language)
./start-mcp.sh /path/to/repo

# Current directory
LANGUAGE=python ./start-mcp.sh .
```

**What it does:**
1. Builds Docker image (if needed)
2. Launches container on port 63777
3. Mounts your repository at `/work`
4. Calls `/introduce` to detect repository structure
5. Calls `/ensure-checklist` or `/tdd/start` based on existing checklists

**Supported Languages:**
- `python` - Python projects
- `node` - Node.js/JavaScript projects
- `go` - Go projects
- `rust` - Rust projects
- `java` - Java projects
- `cpp` - C++ projects

### tdd-helper.sh

Quick setup script for any repository:

```bash
# Download and run
curl -sSL https://raw.githubusercontent.com/Hawaiideveloper/test-Driven_Development-MCP/main/tdd-helper.sh -o tdd-helper.sh
chmod +x tdd-helper.sh
./tdd-helper.sh

# With options
./tdd-helper.sh --reset  # Reconfigure from scratch
./tdd-helper.sh --help   # Show help
```

## Troubleshooting

### Docker Issues

**Container won't start:**
```bash
# Check if Docker Desktop is running
docker version

# Check if port 63777 is in use
lsof -i :63777

# Stop existing container
docker stop TDD-MCP && docker rm TDD-MCP
```

**Server not responding:**
```bash
# View container logs
docker logs TDD-MCP -f

# Check container status
docker ps -a | grep TDD-MCP

# Restart container
docker restart TDD-MCP
```

### Build Issues

**Image build fails:**
```bash
# Clean rebuild
docker build --no-cache -t tdd-mcp:local .

# Check Docker disk space
docker system df

# Clean up old images
docker system prune -a
```

### Repository Access Issues

**Server can't access files:**
- Ensure repository path is absolute, not relative
- Check Docker file sharing settings (Docker Desktop → Settings → Resources → File Sharing)
- Verify the repository is in an allowed path

**Permission errors:**
```bash
# On Linux/macOS, ensure files are readable
chmod -R 755 /path/to/repo

# Check mount point inside container
docker exec TDD-MCP ls -la /work
```

### Common Solutions

**Port already in use:**
```bash
# Use different port
docker run -d -p 8080:63777 -v "$(pwd):/work" --name TDD-MCP ghcr.io/hawaiideveloper/tdd-mcp:latest

# Update base URL in requests
curl http://localhost:8080/health
```

**Slow performance:**
- First run may be slow due to dependency installation
- Subsequent runs use Docker layer caching
- Large repositories may take longer to analyze

**Can't connect from host:**
```bash
# Verify container is running
docker ps | grep TDD-MCP

# Test connectivity
curl -v http://localhost:63777/health

# Check container network
docker inspect TDD-MCP | grep -A 5 "NetworkSettings"
```

### Getting Help

1. Check logs: `docker logs TDD-MCP -f`
2. View API docs: `http://localhost:63777/docs`
3. Test health endpoint: `curl http://localhost:63777/health`
4. Rebuild image: `docker build -t tdd-mcp:local .`
5. Open GitHub issue with logs and error messages


