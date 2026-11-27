---
name: codexbox
description: "Run OpenAI Codex through an already-installed codexbox: interactive and `codexbox exec` calls, plus its HTTP /run API, OpenAI-compatible endpoint, MCP tools, Telegram bot and cron results. Use when the user asks to run Codex in the codexbox container or to call a codexbox server."
homepage: https://github.com/psyb0t/docker-codexbox
user-invocable: true
metadata:
  { "openclaw": { "emoji": "💻", "primaryEnv": "CODEXBOX_URL", "requires": { "bins": ["codexbox", "curl"] } } }
permissions:
  network: "Calls to the user's codexbox server at CODEXBOX_URL (http://localhost:8080 by default). Codex sends requests to OpenAI, or to OPENAI_BASE_URL when the user set it, and Telegram mode uses api.telegram.org."
  shell: "Run the codexbox command and curl."
  filesystem: "Read and write files in the workspace directory the user names for codexbox."
---

# codexbox

[OpenAI Codex CLI](https://github.com/openai/codex) inside an [aicodebox](https://github.com/psyb0t/docker-aicodebox) container, put on the network. codexbox is aicodebox's `codex` adapter. The HTTP/MCP/Telegram/cron surfaces are aicodebox's, the argv/JSON-event translation is codexbox's.

## Setup

codexbox must already be installed and running; this skill only covers using it. Installation and server configuration are in the docs at https://psyb0t.github.io/docker-codexbox/ and the README at https://github.com/psyb0t/docker-codexbox. For the HTTP, OpenAI and MCP surfaces, read `CODEXBOX_URL` (default `http://localhost:8080`), `CODEXBOX_API_MODE_TOKEN` and `CODEXBOX_MCP_MODE_TOKEN` from the environment the user set. For the local `codexbox` command, run it from the workspace the user named.

## Agent execution

Use `codexbox` when it is on `PATH`, from the workspace the user named.

```bash
codexbox                                      # interactive Codex TUI
codexbox exec "inspect this workspace"        # one-shot work
printf '%s\n' "summarize README.md" | codexbox exec -
```

Use an HTTP or MCP endpoint only when the user asks for a service or provides an already-running remote URL.

## Security & safety

- **Deletion has no undo.** The file delete endpoint, the MCP `delete_file` tool and `codexbox clear-session` remove data. Use them only on files or sessions the current task created, only when the user asked for that removal, and never in another caller's workspace.
- **codexbox is not a sandbox.** Codex runs inside it with its approvals and sandbox bypassed and broad access. Do not run untrusted prompts or repositories through it. Cron jobs run unattended, so schedule only jobs the user asked for.
- **Data leaves the machine only to these hosts.** Codex sends prompts and the files it reads to OpenAI, or to `OPENAI_BASE_URL` when set. Telegram mode sends bot messages and files to the Telegram Bot API. The `curl` examples below call the codexbox server the user runs, over plain HTTP on `localhost` by default. Send the user's tokens only to the user's own server.
- **An unset API or MCP token means no authentication** on that surface, giving run execution and full workspace file access to anyone who can reach it. If the user's server is open, tell them rather than relying on it.

## When To Use

- Drive Codex from a script/CI job via `POST /run` instead of a terminal session.
- Point an OpenAI-SDK client at Codex via `/openai/v1/chat/completions` (drop-in base-URL swap).
- Wire Codex into an MCP-aware agent (Claude Code, another OpenClaw agent, Cursor) as a tool-calling backend.
- Run Codex from Telegram, or read results of its cron jobs.
- Manage workspace files (upload/download/list/delete) over HTTP without a shell.

## When NOT To Use

- Need `--append-system-prompt` exact CLI semantics. codex has no such flag; codexbox maps `appendSystemPrompt` to `-c developer_instructions=...` (a developer-role message), not a raw prompt prepend.
- Need per-tool allow/deny lists. codex has no name-based built-in tool allowlist. `toolsAllowlist` is accepted for cross-adapter API compatibility but logged and ignored. `noTools` is the only lever (drops shell/exec + web_search, forces the sandbox read-only).
- Need codex's own MCP client/server support (`[mcp_servers.*]` in `config.toml`, `codex mcp-server` stdio). That's a different, unrelated surface from the MCP mode documented here (which is aicodebox's file-ops + prompt-running MCP surface, not codex's).
- Multiple concurrent runs against the *same* workspace. The API/OAI/MCP surfaces all serialize per-workspace; a second run against a busy workspace gets 409.

## Shell mode

`codexbox` drops you into `codex`'s interactive TUI, or runs codex subcommands directly.

```bash
codexbox                       # interactive TUI, continues the last session for this dir
codexbox --no-continue         # same, but starts a brand-new session
codexbox stop                  # stop this dir's running container(s)
```

The wrapper forwards `"$@"` straight to codex, so any `codex` subcommand works (`codexbox mcp ...`, `codexbox doctor`, etc.).

## One-shot exec mode

`codexbox exec`: single prompt in, output to your terminal, no TUI.

```bash
codexbox exec "fix the failing test in ./app"
echo "summarize README.md" | codexbox exec -     # prompt via stdin
```

## API

The API listens at `CODEXBOX_URL`. If the server has `CODEXBOX_API_MODE_TOKEN` set, send it as a bearer token. The models it accepts are the ones the operator configured; list them with `GET /openai/v1/models`.

| Method | Path | What it does |
|--------|------|---------------|
| `GET` | `/healthz` | liveness, `{ok, adapter}`, no token needed |
| `GET` | `/status` | in-flight runs + busy workspaces |
| `POST` | `/run` | sync agent run → `{runId, workspace, exitCode, text, ...}` |
| `GET` | `/run/result?runId=<id>` | poll an async run |
| `DELETE` | `/run/{run_id}` | cancel an in-flight run |
| `GET` | `/files` | list the workspace root |
| `GET` | `/files/{path}` | list a sub-directory, or stream a file's bytes |
| `PUT` | `/files/{path}` | upload: raw request body becomes the file contents; parent dirs auto-created |
| `DELETE` | `/files/{path}` | delete a file (refuses directories with 400) |
| `POST` | `/openai/v1/chat/completions` | OpenAI-compatible chat endpoint (see below) |
| `GET` | `/openai/v1/models` | model list the server advertises |
| `POST` | `/mcp/` | MCP server, when the operator enabled it (see MCP) |

The delete row above removes one workspace file. See [Security & safety](#security--safety) before using it.

`POST /run` body: `prompt` (required), `workspace`, `model`, `systemPrompt`, `appendSystemPrompt`, `jsonSchema`, `eventMode`, `outputFormat`, `noContinue`, `resume`, `timeoutSeconds`, `thinking`, `noTools`, `toolsAllowlist`, `includeRaw`, `async`, `fireAndForget`. With `jsonSchema` set, the response adds `json`, `events`, `sessionId`, `usage`, `attempts`. codex has native `--output-schema` enforcement, so `jsonSchema` maps straight onto it; the shared validator and its retry stay only as a fallback. `"eventMode": "full"` returns every native Codex event, `"none"` only the final result, and the default `"auto"` turns events on for `jsonSchema` requests.

Default programmatic runs continue the exact top-level Codex `exec` root
pinned to the canonical workspace. The first run creates the pin; existing
workspaces migrate their newest top-level `exec` rollout. Newer subagent
rollouts are deliberately excluded because Codex rejects direct turns on
multi-agent children. Explicit `resume` re-pins the confirmed thread;
`noContinue` is ephemeral and leaves the workspace pin unchanged.

```bash
curl -s "$CODEXBOX_URL/run" \
  --oauth2-bearer "$CODEXBOX_API_MODE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "say HELLO", "workspace": "/workspace"}'
```

Async: set `"async": true`, poll `GET /run/result?runId=<id>` until `status != "running"`.

All `/files/*` paths are resolved against the workspace root with traversal checking: `..` segments that escape the root return 400.

```bash
curl -sS -X PUT --oauth2-bearer "$CODEXBOX_API_MODE_TOKEN" \
  --data-binary @local.txt "$CODEXBOX_URL/files/notes/hello.txt"

curl -sS --oauth2-bearer "$CODEXBOX_API_MODE_TOKEN" \
  "$CODEXBOX_URL/files/notes/hello.txt"
```

## OpenAI-compatible endpoint

`POST /openai/v1/chat/completions` (same URL and token as the API). Point any OpenAI SDK's base URL at `$CODEXBOX_URL/openai/v1` and call it like the real API.

- **Streaming**: `"stream": true` gives real incremental SSE for plain chat. When `tools`/`tool_choice` or a schema constraint is also set, the full answer is computed first, then replayed as a single-shot SSE stream (tool-call/schema turns can't be streamed token-by-token).
- **Tools**: OpenAI-style `tools` / `tool_choice` in the request body. codex runs its own tools internally, so client-executed tool calling is bridged: codexbox injects an "emit `{"tool_calls":[...]}` and stop" protocol into the system prompt and parses codex's textual output back into OpenAI `tool_calls`. Stateless: resend full history each round-trip, same as the standard OpenAI tool loop.
- **`response_format`**: `{"type":"text"}` (default), `{"type":"json_object"}` (force parseable JSON, no schema), or `{"type":"json_schema","json_schema":{"name","schema","strict?"}}` (schema-constrained, same native `--output-schema` path as `/run`'s `jsonSchema`). Composable with `tools`: a tool-call turn isn't schema-checked, only the final non-tool answer is.
- Custom headers (`x-aicodebox-*` prefix, `x-claude-*` accepted as aliases for workspace/continue/append-system-prompt) cover what the OpenAI wire format has no field for: `x-aicodebox-workspace`, `x-aicodebox-continue`, `x-aicodebox-resume`, `x-aicodebox-json-schema` (fallback if `response_format` isn't set), `x-aicodebox-no-tools`, `x-aicodebox-tools-allowlist`, `x-aicodebox-timeout-seconds`, `x-aicodebox-extra-args`.

```bash
curl -s "$CODEXBOX_URL/openai/v1/chat/completions" \
  --oauth2-bearer "$CODEXBOX_API_MODE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
        "model": "gpt-5.1-codex",
        "messages": [{"role": "user", "content": "say HELLO"}],
        "stream": false
      }'
```

## MCP

The MCP surface is aicodebox's own, file ops + prompt running as tools: `run_prompt`, `list_files`, `read_file`, `write_file`, `delete_file`. This is separate from codex's own MCP client/server support.

Where it lives: at `$CODEXBOX_URL/mcp/` when it is served by the API server, or at the root of its own port (default `8081`) when it runs standalone. Use the URL the user gives you. The `@psyb0t/codexbox` stdio bridge appends `CODEXBOX_MCP_PATH` (default `/mcp/`) to `CODEXBOX_URL`; use `CODEXBOX_MCP_PATH=/` for a standalone server.

Auth: `CODEXBOX_MCP_MODE_TOKEN` as `Authorization: Bearer ...`, or `?apiToken=...` for clients that can't set headers. It is independent of the API token. An MCP server behind a reverse proxy may reject requests whose `Host` or `Origin` it was not configured to accept; if that happens, tell the user.

Wire into an MCP-aware client:

```bash
claude mcp add --transport http codexbox "$CODEXBOX_URL/mcp/" \
  --header "Authorization: Bearer $CODEXBOX_MCP_MODE_TOKEN"
```

## Telegram bot

When the user's instance runs the Telegram bot:

- Text in → codex runs → Markdown→HTML rendered response back.
- File uploads land in the chat's workspace. `[SEND_FILE: path]` in codex's output delivers workspace files as Telegram attachments.
- Per-chat overrides: `/model`, `/effort` (codex's `model_reasoning_effort` levels), `/system_prompt`, `/append_system_prompt`.
- `/cancel` kills the in-flight run, `/reload` re-reads config, `/config` dumps merged settings, `/fetch <path>` downloads a file.

## Cron

When the user's instance runs the cron scheduler, YAML-defined jobs fire codex non-interactively on 6-field cron schedules and can post results to Telegram. Each run records `meta.json`, `stdout.log`, `stderr.log` and `result.txt` in the instance's cron history. Job definitions are the operator's to manage; see the docs at https://psyb0t.github.io/docker-codexbox/.

## Typical Workflows

**Fire a one-off prompt from a script:**

```bash
curl -s "$CODEXBOX_URL/run" \
  -H "Authorization: Bearer $CODEXBOX_API_MODE_TOKEN" -H "Content-Type: application/json" \
  -d '{"prompt": "list every TODO in /workspace", "workspace": "/workspace"}' | jq -r .text
```

**Drop-in OpenAI SDK swap:**

```python
from openai import OpenAI
client = OpenAI(base_url="http://localhost:8080/openai/v1", api_key="your-secret")  # CODEXBOX_URL + /openai/v1
resp = client.chat.completions.create(
    model="gpt-5.1-codex",
    messages=[{"role": "user", "content": "say HELLO"}],
)
print(resp.choices[0].message.content)
```

**Schema-constrained extraction:**

```bash
curl -s "$CODEXBOX_URL/run" \
  -H "Authorization: Bearer $CODEXBOX_API_MODE_TOKEN" -H "Content-Type: application/json" \
  -d '{
        "prompt": "extract the version + license from README.md",
        "workspace": "/workspace",
        "jsonSchema": {"type": "object", "properties": {"version": {"type": "string"}, "license": {"type": "string"}}, "required": ["version", "license"]}
      }' | jq .json
```

**Async run + poll:**

```bash
run_id=$(curl -s "$CODEXBOX_URL/run" -H "Authorization: Bearer $CODEXBOX_API_MODE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "run the full test suite and summarize failures", "async": true}' | jq -r .runId)

curl -s "$CODEXBOX_URL/run/result?runId=$run_id" -H "Authorization: Bearer $CODEXBOX_API_MODE_TOKEN" | jq
```

**Cancel a stuck run:**

```bash
curl -s -X DELETE "$CODEXBOX_URL/run/$run_id" -H "Authorization: Bearer $CODEXBOX_API_MODE_TOKEN"
```
