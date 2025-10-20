FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:$PATH

WORKDIR /app

# System deps for building typical projects (keep small but useful)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create and use a virtual environment for all Python deps
RUN python -m venv "$VIRTUAL_ENV" \
    && "$VIRTUAL_ENV/bin/pip" install --no-cache-dir --upgrade pip

COPY server/requirements.txt /app/server/requirements.txt
RUN "$VIRTUAL_ENV/bin/pip" install --no-cache-dir -r /app/server/requirements.txt

COPY server /app/server
COPY bin /app/bin
COPY .mcp /app/.mcp
COPY README.md /app/README.md
COPY package.json /app/package.json

LABEL org.opencontainers.image.title="TDD-MCP" \
      org.opencontainers.image.description="Local TDD MCP FastAPI server"

EXPOSE 63777

CMD ["uvicorn", "server.main:app", "--host", "0.0.0.0", "--port", "63777"]


