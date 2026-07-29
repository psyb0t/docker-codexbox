# codexbox setup

See [SKILL.md](../SKILL.md#security--safety) for the full destructive-operation and unauthenticated-surface warnings before running any mode that binds a port.

## Requirements

- Docker
- Codex auth: `OPENAI_API_KEY` (pay-as-you-go) or a ChatGPT Plus/Pro/Team subscription (`codexbox login --device-auth`)
- Optional: SSH key for git-over-SSH inside the container (the installer generates one)

## Quick Install (wrapper)

The one-liner installer pulls the image, creates persistent Codex/SSH dirs, and installs the `codexbox` wrapper on `PATH`.

**Recommended: download, inspect, then run.** Piping a remote script straight into bash executes unreviewed remote code as you. Download it, read it, then run it:

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/psyb0t/docker-codexbox/master/install.sh
less install.sh          # read it before running anything
bash install.sh          # minimal image — default
# CODEXBOX_FULL=1 bash install.sh        # full image — every development tool pre-installed
# bash install.sh codex                  # custom command name
```

`CODEXBOX_FULL=1` must be set before `install.sh` runs — the installer needs it in `bash`'s environment. The choice is baked into the installed wrapper; you don't need to set it again afterward.

### Install from a local checkout

From this repository, build and install without pulling a published codexbox
image:

```bash
make install       # minimal image
make install-full  # full image

# wrapper only — no build or pull; select full when needed
make install-wrapper
CODEXBOX_FULL=1 make install-wrapper
```

The installer-only `CODEXBOX_SRC_LOCAL=true` flag skips `docker pull` and
requires the selected local image to already exist. `make install-wrapper`
uses that existing image without rebuilding it.

**Verify:** `codexbox --version` should print the codex CLI version.

## Image Variants

| Image | Tag | Contents |
|---|---|---|
| Minimal (default) | `psyb0t/codexbox:latest` | Codex, Node.js, Python, `uv`, Docker, Git, `jq`, `curl` |
| Full | `psyb0t/codexbox:latest-full` | Everything in minimal + Go, gopls/Delve/golangci-lint/staticcheck/gofumpt, Python lint/type/test tooling, JS/TS lint/format/framework CLIs, GitHub CLI, Terraform, kubectl, Helm, build tools (CMake/ClangFormat/Valgrind/GDB/strace/ltrace), Postgres/MySQL/SQLite/Redis clients, editors/shell tools |

`CODEXBOX_FULL` is binary: unset or `0` selects minimal, `1` selects full — any other value fails. `CODEXBOX_IMAGE` is the highest-priority explicit override if you want a specific tag regardless of `CODEXBOX_FULL`.

## Manual Docker Use

Use raw Docker for one-shot runs or long-running API/Telegram/cron services (the wrapper is meant for the interactive per-directory shell case). All the `docker run` shapes for each mode are in [../SKILL.md](../SKILL.md).

Minimal foreground-mode boilerplate:

```bash
docker run -d --name codexbox \
  -e OPENAI_API_KEY=sk-... \
  -v "$PWD:/workspace" \
  -v "$HOME/.codex:/home/aicode/.codex" \
  <mode env vars here> \
  -p <port>:<port> \
  psyb0t/codexbox:latest
```

## Environment Variable Reference

### Wrapper-only (host-side, read by `wrapper.sh`, not passed into the container as-is)

| Var | Default | What it does |
|---|---|---|
| `OPENAI_API_KEY` | — | Forwarded into the container; seeds `auth.json` on boot |
| `OPENAI_BASE_URL` | — | Point codex at an OpenAI-compatible endpoint instead of the default API |
| `CODEXBOX_IMAGE` | installed image | Override the image the wrapper runs |
| `CODEXBOX_FULL` | installed choice (`0` initially) | `0` forces minimal, `1` forces full |
| `CODEXBOX_DATA_DIR` | `~/.codex` | Host dir mounted as `CODEX_HOME` (auth + config + sessions) |
| `CODEXBOX_SSH_DIR` | `~/.ssh/codexbox` | SSH key dir mounted into the container |
| `CODEXBOX_MAX_MEM` | `10g` | Per-container memory limit |
| `CODEXBOX_CONTAINER_NAME` | derived from `$PWD` | Override the per-workspace container name |
| `CODEXBOX_ENV_*` | — | Forward arbitrary env into the container (prefix stripped: `CODEXBOX_ENV_FOO=bar` → `FOO=bar` inside) |
| `CODEXBOX_MOUNT_*` | — | Mount extra host dirs (`/host:/container`, or a bare path for same-path-both-sides) |
| `CODEXBOX_MODE_CRON` / `CODEXBOX_MODE_CRON_FILE` | — | Wrapper trigger: starts the cron scheduler as a long-running background container instead of the interactive one. Translated internally to `CODEXBOX_CRON_MODE` / `CODEXBOX_CRON_MODE_FILE` inside the container. |

### Container-side mode flags

Naming convention: `CODEXBOX_<MODE>_MODE=1` is the on/off flag, `CODEXBOX_<MODE>_MODE_<KNOB>=...` is its config.

| Var | Default | What it does |
|---|---|---|
| `CODEXBOX_API_MODE` | `0` | Boot the HTTP API server (foreground) |
| `CODEXBOX_TELEGRAM_MODE` | `0` | Boot the Telegram bot (foreground) |
| `CODEXBOX_CRON_MODE` | `0` | Boot the cron scheduler (foreground; in-thread when telegram is also on) |
| `CODEXBOX_MCP_MODE` | `0` | Expose MCP — mounted at `/mcp` in API mode, or as a standalone sidecar elsewhere |

Foreground modes (API/Telegram/Cron) are mutually exclusive, except Telegram+Cron together (cron runs in-thread inside the telegram process). API wins if set alongside anything else. MCP mode is independent — it coexists with whatever foreground mode is running, or with none at all (shell-only + MCP sidecar).

### API mode config

| Var | Default | What it does |
|---|---|---|
| `CODEXBOX_API_MODE_PORT` | `8080` | Port the API server binds to |
| `CODEXBOX_API_MODE_TOKEN` | empty | Bearer token for the API surface (`/run`, `/files/*`, `/openai/v1/*`). Empty = no auth |

With `CODEXBOX_API_MODE_TOKEN` unset the API surface (`/run`, `/files/*`, `/openai/v1/*`) is unauthenticated — anyone who can reach it gets run-execution and full workspace file access. Set the token and bind to loopback / behind an authenticating proxy before exposing it beyond localhost.

### Telegram mode config

| Var | Default | What it does |
|---|---|---|
| `CODEXBOX_TELEGRAM_MODE_TOKEN` | — | Bot token from @BotFather |
| `CODEXBOX_TELEGRAM_MODE_CONFIG` | `~/.aicodebox/telegram.yml` | Path to the telegram config YAML |
| `CODEXBOX_TELEGRAM_MODE_OVERRIDES` | `~/.aicodebox/telegram_overrides.json` | Per-chat override store (model/effort/system prompts) |

### Cron mode config

| Var | Default | What it does |
|---|---|---|
| `CODEXBOX_CRON_MODE_FILE` | — | Path to the cron YAML |
| `CODEXBOX_CRON_MODE_HISTORY_DIR` | `~/.aicodebox/cron/history` | Where cron writes per-run history dirs (`meta.json`, `stdout.log`, `stderr.log`, `result.txt`, `telegram.json`) |

### MCP mode config

| Var | Default | What it does |
|---|---|---|
| `CODEXBOX_MCP_MODE_PORT` | `8081` | Port the sidecar MCP server binds to (ignored when mounted inside API mode) |
| `CODEXBOX_MCP_MODE_TOKEN` | empty | Bearer token for MCP. Empty = no auth. No fallback to `API_MODE_TOKEN` |

With `CODEXBOX_MCP_MODE_TOKEN` unset the MCP surface (`run_prompt`, `list_files`, `read_file`, `write_file`, `delete_file`) is unauthenticated — anyone who can reach it gets full workspace file access. This surface has its own bearer; setting `CODEXBOX_API_MODE_TOKEN` does not protect it. Set the token and bind to loopback / behind an authenticating proxy before exposing it beyond localhost.

### Workspace & runtime

| Var | Default | What it does |
|---|---|---|
| `CODEXBOX_WORKSPACE` | `/workspace` | Root workspace dir inside the container |
| `CODEXBOX_CONTAINER_NAME` | `aicodebox` | Scopes per-container state files (auth, etc.) |
| `CODEXBOX_AVAILABLE_MODELS` | — | **Required for API mode.** CSV list returned by `/openai/v1/models` and shown in the Telegram `/model` picker |
| `CODEXBOX_AVAILABLE_EFFORTS` | `none,minimal,low,medium,high,xhigh,max` | Override the effort/reasoning list shown by the Telegram `/effort` picker |
| `CODEXBOX_MODEL` | — | Default model passed to codex when a caller doesn't specify one |

Every `CODEXBOX_X` name above also works as `AICODEBOX_X` (the base image's native naming) — the entrypoint translates `CODEXBOX_X` to `AICODEBOX_X` when only the codexbox-prefixed one is set. If both are set, `AICODEBOX_X` wins.

## Ports

| Port | Default var | Service |
|---|---|---|
| 8080 | `CODEXBOX_API_MODE_PORT` | HTTP API (`/run`, `/files`, `/openai/v1/*`) + MCP mounted at `/mcp` when `CODEXBOX_MCP_MODE=1` |
| 8081 | `CODEXBOX_MCP_MODE_PORT` | Standalone MCP sidecar — only when MCP mode is on and API mode is not |

No port is exposed by default in Telegram-only or cron-only or shell-only deployments (they're outbound-only / no HTTP surface unless MCP mode is also enabled).

## Auth Setup

### API key

```bash
docker run --rm \
  -e OPENAI_API_KEY=sk-... \
  -v "$PWD/.codex:/home/aicode/.codex" \
  psyb0t/codexbox:latest \
  exec "say HELLO"
```

Seeded into `$CODEX_HOME/auth.json` on every boot (`codex login --with-api-key` under the hood). Safe to leave set permanently — it never overwrites an existing ChatGPT-subscription login.

### ChatGPT subscription

```bash
docker run -it \
  -v "$HOME/.codex:/home/aicode/.codex" \
  psyb0t/codexbox:latest \
  login --device-auth
```

Prints a URL + short code for one-time browser approval. `~/.codex` **must** be bind-mounted or the login is lost when the container is removed. Every later run against the same bind-mounted `~/.codex` reuses it, no `OPENAI_API_KEY` needed. `codex login status` reports the active mode; `codex logout` clears it.

## Management

```bash
codexbox stop              # stop this dir's running container(s)
codexbox clear-session      # drop saved codex sessions (keeps auth + config)
docker logs -f codexbox-api # tail logs for a manually-run named container
docker pull psyb0t/codexbox:latest   # update
```

## Development / Testing

Requires `psyb0t/docker-aicodebox` checked out next to this repo (`../docker-aicodebox`).

```bash
make help              # list targets
make build-base        # build aicodebox-base from ../docker-aicodebox
make build              # build codexbox:local on top of it
make build-full         # build + tag the full toolchain variant
make test               # run the full e2e suite (needs .env.test — OPENAI_API_KEY, optional Telegram creds)
```
