# docker-codexbox

[![CI](https://github.com/psyb0t/docker-codexbox/actions/workflows/pipeline.yml/badge.svg?branch=main)](https://github.com/psyb0t/docker-codexbox/actions/workflows/pipeline.yml)
[![version](https://raw.githubusercontent.com/psyb0t/docker-codexbox/badges/version.svg)](https://github.com/psyb0t/docker-codexbox/releases)
[![license](https://raw.githubusercontent.com/psyb0t/docker-codexbox/badges/license.svg)](LICENSE)
[![Docker Pulls](https://img.shields.io/docker/pulls/psyb0t/codexbox?style=flat-square)](https://hub.docker.com/r/psyb0t/codexbox)

[OpenAI Codex CLI](https://github.com/openai/codex) inside an [aicodebox](https://github.com/psyb0t/docker-aicodebox) container. Minimal and toolchain-loaded images, five ways in: interactive shell, one-shot exec, OpenAI-compatible endpoint, MCP server, Telegram bot, and a cron scheduler that fires codex on whatever schedule you want.

You talk to codexbox. codexbox talks to codex. codex talks to OpenAI — or your ChatGPT subscription. Nobody cares about the middle.

## Table of Contents

- [Quick start](#quick-start)
- [Using the `codexbox` wrapper](#using-the-codexbox-wrapper)
- [Image variants](#image-variants)
- [Modes](#modes)
  - [API mode](docs/modes/api.md)
  - [Telegram mode](docs/modes/telegram.md)
  - [Cron mode](docs/modes/cron.md)
  - [MCP mode](docs/modes/mcp.md)
- [Configuration](#configuration)
- [Auth](#auth)
- [Agent integrations](#agent-integrations)
- [Development](#development)
- [Tests](#tests)
- [License](#license)

## Quick start

Docker installed and running is the only prerequisite.

### One-liner install

The installer pulls the selected image, creates the persistent Codex and SSH
directories, downloads the wrapper, and installs `codexbox` on your `PATH`.

```bash
# minimal image — default
curl -fsSL https://raw.githubusercontent.com/psyb0t/docker-codexbox/master/install.sh | bash

# full image — every development tool pre-installed
export CODEXBOX_FULL=1 && curl -fsSL https://raw.githubusercontent.com/psyb0t/docker-codexbox/master/install.sh | bash

# custom command name
curl -fsSL https://raw.githubusercontent.com/psyb0t/docker-codexbox/master/install.sh | bash -s -- codex
```

Installing with `CODEXBOX_FULL=1` bakes `latest-full` into the wrapper, so the
choice persists; you do not need to export it again. `CODEXBOX_FULL` must be
set for `bash`, not merely for `curl`, hence the `export … &&` form above.

### Local checkout

From a checkout of this repository, build the matching image and install the
local wrapper without pulling a published codexbox image:

```bash
make install       # minimal image
make install-full  # full image

# install only the local wrapper; do not build or pull
make install-wrapper
CODEXBOX_FULL=1 make install-wrapper  # full image
```

These targets set `CODEXBOX_SRC_LOCAL=true`. `make install` and `make
install-full` build their image first; `make install-wrapper` only installs the
local `wrapper.sh` against the selected existing image. It fails if that image
is absent instead of falling back to `docker pull`.

## Using the `codexbox` wrapper

The wrapper mounts the current directory as the workspace, persists `~/.codex`
(so login survives container recreation), forwards auth and configured
environment variables, and manages a per-directory container.

```bash
export OPENAI_API_KEY=sk-...         # or use a subscription: `codexbox login --device-auth`

codexbox                             # interactive TUI — continues the last session for THIS dir
codexbox --no-continue               # same, but starts a brand-new session instead
codexbox exec "fix the failing test in ./app"   # one-shot codex exec, output to your terminal
echo "summarize README.md" | codexbox exec -     # prompt via stdin
codexbox login --device-auth         # ChatGPT-subscription OAuth login (persists in ~/.codex)
codexbox login status                # which auth mode is active
codexbox --version                   # passthrough to `codex --version`
codexbox stop                        # stop this dir's running container(s)
codexbox clear-session               # drop codex's saved sessions (keeps auth + config)
```

The wrapper forwards `"$@"` straight to the image, so any `codex` subcommand works (`codexbox mcp ...`, `codexbox doctor`, etc.). The sandbox-bypass flag is injected inside the container — you never pass it yourself.

The bare interactive TUI defaults to **continuing the most recent session for the directory you're in** (same idea as claudebox's default) — codex's own `resume --last` cwd-scopes the lookup and starts a fresh session automatically when there's nothing to resume, so this is safe on a brand-new workspace too. Pass `--no-continue` to force a fresh session instead.

### Manual Docker use

Use raw Docker only when you intentionally do not want the wrapper, such as a
one-shot run or a long-running API service. The [Modes](#modes) section has
the relevant commands and configuration.

## Image variants

- `psyb0t/codexbox:latest` is the default minimal image: Codex, Node.js, Python, `uv`, Docker, Git, `jq`, and `curl`.
- `psyb0t/codexbox:latest-full` adds the general-purpose development toolchain from Claudebox's full image while retaining Codexbox's own adapter, entrypoint, auth, and config.

`CODEXBOX_FULL` is binary: unset or `0` selects minimal; `1` selects full. Any other value fails. The installer writes the resolved image into the installed wrapper, so the choice persists without exporting the variable on every run. A runtime `CODEXBOX_FULL=0` or `CODEXBOX_FULL=1` temporarily forces a variant; `CODEXBOX_IMAGE` remains the highest-priority explicit override.

The full image adds:

- Go 1.26.7 with gopls, Delve, golangci-lint, staticcheck, gofumpt, and test/code-generation helpers
- Python 3.14.7 with pytest, Black, Flake8, mypy, Pyright, Poetry, Pipenv, and common HTTP/parsing libraries
- JavaScript and TypeScript linting, formatting, process, framework, API-test, static-server, Lighthouse, and Storybook CLIs
- GitHub CLI, Terraform, kubectl, and Helm
- Build tools, CMake, ClangFormat, Valgrind, GDB, strace, and ltrace
- PostgreSQL, MySQL, SQLite, and Redis clients
- Vim, Nano, tmux, htop, archive tools, network diagnostics, ripgrep, fd, bat, eza, shellcheck, and shfmt

The full variant is reproducible by design: its minimal parent and the
published aicodebox parent are digest-pinned; Node tools install through a
committed pnpm lockfile with lifecycle scripts disabled; Python tools install
from a committed hash-locked requirements file; and Go tools build from a
committed `go.sum` with the checksum database enabled. The lock inputs use a
fixed seven-day release-age cutoff and are refreshed deliberately, not during
an ordinary image build.

**Licensing note:** the minimal image is clean — just Apache-2.0 Codex on
top of the aicodebox base. The full image additionally bundles HashiCorp
Terraform, which is BUSL-1.1 (source-available, non-compete), not
OSI-approved open source. If that matters to your use case, stick to the
minimal image or review the [BUSL-1.1 terms](https://github.com/hashicorp/terraform/blob/main/LICENSE)
yourself before using `latest-full`. Full breakdown in
[THIRD_PARTY.md](THIRD_PARTY.md).

### Wrapper environment variables

Set these on the host before running `codexbox`:

| Var | Default | What it does |
|-----|---------|---------------|
| `OPENAI_API_KEY` | — | API-key auth (seeded into `~/.codex/auth.json` on boot). Not needed for subscription login. |
| `OPENAI_BASE_URL` | — | Point codex at an OpenAI-compatible endpoint |
| `CODEXBOX_IMAGE` | installed image | Override the image the wrapper runs |
| `CODEXBOX_FULL` | installed choice (`0` initially) | `0` forces minimal; `1` forces full |
| `CODEXBOX_DATA_DIR` | `~/.codex` | Host dir mounted as `CODEX_HOME` (auth + config + sessions) |
| `CODEXBOX_SSH_DIR` | `~/.ssh/codexbox` | SSH key dir mounted into the container (for git over SSH) |
| `CODEXBOX_MAX_MEM` | `10g` | Per-container memory limit |
| `CODEXBOX_CONTAINER_NAME` | derived from `$PWD` | Override the per-workspace container name |
| `CODEXBOX_ENV_*` | — | Forward arbitrary env into the container (prefix stripped: `CODEXBOX_ENV_FOO=bar` → `FOO=bar`) |
| `CODEXBOX_MOUNT_*` | — | Mount extra host dirs (`/host:/container` syntax, or a bare path for same-path-both-sides) |

`CODEXBOX_MODE_CRON=1` + `CODEXBOX_MODE_CRON_FILE=/path/cron.yaml codexbox` starts the cron scheduler as a long-running background container instead.

**Prefer no host install?** Everything the wrapper does is plain `docker run`; see [Manual Docker use](#manual-docker-use) and [Modes](#modes).

## Modes

**Foreground modes** (API / Telegram / Cron) are mutually exclusive — except `CODEXBOX_TELEGRAM_MODE=1` + `CODEXBOX_CRON_MODE=1`, which run together (cron in-thread inside telegram). API wins if set alongside anything else.

**MCP mode** (`CODEXBOX_MCP_MODE=1`) is independent — it coexists with whatever foreground mode is running. In API mode it's mounted at `/mcp` on the API port; in other modes it runs as a sidecar uvicorn on its own port.

Each mode has its own page with full setup, env vars, and examples.

### [API Mode →](docs/modes/api.md)

Long-lived FastAPI server on `:8080`. Agent runs (sync, async with run-id polling, cancellable), workspace file upload/download/list/delete with traversal checking, and an OpenAI-compatible `chat/completions` endpoint with streaming and client-executed tool calling. Codex's native `--output-schema` backs `jsonSchema`, so schema-conforming output needs no retries.

```yaml
environment:
  - CODEXBOX_API_MODE=1
  - CODEXBOX_API_MODE_TOKEN=your-secret
  - CODEXBOX_AVAILABLE_MODELS=gpt-5.1-codex,gpt-5.1-codex-mini
```

### [Telegram Mode →](docs/modes/telegram.md)

Talk to codex from Telegram. Per-chat isolated workspaces, allowed-chats and per-chat allowed-users gating, file ingestion, `[SEND_FILE: path]` to get files back, and per-chat `/model`, `/effort`, `/system_prompt`, `/append_system_prompt` overrides that persist across restarts.

```yaml
environment:
  - CODEXBOX_TELEGRAM_MODE=1
  - CODEXBOX_TELEGRAM_MODE_TOKEN=123456:ABC
```

### [Cron Mode →](docs/modes/cron.md)

YAML-defined scheduled jobs on 6-field croniter schedules. Per-run history dirs with `meta.json`, `stdout.log`, `stderr.log`, `result.txt`, and a "prior run" hint so a job can reference its own history.

```yaml
environment:
  - CODEXBOX_CRON_MODE=1
  - CODEXBOX_CRON_MODE_FILE=/home/aicode/.aicodebox/cron.yaml
```

### [MCP Mode →](docs/modes/mcp.md)

Exposes `run_prompt` plus workspace-confined file tools over streamable HTTP, so other agents can drive codex as a tool. Coexists with any foreground mode — mounted at `/mcp` on the API port in API mode, a sidecar on its own port everywhere else. Distinct from codex's own MCP client/server support, which codexbox does not wire up.

```yaml
environment:
  - CODEXBOX_MCP_MODE=1
  - CODEXBOX_MCP_MODE_TOKEN=your-secret
```

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

Each mode's own knobs (ports, tokens, config paths, history dirs) live on that mode's page: [api.md](docs/modes/api.md), [telegram.md](docs/modes/telegram.md), [cron.md](docs/modes/cron.md), [mcp.md](docs/modes/mcp.md).

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
- Session: a call with neither `resume` nor `noContinue` continues the top-level
  Codex `exec` session pinned to that canonical workspace. The first call starts
  a persistent root session; later calls resume its exact ID, so a newer
  subagent rollout cannot steal continuation. Existing workspaces migrate their
  newest top-level `exec` rollout automatically. `resume` targets and re-pins a
  specific session ID; `noContinue` runs ephemerally without changing the pin.

## Agent integrations

The [skill](.agents/skills/codexbox) works in any agent that reads `.agents/skills/`, and installs natively in the clients below.

### Claude Code

```bash
claude plugin marketplace add psyb0t/agents
claude plugin install codexbox@psyb0t
```

Claude Code prompts for the codexbox URL and, if the API/MCP tokens are set on the server, the matching bearer tokens — sensitive values are stored in your OS keychain.

### Codex

```bash
codex plugin marketplace add psyb0t/agents
codex plugin add codexbox@psyb0t
```

Installed via the marketplace, the skill is invoked as `$codexbox:codexbox`. Codex also picks the skill up automatically, with no install, in any repo containing `.agents/skills/` — there it's invoked as plain `$codexbox`.

### OpenClaw

The skill is published to ClawHub on every release:

```bash
openclaw skills install @psyb0t/codexbox
```

For MCP clients that speak local stdio, the [`@psyb0t/codexbox`](.agents/plugins/codexbox) plugin bridges to a running box's `/mcp` endpoint:

```bash
openclaw plugins install clawhub:@psyb0t/codexbox
```

Then set `CODEXBOX_URL` (and `CODEXBOX_MCP_MODE_TOKEN` if the server was started with it set).

## Development

Requires `psyb0t/docker-aicodebox` checked out next to this repo (`../docker-aicodebox`).

```bash
make help        # list targets
make build-base  # build aicodebox-base from ../docker-aicodebox
make build       # build codexbox:local on top of it
make build-full  # build + tag the full toolchain variant
make build-all   # build both variants
make test        # run the full e2e suite (needs .env.test)
make test-image-select # hermetic installer/wrapper variant regression
make test-full-image   # build full and check every advertised tool
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

`make test-image-select` needs neither credentials nor a Docker daemon. It proves `CODEXBOX_FULL=0|1` selects, pulls, and bakes the same image. `make test-full-image` builds `latest-full` and checks its variant marker, Codex, pinned Go/Python versions, and the advertised CLI matrix.

## License

WTFPL — see [LICENSE](LICENSE). Do what the fuck you want.

Third-party components bundled in the published images (Codex, and — full
image only — Terraform, gh, kubectl, Helm, golangci-lint) keep their own
licenses; see [THIRD_PARTY.md](THIRD_PARTY.md).
