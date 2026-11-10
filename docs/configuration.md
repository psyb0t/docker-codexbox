---
title: "Configuration"
description: "Every codexbox container setting: CODEXBOX_ names and their AICODEBOX_ aliases, mode flags, workspace, models, Git identity, init scripts and ports."
nav_order: 5
---

# Configuration

These settings are read inside the container. Pass them with `-e` or an env file on a direct `docker run`, or as `CODEXBOX_ENV_<NAME>` through the [wrapper](wrapper.md#host-settings). [`.env.example`](https://github.com/psyb0t/docker-codexbox/blob/main/.env.example) lists them for `docker run --env-file`.

## Naming

`CODEXBOX_<MODE>_MODE=1` turns a mode on, and `CODEXBOX_<MODE>_MODE_<KNOB>` configures it. Settings that belong to no mode have bare names, such as `CODEXBOX_WORKSPACE`.

The runtime belongs to the [aicodebox](https://psyb0t.github.io/docker-aicodebox/) base image, which reads `AICODEBOX_*` names. The codexbox [entrypoint](https://github.com/psyb0t/docker-codexbox/blob/main/codexbox-entrypoint.sh) copies each `CODEXBOX_<X>` to `AICODEBOX_<X>` when the `AICODEBOX_` one is unset or empty, then starts the base entrypoint. So both names work, and `AICODEBOX_*` wins when both are set. The aliased suffixes are:

`API_MODE`, `API_MODE_PORT`, `API_MODE_TOKEN`, `TELEGRAM_MODE`, `TELEGRAM_MODE_TOKEN`, `TELEGRAM_MODE_CONFIG`, `TELEGRAM_MODE_OVERRIDES`, `CRON_MODE`, `CRON_MODE_FILE`, `CRON_MODE_HISTORY_DIR`, `MCP_MODE`, `MCP_MODE_PORT`, `MCP_MODE_TOKEN`, `MCP_MODE_ALLOWED_HOSTS`, `MCP_MODE_ALLOWED_ORIGINS`, `WORKSPACE`, `AVAILABLE_MODELS`, `AVAILABLE_EFFORTS`, `CONTAINER_NAME`, `GIT_NAME`, `GIT_EMAIL`.

## Mode flags

| Variable | Default | What it does |
| --- | --- | --- |
| `CODEXBOX_API_MODE` | `0` | Run the HTTP API server in the foreground |
| `CODEXBOX_TELEGRAM_MODE` | `0` | Run the Telegram bot in the foreground |
| `CODEXBOX_CRON_MODE` | `0` | Run the cron scheduler in the foreground, or inside the bot when Telegram is also on |
| `CODEXBOX_MCP_MODE` | `0` | Serve MCP, at `/mcp/` in API mode or as a separate server otherwise |

[Modes](modes.md) explains how they combine. Each mode's own settings, such as ports, tokens and file paths, are on its page.

## Workspace and runtime

| Variable | Default | What it does |
| --- | --- | --- |
| `CODEXBOX_WORKSPACE` | `/workspace` | Workspace root in the container. The wrapper sets it to your host directory's path. |
| `CODEXBOX_CONTAINER_NAME` | `aicodebox` | Names the container-scoped state files. The wrapper sets it to the container name. |
| `CODEXBOX_AVAILABLE_MODELS` | none | Comma-separated model list served at `/openai/v1/models` and offered by the Telegram `/model` picker. API mode refuses to start without it, because Codex declares no model list of its own. |
| `CODEXBOX_AVAILABLE_EFFORTS` | `none,minimal,low,medium,high,xhigh,max` | Comma-separated list offered by the Telegram `/effort` picker |
| `OPENAI_API_KEY` | none | API-key login. See [Authentication](auth.md). |
| `OPENAI_BASE_URL` | none | OpenAI-compatible endpoint for Codex |
| `DEBUG` | `false` | `true` turns on debug logging |

### Codex defaults for the workspace

The [init script](https://github.com/psyb0t/docker-codexbox/blob/main/codexbox/init.d/10-codex-auth-config.sh) adds a `[projects."<workspace>"]` table with `trust_level = "trusted"` to `$CODEX_HOME/config.toml` when that table is missing, so Codex does not ask whether to trust the workspace.

Two settings give Codex a default model and reasoning effort on the shell path (the interactive TUI, `codexbox exec` and a bare `codexbox "<prompt>"`):

| Variable | Default | What it does |
| --- | --- | --- |
| `CODEXBOX_MODEL` | none | Passed to Codex as `-c model="..."` |
| `CODEXBOX_REASONING_EFFORT` | none | Passed to Codex as `-c model_reasoning_effort="..."`. Codex accepts `none`, `minimal`, `low`, `medium`, `high`, `xhigh` and `max`. |

`codexbox-agent` reads them on every run and puts them before your own arguments, so `-m` or `-c` on the command line still wins. Nothing is written to `config.toml`. Management subcommands such as `login`, `resume` and `review` run without them. Neither has an `AICODEBOX_` alias, and neither sets the model of an API, MCP, Telegram or cron run; those take the model from the request or job. Through the wrapper, set them on the host as `CODEXBOX_ENV_CODEXBOX_MODEL` and `CODEXBOX_ENV_CODEXBOX_REASONING_EFFORT`.

### Git identity

`CODEXBOX_GIT_NAME` and `CODEXBOX_GIT_EMAIL` set the runtime user's global Git `user.name` and `user.email` before the init scripts run. Nonempty `AICODEBOX_GIT_NAME` and `AICODEBOX_GIT_EMAIL` take precedence. Through the wrapper, pass the codexbox names on the host as they are, or the shared ones as `AICODEBOX_ENV_AICODEBOX_GIT_NAME` and `AICODEBOX_ENV_AICODEBOX_GIT_EMAIL`. Empty values leave the existing Git config alone. Values with a newline are rejected.

## Fixed by the image

These are set in the Dockerfiles. Do not change them.

| Variable | Value | Purpose |
| --- | --- | --- |
| `CODEX_HOME` | `/home/aicode/.codex` | Codex's auth, config and sessions. Mount it to keep them. |
| `AICODEBOX_ADAPTER` | `codexbox.adapter:CodexAdapter` | The adapter the server modes load |
| `AICODEBOX_AGENT_BINARY` | `codexbox-agent` | The command the shell and passthrough path runs |
| `CODEXBOX_IMAGE_VARIANT` | `minimal` or `full` | Which variant this image is |

## Init scripts and user bin

`$HOME/.aicodebox/bin` comes first on `PATH`, for Codex, for init scripts and for `docker exec` shells. Put your own scripts there.

`$HOME/.aicodebox/init.d/*.sh` run once per container, after the image's own `/aicodebox-init.d/*.sh`, as `aicode` with passwordless sudo. A failing script is logged and the rest still run. Mount `$HOME/.aicodebox` (`/home/aicode/.aicodebox`) to supply either directory. A new container runs init again even with a previously used `$HOME/.aicodebox`, so your scripts have to be safe to repeat.

## Ports

| Port | Setting | Service |
| --- | --- | --- |
| 8080 | `CODEXBOX_API_MODE_PORT` | HTTP API, with MCP at `/mcp/` when `CODEXBOX_MCP_MODE=1` |
| 8081 | `CODEXBOX_MCP_MODE_PORT` | Separate MCP server, only when MCP is on and API mode is not |

Telegram, cron and shell containers open no port unless MCP mode is on. The wrapper runs containers with host networking, so a server started through it listens on the host directly.
