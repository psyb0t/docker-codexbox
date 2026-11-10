---
title: "API mode"
description: "codexbox API mode: POST /run, async runs, workspace file endpoints and the OpenAI-compatible chat/completions endpoint, with every setting."
nav_order: 1
parent: "Modes"
---

# API mode

`CODEXBOX_API_MODE=1` runs codexbox as a long-lived FastAPI server on `:8080` (change it with `CODEXBOX_API_MODE_PORT`). It serves agent runs, workspace file operations and an OpenAI-compatible chat endpoint.

> **Required:** `CODEXBOX_AVAILABLE_MODELS=<csv>`, for example `gpt-5.1-codex,gpt-5.1-codex-mini`. API mode refuses to start without it. `/openai/v1/models` needs a real list, and Codex has no fixed model name to fall back to. OpenAI's servers decide the list, and it changes without notice.

## Setup

```yaml
# docker-compose.yml
services:
  codexbox:
    image: psyb0t/codexbox:latest
    ports:
      - "127.0.0.1:8080:8080"
    environment:
      - CODEXBOX_API_MODE=1
      - CODEXBOX_API_MODE_TOKEN=your-secret
      - CODEXBOX_AVAILABLE_MODELS=gpt-5.1-codex,gpt-5.1-codex-mini
      - OPENAI_API_KEY=sk-...
    volumes:
      - ~/.codex:/home/aicode/.codex
      - ~/workspaces:/workspace
```

Mount `~/.codex` to use a [subscription login](../auth.md#chatgpt-subscription) instead of `OPENAI_API_KEY`.

For a local server in the current directory, the [wrapper](../wrapper.md) does the mounts for you. Forward the container settings with `CODEXBOX_ENV_`:

```bash
CODEXBOX_ENV_CODEXBOX_API_MODE=1 \
CODEXBOX_ENV_CODEXBOX_AVAILABLE_MODELS=your-model-id \
CODEXBOX_ENV_CODEXBOX_API_MODE_TOKEN=your-api-token \
codexbox
```

The wrapper uses host networking, so the server listens on port 8080 of the host.

## Endpoints

| Method | Path | What it does |
| --- | --- | --- |
| `GET` | `/healthz` | Liveness, with no token required |
| `GET` | `/status` | Runs in flight and busy workspaces |
| `POST` | `/run` | Synchronous agent run, returning `{runId, workspace, exitCode, text, ...}`. With `"async": true` it returns a `runId` at once. |
| `GET` | `/run/result?runId=<id>` | Poll an async run |
| `DELETE` | `/run/{run_id}` | Kill a run in flight |
| `GET` | `/files` | List the workspace root (`{entries: [{name, type, size?}, ...]}`) |
| `GET` | `/files/{path}` | List a subdirectory, or stream a file's bytes |
| `PUT` | `/files/{path}` | Upload. The raw request body becomes the file; parent directories are created. |
| `DELETE` | `/files/{path}` | Delete a file. Directories are refused with 400. There is no undo. |
| `POST` | `/openai/v1/chat/completions` | OpenAI-compatible chat, streaming and non-streaming |
| `GET` | `/openai/v1/models` | The `CODEXBOX_AVAILABLE_MODELS` list |
| `POST` | `/mcp/` | MCP over streamable HTTP, only when `CODEXBOX_MCP_MODE=1`. See [MCP mode](mcp.md). |

Every `/files` path resolves against the workspace root with traversal checking: a `..` that escapes the root returns 400. The same bearer token protects them as the rest of the API.

```bash
# upload a file
curl -sS -X PUT \
  --oauth2-bearer "$CODEXBOX_API_MODE_TOKEN" \
  --data-binary @local.txt \
  http://localhost:8080/files/notes/hello.txt

# download it again
curl -sS \
  --oauth2-bearer "$CODEXBOX_API_MODE_TOKEN" \
  http://localhost:8080/files/notes/hello.txt

# list the directory
curl -sS \
  --oauth2-bearer "$CODEXBOX_API_MODE_TOKEN" \
  http://localhost:8080/files/notes | jq

# delete it
curl -sS -X DELETE \
  --oauth2-bearer "$CODEXBOX_API_MODE_TOKEN" \
  http://localhost:8080/files/notes/hello.txt
```

Runs serialize per workspace. A second run against a busy workspace gets 409.

## Running a prompt

The `POST /run` body takes `prompt` (required), `workspace`, `model`, `systemPrompt`, `appendSystemPrompt`, `jsonSchema`, `eventMode`, `outputFormat`, `noContinue`, `resume`, `timeoutSeconds`, `thinking`, `noTools`, `toolsAllowlist`, `includeRaw`, `async` and `fireAndForget`.

```bash
curl -sS http://localhost:8080/run \
  --oauth2-bearer "$CODEXBOX_API_MODE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "say HELLO", "workspace": "/workspace"}'
```

For a long run, send `"async": true` and poll until `status` is no longer `running`:

```bash
run_id=$(
  curl -sS http://localhost:8080/run \
    --oauth2-bearer "$CODEXBOX_API_MODE_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"prompt": "run the full test suite and summarize failures", "async": true}' |
    jq -r .runId
)

curl -sS "http://localhost:8080/run/result?runId=$run_id" \
  --oauth2-bearer "$CODEXBOX_API_MODE_TOKEN" | jq

# cancel it
curl -sS -X DELETE "http://localhost:8080/run/$run_id" \
  --oauth2-bearer "$CODEXBOX_API_MODE_TOKEN"
```

### Events

`"eventMode": "full"` returns every Codex `exec --json` record. Each one is wrapped as `{sequence, attempt, backend, eventType, event}`, and the nested `event` is untouched, so reasoning items, command execution updates, file changes, MCP activity, web activity, todo updates and turn usage all come through. `"eventMode": "none"` returns only the final result. The default, `"auto"`, keeps the older behavior of turning events on for `jsonSchema` requests; `"outputFormat": "json-verbose"` is the compatibility alias for that.

`"outputFormat": "text"` and `"outputFormat": "json"` are still accepted but change nothing in the `/run` response. New callers should use `eventMode`.

### Structured output

`jsonSchema` maps to Codex's native `--output-schema`, so Codex itself enforces the schema. The shared validator and its retry stay as a fallback if the returned text still fails validation. `jsonSchema` works with either event mode.

```bash
curl -sS http://localhost:8080/run \
  --oauth2-bearer "$CODEXBOX_API_MODE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "extract the version and license from README.md",
    "workspace": "/workspace",
    "jsonSchema": {
      "type": "object",
      "properties": {
        "version": {"type": "string"},
        "license": {"type": "string"}
      },
      "required": ["version", "license"]
    }
  }' | jq .json
```

### Prompts, tools and sessions

`systemPrompt`, `appendSystemPrompt`, `noTools`, `toolsAllowlist`, `resume` and `noContinue` map onto Codex in ways that differ from the other aicodebox agents. [Codex adapter](../codex-adapter.md) has the mapping. In short: `toolsAllowlist` is ignored with a warning, and a call with neither `resume` nor `noContinue` continues the workspace's pinned Codex session.

## OpenAI-compatible endpoint

`POST /openai/v1/chat/completions` sits on the same port behind the same token. Point an OpenAI SDK's base URL at `http://host:8080/openai/v1`:

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8080/openai/v1",
    api_key="your-secret",
)
resp = client.chat.completions.create(
    model="gpt-5.1-codex",
    messages=[{"role": "user", "content": "say HELLO"}],
)
print(resp.choices[0].message.content)
```

- **Streaming:** `"stream": true` streams plain chat as it arrives. With `tools`, `tool_choice` or a schema, the full answer is computed first and then sent as one SSE stream. `stream_options.include_aicodebox_events` adds Codex's native records as named `aicodebox.native` SSE events; standard chunks are unchanged.
- **Tools:** OpenAI-style `tools` and `tool_choice`, executed by the client. Codex runs its own tools internally, so the endpoint asks Codex to answer with a `{"tool_calls":[...]}` object and turns that into OpenAI `tool_calls`. It is stateless: send the full history on every round trip, as with the OpenAI tool loop.
- **`response_format`:** `{"type":"text"}` (the default), `{"type":"json_object"}`, or `{"type":"json_schema","json_schema":{...}}`, which goes through the same `--output-schema` path as `jsonSchema`. It combines with `tools`; only the final answer that is not a tool call is checked against the schema.
- **Headers** for what the OpenAI format has no field for: `x-aicodebox-workspace`, `x-aicodebox-continue`, `x-aicodebox-resume`, `x-aicodebox-append-system-prompt`, `x-aicodebox-json-schema` (used when `response_format` is not set), `x-aicodebox-no-tools`, `x-aicodebox-tools-allowlist`, `x-aicodebox-timeout-seconds` and `x-aicodebox-extra-args`. `x-claude-workspace`, `x-claude-continue` and `x-claude-append-system-prompt` are accepted as aliases.

## API mode settings

| Variable | Default | What it does |
| --- | --- | --- |
| `CODEXBOX_API_MODE` | `0` | Run the HTTP API server in the foreground |
| `CODEXBOX_API_MODE_PORT` | `8080` | Port the server binds |
| `CODEXBOX_API_MODE_TOKEN` | empty | Bearer token for every route except `/healthz` and `/mcp/`, which has its own. Empty means no auth. |
| `CODEXBOX_AVAILABLE_MODELS` | none | **Required.** Comma-separated list served at `/openai/v1/models` |

Every `CODEXBOX_*` name is an alias for the `AICODEBOX_*` name the base reads. If both are set, `AICODEBOX_*` wins.

With `CODEXBOX_API_MODE_TOKEN` empty, anyone who can reach the port can run Codex and read, write and delete workspace files. Set the token, and bind to loopback or put an authenticating proxy in front before exposing the port.

## With MCP mode

API mode is the one foreground mode where MCP costs nothing extra. It is mounted at `/mcp/` on this same port instead of running a second server. See [MCP mode](mcp.md).
