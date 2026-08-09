# API Mode

`CODEXBOX_API_MODE=1`. Runs codexbox as a long-lived FastAPI server on `:8080` (override with `CODEXBOX_API_MODE_PORT`), exposing agent runs, workspace file operations, and an OpenAI-compatible chat endpoint.

> **Required:** `CODEXBOX_AVAILABLE_MODELS=<csv>` (e.g. `gpt-5.1-codex,gpt-5.1-codex-mini`). API mode refuses to boot without it — `/openai/v1/models` needs a real list and there's no sensible default (codex has no hardcoded model slug; it's server-driven and OpenAI can add/retire models without notice).

## Setup

```yaml
# docker-compose.yml
services:
  codexbox:
    image: psyb0t/codexbox:latest
    ports:
      - "8080:8080"
    environment:
      - CODEXBOX_API_MODE=1
      - CODEXBOX_API_MODE_TOKEN=your-secret
      - CODEXBOX_AVAILABLE_MODELS=gpt-5.1-codex,gpt-5.1-codex-mini
    volumes:
      - ~/workspaces:/workspace
```

## Endpoints

| Method | Path | What it does |
|--------|------|--------------|
| `GET` | `/healthz` | liveness |
| `GET` | `/status` | in-flight runs |
| `POST` | `/run` | sync agent run → `{runId, workspace, exitCode, text, ...}`; pass `"async": true` in the body to fire and get a `runId` back instead |
| `GET` | `/run/result?runId=<id>` | poll async job |
| `DELETE` | `/run/{run_id}` | kill in-flight run |
| `GET` | `/files` | list the workspace root (`{entries: [{name, type, size?}, ...]}`) |
| `GET` | `/files/{path}` | list a sub-directory, or stream a file's bytes |
| `PUT` | `/files/{path}` | upload — raw request body becomes the file contents; parent dirs auto-created |
| `DELETE` | `/files/{path}` | delete a file (refuses directories — 400) |
| `POST` | `/openai/v1/chat/completions` | OpenAI-compatible (streaming + non-streaming; supports `tools` / `tool_choice` client-executed tool calling, composable with `response_format`) |
| `GET` | `/openai/v1/models` | model list |
| `POST` | `/mcp` | MCP server (streamable HTTP) — mounted only when `CODEXBOX_MCP_MODE=1`. See [mcp.md](mcp.md) |

All `/files/*` paths are resolved against the workspace root with traversal checking — `..` segments that escape the root return 400. Same `Authorization: Bearer ...` token gates them as the rest of the API.

```bash
# upload a file
curl -sS -X PUT \
  -H "Authorization: Bearer your-secret" \
  --data-binary @local.txt \
  http://localhost:8080/files/notes/hello.txt

# download it back
curl -sS -H "Authorization: Bearer your-secret" \
  http://localhost:8080/files/notes/hello.txt

# list the dir
curl -sS -H "Authorization: Bearer your-secret" \
  http://localhost:8080/files/notes | jq

# delete it
curl -sS -X DELETE -H "Authorization: Bearer your-secret" \
  http://localhost:8080/files/notes/hello.txt
```

## Running a prompt

**`POST /run`** body: `prompt` (required), `workspace`, `model`, `systemPrompt`, `appendSystemPrompt`, `jsonSchema`, `noContinue`, `resume`, `timeoutSeconds`, `thinking`, `noTools`, `toolsAllowlist`, `includeRaw`, `async`, `fireAndForget`. With `jsonSchema` set the response includes `text`, `json`, `events`, `sessionId`, `usage`, `attempts`; without it the response is `{runId, workspace, exitCode, text}`.

```bash
curl -s http://localhost:8080/run \
  -H "Authorization: Bearer your-secret" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "say HELLO", "workspace": "/workspace"}'
```

> Codex has **native JSON-schema enforcement** (`--output-schema`) — of the adapters on the aicodebox base, codex is the only one that doesn't need self-correction retries to get schema-conforming output; `jsonSchema` maps straight onto codex's own structured-output flag.

`appendSystemPrompt` and `systemPrompt` have no direct codex equivalent — codex has no `--append-system-prompt` flag; system-prompt injection there is via `AGENTS.md` in the workspace or `-c instructions=...`, not a per-request field. `noTools` / `toolsAllowlist` are accepted for API compatibility with the other adapters but codex has no per-tool allowlist or "disable internal tools" switch, so they're logged and ignored.

## API mode environment variables

| Var | Default | What it does |
|-----|---------|---------------|
| `CODEXBOX_API_MODE` | `0` | Boot the HTTP API server (foreground) |
| `CODEXBOX_API_MODE_PORT` | `8080` | Port the API server binds to |
| `CODEXBOX_API_MODE_TOKEN` | empty | Bearer token for the API surface. Empty = no auth |
| `CODEXBOX_AVAILABLE_MODELS` | — | **Required for API mode.** CSV list returned by `/openai/v1/models`. API mode refuses to boot without it |

> Every `CODEXBOX_*` variable is an alias for the `AICODEBOX_*` equivalent read by the base image. If both are set, `AICODEBOX_*` wins.

## Combined with MCP mode

API mode is the one foreground mode where MCP costs nothing extra — it mounts at `/mcp` on this same port instead of spawning a sidecar. See [mcp.md](mcp.md).
