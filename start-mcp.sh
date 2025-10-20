#!/bin/sh
set -e

# Simple bootstrap script to build and run the MCP container locally, then
# introduce itself and ensure a checklist exists, and kick off TDD.

REPO_PATH="${1:-$PWD}"
IMAGE_TAG="tdd-mcp:local"
CONTAINER_NAME="TDD-MCP"
PORT="63777"
LANGUAGE_INPUT="${LANGUAGE:-}"
OPEN_EDITOR="${OPEN_EDITOR:-auto}" # auto|cursor|code|none

open_url() {
  url="$1"
  if command -v open >/dev/null 2>&1; then
    open "$url" || true
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" || true
  else
    printf "Open this URL in your browser: %s\n" "$url"
  fi
}

open_editor() {
  repo="$1"
  choice="$2"
  case "$choice" in
    cursor)
      if command -v cursor >/dev/null 2>&1; then
        cursor -r "$repo" || open -a "Cursor" "$repo" || true
        return
      fi
      ;;
    code)
      if command -v code >/dev/null 2>&1; then
        code -r "$repo" || open -a "Visual Studio Code" "$repo" || true
        return
      fi
      ;;
    none)
      return
      ;;
  esac
  # auto-detect
  if command -v cursor >/dev/null 2>&1; then
    cursor -r "$repo" || open -a "Cursor" "$repo" || true
    return
  fi
  if command -v code >/dev/null 2>&1; then
    code -r "$repo" || open -a "Visual Studio Code" "$repo" || true
    return
  fi
}

echo "[start-mcp] Building Docker image ${IMAGE_TAG}..."
docker build -t "${IMAGE_TAG}" .

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "[start-mcp] Removing existing container ${CONTAINER_NAME}..."
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
fi

echo "[start-mcp] Starting container ${CONTAINER_NAME} on port ${PORT}..."
docker run -d --name "${CONTAINER_NAME}" -p ${PORT}:63777 \
  -e MCP_REPO_PATH="/work" \
  -v "${REPO_PATH}:/work" \
  "${IMAGE_TAG}"

# Wait for FastAPI to become ready
echo "[start-mcp] Waiting for API to be ready..."
for i in 1 2 3 4 5 6 7 8 9 10; do
  if curl -fsS "http://localhost:${PORT}/health" >/dev/null; then
    break
  fi
  sleep 1
done

echo "[start-mcp] Introducing to server..."
INTRO=$(curl -sS -X POST "http://localhost:${PORT}/introduce" \
  -H 'Content-Type: application/json' \
  -d "{\"repoPath\": \"/work\"}")
echo "$INTRO" | sed 's/.*/[server] &/'

HAS=$(echo "$INTRO" | grep -o '"hasChecklist":\s*\(true\|false\)')

if [ -z "${LANGUAGE_INPUT}" ]; then
  printf "Enter default language (python/node/go/rust/java/cpp) [python]: "
  read -r LANGUAGE_INPUT
fi
LANGUAGE_INPUT=${LANGUAGE_INPUT:-python}

if echo "$HAS" | grep -q 'false'; then
  echo "[start-mcp] No checklist found. Creating one now..."
  OUT=$(curl -sS -X POST "http://localhost:${PORT}/ensure-checklist" \
    -H 'Content-Type: application/json' \
    -d "{\"repoPath\": \"/work\", \"dryRun\": false, \"language\": \"${LANGUAGE_INPUT}\"}")
  echo "$OUT" | sed 's/.*/[server] &/'
else
  echo "[start-mcp] Checklist exists. Starting TDD bootstrap/tests..."
  TDD=$(curl -sS -X POST "http://localhost:${PORT}/tdd/start" \
    -H 'Content-Type: application/json' \
    -d "{\"repoPath\": \"/work\", \"language\": \"${LANGUAGE_INPUT}\"}")
  echo "$TDD" | sed 's/.*/[server] &/'
fi

cat <<'MSG'

Next steps:
- Connect from your editor/agent (VS Code, Cursor, Claude) to the local service http://localhost:${PORT}
- Use /introduce, /ensure-checklist, and /tdd/start endpoints as needed

MSG

# Auto-open API docs and editor for convenience
open_url "http://localhost:${PORT}/docs"
open_editor "${REPO_PATH}" "${OPEN_EDITOR}"


