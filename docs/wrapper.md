---
title: "The codexbox wrapper"
description: "The codexbox host command: its subcommands, the per-directory container, host settings, CODEXBOX_ENV_ forwarding, sibling boxes and SSH agents."
nav_order: 3
---

# The codexbox wrapper

[`wrapper.sh`](https://github.com/psyb0t/docker-codexbox/blob/main/wrapper.sh) is the `codexbox` command on your host. It mounts the current directory as the workspace at the same path, mounts `~/.codex` as `CODEX_HOME` so logins and sessions survive container recreation, mounts `~/.ssh/codexbox` and the Docker socket, forwards auth and the variables you choose, and manages one container per directory. It runs every container with `--network host`.

The wrapper decides nothing about Codex flags. It passes your arguments to the image, where [`codexbox-agent.sh`](https://github.com/psyb0t/docker-codexbox/blob/main/codexbox-agent.sh) adds `--dangerously-bypass-approvals-and-sandbox` to `exec` and the TUI. You never pass that flag yourself.

## Commands

```bash
export OPENAI_API_KEY=sk-...        # or: codexbox login --device-auth

codexbox                            # Codex TUI, continuing the last session for this directory
codexbox --no-continue              # Codex TUI, new session
codexbox exec "fix the failing test in ./app"
echo "summarize README.md" | codexbox exec -
codexbox login --device-auth        # ChatGPT subscription login, stored in ~/.codex
codexbox login status               # which auth mode is active
codexbox --version                  # codex --version
codexbox stop                       # stop this directory's running containers
codexbox clear-session              # delete saved Codex sessions, keep auth and config
```

Any other Codex subcommand works the same way, such as `codexbox mcp ...` or `codexbox doctor`.

| Invocation | Container |
| --- | --- |
| bare `codexbox`, or arguments that are not a known subcommand | A persistent container named `codex-<directory path with / turned into _>`. An existing one is restarted with `docker start -ai`. If it is busy, the wrapper waits up to three times before it gives up. |
| `exec` or `e` | A throwaway `--rm` container named `<name>_prog` |
| a Codex management subcommand, listed below | A throwaway `--rm` container, Codex run verbatim |
| `stop` | Stops `<name>` and `<name>_cron` if they are running |
| `clear-session` | Deletes `sessions` and `archived_sessions` under the host Codex directory |

The management subcommands are `login`, `logout`, `mcp`, `mcp-server`, `app-server`, `remote-control`, `completion`, `update`, `doctor`, `sandbox`, `debug`, `plugin`, `review`, `apply`, `a`, `resume`, `archive`, `delete`, `unarchive`, `fork`, `cloud`, `exec-server`, `features`, `help`, `-V`, `--version`, `-h` and `--help`. The same list lives in the wrapper and in `codexbox-agent.sh`.

The bare TUI runs `codex resume --last`. Codex scopes that lookup to the current directory and starts a fresh session when there is nothing to resume, so it is safe in a new workspace. `--no-continue` is a codexbox flag, removed before Codex sees the arguments.

The wrapper attaches a TTY only when both stdin and stdout are terminals, so `codexbox exec "..." | jq` works.

## Host settings

Set these on the host before running `codexbox`.

| Variable | Default | What it does |
| --- | --- | --- |
| `OPENAI_API_KEY` | none | API-key auth, seeded into `~/.codex/auth.json` the first time each container starts. Not needed with a subscription login. |
| `OPENAI_BASE_URL` | none | Point Codex at an OpenAI-compatible endpoint |
| `CODEXBOX_IMAGE` | installed image | Run this image, whatever `CODEXBOX_FULL` says |
| `CODEXBOX_FULL` | installed choice | `0` forces the minimal image, `1` the full image. Any other value fails. |
| `CODEXBOX_DATA_DIR` | `~/.codex` | Host directory mounted as `CODEX_HOME`: auth, config, sessions and the per-workspace session pins |
| `CODEXBOX_SSH_DIR` | `~/.ssh/codexbox` | Host directory mounted as `/home/aicode/.ssh` |
| `CODEXBOX_MAX_MEM` | `10g` | Memory and swap limit of the persistent container |
| `CODEXBOX_CONTAINER_NAME` | derived from `$PWD` | Name of the persistent container |
| `CODEXBOX_GIT_NAME`, `CODEXBOX_GIT_EMAIL` | empty | Global Git identity of the runtime user. See [Configuration](configuration.md#git-identity). |
| `CODEXBOX_ENV_<NAME>` | none | Forwarded into the container as `<NAME>`. `CODEXBOX_ENV_FOO=bar` becomes `FOO=bar`. |
| `CODEXBOX_MOUNT_<ANY>` | none | Extra mount. `/host:/container` is passed to `docker -v` as is; a bare path is mounted at the same path. |
| `AICODEBOX_ENV_<NAME>`, `AICODEBOX_MOUNT_<ANY>` | none | The same, under the names every aicodebox wrapper reads |
| `CODEXBOX_ENV_OPENAI_API_KEY`, `CODEXBOX_ENV_OPENAI_BASE_URL` | none | Win over the bare `OPENAI_*` names |
| `CODEXBOX_ENV_DEBUG` or `DEBUG` | empty | `true` prints wrapper debug lines and passes `DEBUG=true` into the container |

Container settings, such as the server mode flags, are not read from the host. Forward them with `CODEXBOX_ENV_`:

```bash
CODEXBOX_ENV_CODEXBOX_API_MODE=1 \
CODEXBOX_ENV_CODEXBOX_AVAILABLE_MODELS=your-model-id \
CODEXBOX_ENV_CODEXBOX_API_MODE_TOKEN=your-api-token \
codexbox
```

A bare `CODEXBOX_API_MODE=1 codexbox` does not start the server.

### Cron through the wrapper

The wrapper has its own trigger for a background cron container:

```bash
CODEXBOX_MODE_CRON=1 \
CODEXBOX_MODE_CRON_FILE=/path/to/cron.yaml \
codexbox
```

It starts or restarts a detached container named `<name>_cron` with `CODEXBOX_CRON_MODE=1` and, when given, `CODEXBOX_CRON_MODE_FILE`. The file path is read inside the container, so it has to be under the mounted workspace or another mount. `codexbox stop` stops it. Mind the word order. `CODEXBOX_MODE_CRON` is the host trigger, `CODEXBOX_CRON_MODE` is the container setting. [Cron mode](modes/cron.md) covers the job file.

## Agents and nested launches

People and agents should both use the installed wrapper. An agent runs `codexbox` from the workspace it was asked to work in, instead of writing its own `docker run`. The wrapper keeps the workspace path, Codex state, SSH state, image choice and container lifecycle right.

```bash
codexbox exec "inspect this workspace and report the failing tests"
CODEXBOX_FULL=1 codexbox exec "run the full test suite"
printf '%s\n' "summarize README.md" | codexbox exec -
```

Install `codexbox`, `claudebox` and `pibox` in the same command directory, normally `/usr/local/bin`, when one box needs to launch another. The wrapper finds the sibling wrapper files there and mounts each one read-only at `/usr/local/bin/<name>` in the container. A sibling started from inside a box runs through the host Docker daemon and mounts its own host data directory. codexbox never mounts another agent's home directly.

The parent wrapper passes the host paths in `AICODEBOX_HOST_*` variables, with `AICODEBOX_LAUNCH_CONTEXT_VERSION=1`. They are set automatically. Do not set them, copy wrapper files, or mount another box's state directory by hand.

## SSH agent

The wrapper does not forward an SSH agent on its own. To give the box yours, mount the socket and point `SSH_AUTH_SOCK` at it:

```bash
CODEXBOX_MOUNT_SSH="$SSH_AUTH_SOCK:/ssh-agent:ro" \
CODEXBOX_ENV_SSH_AUTH_SOCK=/ssh-agent \
codexbox
```

Every key loaded in that agent becomes usable inside the box.

## Without the wrapper

Use raw `docker run` only for a deliberate container deployment, such as a server in Compose. The [Modes](modes.md) pages have those setups, and [Authentication](auth.md) shows the `docker run` form for logging in.
