# docker-codexbox

[![Docker Pulls](https://img.shields.io/docker/pulls/psyb0t/codexbox?style=flat-square)](https://hub.docker.com/r/psyb0t/codexbox)
[![License: WTFPL](https://img.shields.io/badge/License-WTFPL-brightgreen.svg?style=flat-square)](http://www.wtfpl.net/)

[OpenAI Codex CLI](https://github.com/openai/codex) inside an [aicodebox](https://github.com/psyb0t/docker-aicodebox) container. One image, five ways in: interactive shell, one-shot exec, OpenAI-compatible endpoint, MCP server, Telegram bot, and a cron scheduler that fires codex on whatever schedule you want.

You talk to codexbox. codexbox talks to codex. codex talks to OpenAI — or your ChatGPT subscription. Nobody cares about the middle.

## Table of Contents

- [Quick start](#quick-start)
- [Install (the `codexbox` wrapper)](#install-the-codexbox-wrapper)
- [Modes](#modes)
  - [API mode](#api-mode)
  - [Telegram mode](#telegram-mode)
  - [Cron mode](#cron-mode)
- [Configuration](#configuration)
- [Auth](#auth)
- [Development](#development)
- [Tests](#tests)
- [License](#license)

## Quick start

```bash
# one-shot prompt (passthrough → codexbox-agent maps `exec ...` onto
# `codex exec --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check ...`)
docker run --rm \
  -e OPENAI_API_KEY=sk-... \
  -v "$PWD/.codex:/home/aicode/.codex" \
  psyb0t/codexbox:latest \
  exec "list the files in /workspace"

# API server
docker run -d --network host \
  -e CODEXBOX_API_MODE=1 \
  -e CODEXBOX_API_MODE_TOKEN=your-secret \
  -e OPENAI_API_KEY=sk-... \
  -v "$PWD/workspace:/workspace" \
  -v "$PWD/.codex:/home/aicode/.codex" \
  psyb0t/codexbox:latest
```

Bind-mounting `.codex` (→ `/home/aicode/.codex`) is optional for a quick one-shot API-key run, but **required** if you want auth to survive container recreates — see [Auth](#auth), especially if you're on a ChatGPT subscription instead of an API key.

## Install (the `codexbox` wrapper)

Typing the full `docker run` line every time is tedious. `install.sh` drops a `codexbox` command on your `PATH` that wraps it — it mounts the current directory as the workspace, persists `~/.codex` (so your login sticks), forwards auth/env, and manages a per-directory container for you.

```bash
git clone https://github.com/psyb0t/docker-codexbox.git
cd docker-codexbox
./install.sh                         # pulls psyb0t/codexbox:latest + installs `codexbox`
# or, without cloning:
curl -fsSL https://raw.githubusercontent.com/psyb0t/docker-codexbox/master/install.sh | bash
```

Then, from **any** project directory:

```bash
export OPENAI_API_KEY=sk-...         # or use a subscription: `codexbox login --device-auth`

codexbox                             # interactive TUI in a container for THIS dir
codexbox exec "fix the failing test in ./app"   # one-shot codex exec, output to your terminal
echo "summarize README.md" | codexbox exec -     # prompt via stdin
codexbox login --device-auth         # ChatGPT-subscription OAuth login (persists in ~/.codex)
codexbox login status                # which auth mode is active
codexbox --version                   # passthrough to `codex --version`
codexbox stop                        # stop this dir's running container(s)
codexbox clear-session               # drop codex's saved sessions (keeps auth + config)
```

The wrapper forwards `"$@"` straight to the image, so any `codex` subcommand works (`codexbox mcp ...`, `codexbox doctor`, etc.). The sandbox-bypass flag is injected inside the container — you never pass it yourself.

### Wrapper environment variables

Set these on the host before running `codexbox`:

| Var | Default | What it does |
|-----|---------|---------------|
| `OPENAI_API_KEY` | — | API-key auth (seeded into `~/.codex/auth.json` on boot). Not needed for subscription login. |
| `OPENAI_BASE_URL` | — | Point codex at an OpenAI-compatible endpoint |
| `CODEXBOX_IMAGE` | `psyb0t/codexbox:latest` | Override the image the wrapper runs |
| `CODEXBOX_DATA_DIR` | `~/.codex` | Host dir mounted as `CODEX_HOME` (auth + config + sessions) |
| `CODEXBOX_SSH_DIR` | `~/.ssh/codexbox` | SSH key dir mounted into the container (for git over SSH) |
| `CODEXBOX_MAX_MEM` | `10g` | Per-container memory limit |
| `CODEXBOX_CONTAINER_NAME` | derived from `$PWD` | Override the per-workspace container name |
| `CODEXBOX_ENV_*` | — | Forward arbitrary env into the container (prefix stripped: `CODEXBOX_ENV_FOO=bar` → `FOO=bar`) |
| `CODEXBOX_MOUNT_*` | — | Mount extra host dirs (`/host:/container` syntax, or a bare path for same-path-both-sides) |

`CODEXBOX_MODE_CRON=1` + `CODEXBOX_MODE_CRON_FILE=/path/cron.yaml codexbox` starts the cron scheduler as a long-running background container instead.

**Prefer no host install?** Everything the wrapper does is a plain `docker run` — the [Quick start](#quick-start) and [Modes](#modes) sections show the raw commands.

## Modes

**Foreground modes** (API / Telegram / Cron) are mutually exclusive — except `CODEXBOX_TELEGRAM_MODE=1` + `CODEXBOX_CRON_MODE=1`, which run together (cron in-thread inside telegram). API wins if set alongside anything else.

**MCP mode** (`CODEXBOX_MCP_MODE=1`) is independent — it coexists with whatever foreground mode is running. In API mode it's mounted at `/mcp` on the API port; in other modes it runs as a sidecar uvicorn on its own port.

### API mode

`CODEXBOX_API_MODE=1`. FastAPI server on `:8080` (override with `CODEXBOX_API_MODE_PORT`).

> **Required:** `CODEXBOX_AVAILABLE_MODELS=<csv>` (e.g. `gpt-5.1-codex,gpt-5.1-codex-mini`). API mode refuses to boot without it — `/openai/v1/models` needs a real list and there's no sensible default (codex has no hardcoded model slug; it's server-driven and OpenAI can add/retire models without notice).

| Method | Path | What it does |
|--------|------|--------------|
| `GET` | `/healthz` | liveness |
| `GET` | `/status` | in-flight runs |
| `POST` | `/run` | sync agent run → `{text, exit_code, ...}` |
| `POST` | `/run/async` | fire and get a job id back |
| `GET` | `/run/{id}` | poll async job |
| `POST` | `/run/{id}/cancel` | kill in-flight run |
| `GET` | `/files` | list the workspace root (`{entries: [{name, type, size?}, ...]}`) |
| `GET` | `/files/{path}` | list a sub-directory, or stream a file's bytes |
| `PUT` | `/files/{path}` | upload — raw request body becomes the file contents; parent dirs auto-created |
| `DELETE` | `/files/{path}` | delete a file (refuses directories — 400) |
| `POST` | `/openai/v1/chat/completions` | OpenAI-compatible (streaming + non-streaming; supports `tools` / `tool_choice` client-executed tool calling, composable with `response_format`) |
| `GET` | `/openai/v1/models` | model list |
| `POST` | `/mcp` | MCP server (streamable HTTP) — mounted only when `CODEXBOX_MCP_MODE=1` |

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

**`POST /run`** body: `prompt` (required), `workspace`, `model`, `systemPrompt`, `appendSystemPrompt`, `jsonSchema`, `noContinue`, `resume`, `timeoutSeconds`, `thinking`, `noTools`, `toolsAllowlist`, `includeRaw`, `async`, `fireAndForget`. With `jsonSchema` set the response includes `text`, `json`, `events`, `sessionId`, `usage`, `attempts`; without it the response is `{runId, workspace, exitCode, text}`.

> Codex has **native JSON-schema enforcement** (`--output-schema`) — of the adapters on the aicodebox base, codex is the only one that doesn't need self-correction retries to get schema-conforming output; `jsonSchema` maps straight onto codex's own structured-output flag.

`appendSystemPrompt` and `systemPrompt` have no direct codex equivalent — codex has no `--append-system-prompt` flag; system-prompt injection there is via `AGENTS.md` in the workspace or `-c base_instructions=...`, not a per-request field. `noTools` / `toolsAllowlist` are accepted for API compatibility with the other adapters but codex has no per-tool allowlist or "disable internal tools" switch, so they're logged and ignored.

```bash
curl -s http://localhost:8080/run \
  -H "Authorization: Bearer your-secret" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "say HELLO", "workspace": "/workspace"}'
```

### Telegram mode

`CODEXBOX_TELEGRAM_MODE=1` + `CODEXBOX_TELEGRAM_MODE_TOKEN=<token>`.

- Text in → codex runs → Markdown→HTML rendered response back.
- File uploads land in the chat's workspace. `[SEND_FILE: path]` in codex's output delivers workspace files as Telegram attachments.
- Per-chat overrides: `/model`, `/effort` (maps to codex's `model_reasoning_effort` levels), `/system_prompt`, `/append_system_prompt`. Persisted across restarts.
- `/cancel` kills the in-flight run. `/reload` re-reads config. `/config` dumps merged settings. `/fetch <path>` downloads a file.
- Replies to cron messages inject the job's instruction + result so codex has full context for follow-ups.

Config at `$HOME/.aicodebox/telegram.yml` (override via `CODEXBOX_TELEGRAM_MODE_CONFIG`):

```yaml
allowed_chats: [-100123, 42]
default:
  model: gpt-5.1-codex
  workspace: shared
chats:
  -100123:
    workspace: alpha
    allowed_users: [10, 20]
```

### Cron mode

`CODEXBOX_CRON_MODE=1` + `CODEXBOX_CRON_MODE_FILE=/path/to/cron.yaml`. 6-field schedules via croniter. Each job fires codex with the given instruction.

```yaml
jobs:
  - name: morning-standup
    schedule: "0 0 9 * * 1-5"
    instruction: |
      Summarize what changed in /workspace since yesterday.
      Be brief. One paragraph max.
    workspace: myproject
    telegram_chat_id: -100123
    model: gpt-5.1-codex
    thinking: low
```

Each run gets a history dir at `$HOME/.aicodebox/cron/history/<workspace>/<timestamp>-<job>/` with `meta.json`, `stdout.log`, `stderr.log`, `result.txt`. If telegram is configured, `telegram.json` lands there too and the next run's prompt gets a "prior run" hint so codex can reference its own history without you wiring it up.

### MCP mode

`CODEXBOX_MCP_MODE=1`. Exposes the MCP (Model Context Protocol) surface — `run_prompt`, `list_files`, `read_file`, `write_file`, `delete_file` as tools. Coexists with any foreground mode:

| Foreground | MCP placement |
|---|---|
| API mode (`CODEXBOX_API_MODE=1`) | mounted at `/mcp` on the API port — no extra process |
| Telegram / Cron / passthrough | sidecar uvicorn on `CODEXBOX_MCP_MODE_PORT` (default `8081`) |

Auth: `CODEXBOX_MCP_MODE_TOKEN=<token>` — bearer in the `Authorization: Bearer …` header, or `?apiToken=…` for clients that can't set headers. Empty = no auth. **No fallback to `API_MODE_TOKEN`** — MCP has its own bearer.

This is the aicodebox base's own MCP surface (file ops + prompt running over MCP). It's separate from codex's own MCP support — codex can also act as an MCP *client* (`[mcp_servers.*]` in `config.toml`) and an MCP *server* (`codex mcp-server`, stdio); neither of those is wired up by codexbox v0.1.0.

## Configuration

Naming convention: `CODEXBOX_<MODE>_MODE=1` is the on/off flag, `CODEXBOX_<MODE>_MODE_<KNOB>=...` is its config. Non-mode-scoped vars (workspace, container name, available models) are bare.

The image is built on top of [aicodebox](https://github.com/psyb0t/docker-aicodebox), so the equivalent `AICODEBOX_*` names also work — the entrypoint translates `CODEXBOX_X` to `AICODEBOX_X` when only the codexbox-prefixed one is set. If you set both, `AICODEBOX_*` wins.

### Mode flags

| Var | Default | What it does |
|-----|---------|---------------|
| `CODEXBOX_API_MODE` | `0` | Boot the HTTP API server (foreground) |
| `CODEXBOX_TELEGRAM_MODE` | `0` | Boot the Telegram bot (foreground) |
| `CODEXBOX_CRON_MODE` | `0` | Boot the cron scheduler (foreground; in-thread when telegram is also on) |
| `CODEXBOX_MCP_MODE` | `0` | Expose MCP — mounted at `/mcp` in API mode, or as a sidecar elsewhere |

### API mode config

| Var | Default | What it does |
|-----|---------|---------------|
| `CODEXBOX_API_MODE_PORT` | `8080` | Port the API server binds to |
| `CODEXBOX_API_MODE_TOKEN` | empty | Bearer token for the API surface. Empty = no auth |

### Telegram mode config

| Var | Default | What it does |
|-----|---------|---------------|
| `CODEXBOX_TELEGRAM_MODE_TOKEN` | — | Bot token from @BotFather |
| `CODEXBOX_TELEGRAM_MODE_CONFIG` | `~/.aicodebox/telegram.yml` | Path to the telegram config yaml |
| `CODEXBOX_TELEGRAM_MODE_OVERRIDES` | `~/.aicodebox/telegram_overrides.json` | Per-chat override store (model/effort/system prompts) |

### Cron mode config

| Var | Default | What it does |
|-----|---------|---------------|
| `CODEXBOX_CRON_MODE_FILE` | — | Path to the cron yaml |
| `CODEXBOX_CRON_MODE_HISTORY_DIR` | `~/.aicodebox/cron/history` | Where cron writes per-run history dirs (`meta.json`, `stdout.log`, `stderr.log`, `result.txt`, `telegram.json`) |

### MCP mode config

| Var | Default | What it does |
|-----|---------|---------------|
| `CODEXBOX_MCP_MODE_PORT` | `8081` | Port the sidecar MCP server binds to (ignored when mounted inside API) |
| `CODEXBOX_MCP_MODE_TOKEN` | empty | Bearer token for MCP. Empty = no auth. **No fallback to `API_MODE_TOKEN`** |

### Workspace & runtime

| Var | Default | What it does |
|-----|---------|---------------|
| `CODEXBOX_WORKSPACE` | `/workspace` | Root workspace dir inside the container |
| `CODEXBOX_CONTAINER_NAME` | `aicodebox` | Used to scope per-container state files (auth, etc.) |
| `CODEXBOX_AVAILABLE_MODELS` | — | **Required for API mode.** CSV list returned by `/openai/v1/models` and shown in the telegram `/model` picker. API mode refuses to boot without it; telegram `/model` picker degrades to a "set this env var" reply. |
| `CODEXBOX_AVAILABLE_EFFORTS` | `none,minimal,low,medium,high,xhigh,max` | Override the effort/reasoning list shown by the telegram `/effort` picker (comma-separated) |
| `CODEXBOX_MODEL` | — | Default model passed to codex (`-m/--model`) when a caller doesn't specify one |

## Auth

codex supports **two** distinct auth modes. Pick one.

### 1. API key (pay-as-you-go)

Set `OPENAI_API_KEY`. Optionally `OPENAI_BASE_URL` to point at an OpenAI-compatible endpoint instead of the default OpenAI API.

```bash
docker run --rm \
  -e OPENAI_API_KEY=sk-... \
  -v "$PWD/.codex:/home/aicode/.codex" \
  psyb0t/codexbox:latest \
  exec "say HELLO"
```

The container seeds codex's `$CODEX_HOME/auth.json` from `OPENAI_API_KEY` on boot (`codex login --with-api-key` under the hood, reading the key from stdin — codex does **not** accept a bare `OPENAI_API_KEY` env var for `codex exec`; it needs the login step to actually write `auth.json`). This seeding is safe to run on every boot: it only writes `apikey`-mode auth, and never touches an existing ChatGPT-subscription login (see below).

### 2. ChatGPT subscription (Plus / Pro / Team)

No API key at all — codex bills against your ChatGPT subscription instead. This requires a one-time interactive OAuth login, and **you must bind-mount `~/.codex`** (→ `/home/aicode/.codex` in the container) so that login survives container recreates:

```bash
docker run -it \
  -v "$HOME/.codex:/home/aicode/.codex" \
  psyb0t/codexbox:latest \
  login --device-auth
```

This prints a URL + a short code. Open the URL in any browser, enter the code, approve — codex writes OAuth tokens to `$CODEX_HOME/auth.json` (`auth_mode` is the OAuth/chatgpt variant, not `apikey`). Every later `docker run` against that same bind-mounted `~/.codex` reuses the login and bills against the subscription, no `OPENAI_API_KEY` needed:

```bash
docker run --rm \
  -v "$HOME/.codex:/home/aicode/.codex" \
  psyb0t/codexbox:latest \
  exec "say HELLO"
```

**This only works if `~/.codex` is bind-mounted.** Without it, the login lives inside the throwaway container's filesystem and is gone the moment the container is removed — you'd have to re-run the OAuth flow every single time. If `OPENAI_API_KEY` is also set in the environment once a subscription login exists, it is **not** used to overwrite it — an existing OAuth login always wins over the API-key seeding step. `codex login status` (passed straight through) reports which mode is currently active; `codex logout` clears it.

### Model & reasoning effort

Codex has **no fixed default model slug** — availability is server-driven AND depends on how you authenticated:

- **ChatGPT subscription** — the GPT-5.6 family: `gpt-5.6-luna` (fastest + cheapest — good for tests), `gpt-5.6-terra` (balanced), `gpt-5.6-sol` (flagship; the account default). The `*-codex` / `*-codex-mini` slugs are **rejected** on a ChatGPT account (400 "not supported").
- **API key** — the API catalog: `gpt-5.1-codex`, `gpt-5-codex`, `gpt-5.1-codex-mini` (small), etc.

Pass a model with `-m` / `--model` (passthrough) or set `CODEXBOX_MODEL` / the `model` field on `/run` and `/openai/v1/chat/completions`.

Reasoning effort maps to codex's `model_reasoning_effort` config key (`-c model_reasoning_effort=<level>`). Levels: `none`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max` (default `medium`). Exposed as the `thinking` field on the API and the `/effort` command in telegram — same shape as the other aicodebox children.

### System prompts & tool control

The canonical `/run` knobs are honored — codex just exposes them differently than pi/claude:

- `systemPrompt` → replaces the built-in system prompt (`-c instructions=…`).
- `appendSystemPrompt` → appends a developer-role message (`-c developer_instructions=…`).
- `noTools` → drops the shell/exec + web-search tools and runs the sandbox read-only, so the agent answers without acting. (codex keeps `apply_patch`/`update_plan` tool specs that can't be config-removed, but read-only neuters them — the closest codex has to pi/claude `--no-tools`.)
- `toolsAllowlist` → **not supported**: codex has no name-based built-in tool allowlist (only per-MCP-server `enabled_tools`). It is ignored with a warning.
- Session: a call with neither `resume` nor `noContinue` continues the workspace's most recent session (`codex exec resume --last`, which starts fresh when there's nothing to resume); `resume` targets a specific session id; `noContinue` runs ephemeral.

## Development

Requires `psyb0t/docker-aicodebox` checked out next to this repo (`../docker-aicodebox`).

```bash
make help        # list targets
make build-base  # build aicodebox-base from ../docker-aicodebox
make build       # build codexbox:local on top of it
make test        # run the full e2e suite (needs .env.test)
make clean       # remove built images
```

## Tests

End-to-end tests build the image and run it against a real OpenAI/codex endpoint. Telegram tests use [psyb0t/telethon-plus](https://github.com/psyb0t/docker-telethon) as a real MTProto userbot.

```bash
cp .env.test.example .env.test
$EDITOR .env.test   # fill in OPENAI_API_KEY and optionally Telegram creds
make test
```

Telegram tests auto-skip if `AICODEBOX_TELEGRAM_MODE_TOKEN` is empty. Everything else only needs `OPENAI_API_KEY` (and a real ChatGPT-subscription login, if you also want the subscription auth path exercised).

## License

WTFPL — see [LICENSE](LICENSE). Do what the fuck you want.
