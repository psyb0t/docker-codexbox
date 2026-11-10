# docker-codexbox

Instructions for coding agents and contributors working in this repository. Read this file, then the rules in `.agents/rules/` that match what you are about to change.

## Agent setup

`CLAUDE.md` is a committed symlink to `AGENTS.md`, and `.claude` is a committed symlink to `.agents`, so Claude Code reads the same instructions, rules and skills as Codex. Claude's Edit and Write tools refuse to write through a symlink, so edit `AGENTS.md` and `.agents/rules/*.md` directly.

## What it is

Two Docker images, `psyb0t/codexbox:latest` (minimal) and `psyb0t/codexbox:latest-full`, that run the OpenAI Codex CLI on the shared aicodebox base (`psyb0t/aicodebox:latest` and `:latest-full`, from the sibling repository `psyb0t/docker-aicodebox`). The base owns the runtime: the entrypoint, the HTTP API, MCP, Telegram and cron modes, and the adapter contract. This repository adds the Codex side: the CLI install, the `CodexAdapter`, an init script for auth and workspace trust, a `CODEXBOX_*` entrypoint alias layer, and the host wrapper with its installer.

Documentation: https://psyb0t.github.io/docker-codexbox/, built from `docs/`.

## Architecture

- `Dockerfile`, `Dockerfile.full`: install `@openai/codex@${CODEX_VERSION}` under `/home/aicode/.local` (so `codex update` works as `aicode`), the `codexbox` Python package with `--no-deps`, the init script, `codexbox-agent` and `codexbox-entrypoint`. They set `AICODEBOX_ADAPTER=codexbox.adapter:CodexAdapter`, `AICODEBOX_AGENT_BINARY=codexbox-agent`, `CODEXBOX_IMAGE_VARIANT` and `CODEX_HOME=/home/aicode/.codex`. The two files differ only in base image and variant marker.
- `codexbox-entrypoint.sh`: copies each `CODEXBOX_<X>` in `_CODEXBOX_ALIASES` to `AICODEBOX_<X>` when the latter is empty, then execs `/usr/local/bin/aicodebox-entrypoint`.
- `codexbox-agent.sh`: the shell and passthrough path. Management subcommands run verbatim; `exec` and `e` get `--dangerously-bypass-approvals-and-sandbox`; a bare call runs `codex resume --last` with the bypass flag unless `--no-continue` is given.
- `codexbox/codexbox/adapter.py`: `CodexAdapter`, used by the server modes. `build_argv` turns a `RunRequest` into `codex exec ... --json --skip-git-repo-check ... -`; `parse_output`, `parse_events` and `parse_stream_event` read Codex's JSONL events. It pins one top-level `exec` session per workspace in `$CODEX_HOME/sessions/.codexbox-roots/<sha256>.json`.
- `codexbox/init.d/10-codex-auth-config.sh`: runs once per container. Seeds API-key auth with `codex login --with-api-key` unless a subscription login exists, and adds a trusted `[projects."<workspace>"]` table to `config.toml`.
- `wrapper.sh`: the host `codexbox` command. Mounts the workspace at the same path, `~/.codex`, `~/.ssh/codexbox` and the Docker socket, uses host networking, forwards `CODEXBOX_ENV_*` and `AICODEBOX_ENV_*`, mounts sibling wrappers, and manages one persistent container per directory plus `_prog` and `_cron` containers.
- `install.sh`: pulls or checks the image, creates the host directories and SSH key, and installs the wrapper with the chosen image written into `CODEXBOX_INSTALLED_IMAGE`.

Data flow in a server mode: client -> aicodebox mode (API, MCP, Telegram, cron) -> `CodexAdapter.build_argv` -> `codex exec --json` -> `CodexAdapter.parse_*` -> client. In the shell path: `codexbox` wrapper -> `docker run` -> `codexbox-entrypoint` -> `aicodebox-entrypoint` -> `codexbox-agent` -> `codex`.

## Stack

- Python 3.12+ package `codexbox` (hatchling), no runtime dependencies beyond the `aicodebox` package already in the base image. The base image runs Python 3.14.8.
- Dev tools pinned in `codexbox/pyproject.toml`: pytest 9.1.1, ruff 0.17.0 (line length 100, rule sets E, F, W, I, B, UP, SIM, C4, ARG), pyright 1.1.414.
- Bash for the wrapper, installer, entrypoint, agent launcher, init script and tests.
- Codex CLI pinned by `CODEX_VERSION` (0.162.1) in the `Makefile` and both Dockerfiles.
- Node.js for the OpenClaw MCP bridge in `.agents/plugins/codexbox` (`mcp-remote` 0.14.3).
- Docs: Jekyll on GitHub Pages with just-the-docs v0.12.0.

## Layout

| Path | What it holds |
| --- | --- |
| `Dockerfile`, `Dockerfile.full` | Minimal and full images |
| `codexbox/codexbox/` | `CodexAdapter` and the package version |
| `codexbox/tests/` | Adapter unit tests (pytest) |
| `codexbox/init.d/` | Image init scripts, copied to `/aicodebox-init.d/` |
| `codexbox-entrypoint.sh`, `codexbox-agent.sh` | Image entrypoint and agent launcher |
| `wrapper.sh`, `install.sh` | Host command and installer |
| `test.sh`, `tests/` | E2E runner (`tests/test_smoke.sh`, `tests/e2e-common.sh`) and standalone shell tests |
| `docs/` | Documentation site source, published from `main` |
| `.agents/skills/codexbox/` | The agent skill and `references/setup.md` |
| `.agents/plugins/codexbox/` | The OpenClaw stdio-to-HTTP MCP bridge |
| `.agents/.claude-plugin/`, `.agents/.codex-plugin/` | Claude Code and Codex plugin manifests |
| `.agents/rules/` | Rules for changes in this repository |
| `server.json`, `glama.json` | MCP Registry and Glama listings |
| `.github/workflows/pipeline.yml` | Lint, tests, image build, promotion and publishing |
| `THIRD_PARTY.md`, `LICENSES/` | Bundled third-party licenses |

## Commands

Docker, Make and Bash are enough for everything except `make test` and `make test-unit`.

```bash
make help                 # every target
make build                # minimal image on psyb0t/aicodebox:latest
make build-full           # full image on psyb0t/aicodebox:latest-full
make lint                 # shellcheck, shfmt -i 4 -ci, ruff check, ruff format --check, pyright; all in containers
make test-ci              # unit tests in the base image, image-select, managed-nested, entrypoint identity
make test-unit            # unit tests via uv; needs ../docker-aicodebox checked out
make test-full-image      # build full and check every advertised tool
make test                 # e2e suite; needs .env.test with OPENAI_API_KEY or a subscription login
make docs                 # build the docs site into .testing/docs-site
make version V=X.Y.Z      # sync version metadata without committing or tagging
```

CI (`.github/workflows/pipeline.yml`) runs `make lint` and `make test-ci` on every branch push.

## Rules

Read the matching files in `.agents/rules/` before editing:

- `code-style.md`: Python and shell conventions.
- `adapter.md`: the `CodexAdapter` contract and Codex flag mapping.
- `docker-images.md`: the two Dockerfiles, the entrypoint and the init script.
- `wrapper.md`: the host wrapper and installer.
- `testing.md`: which suite covers what, and what CI runs.
- `security.md`: secrets, auth seeding and exposed surfaces.
- `agent-surface.md`: the skill, plugin manifests and MCP bridge.
- `docs-and-releases.md`: the docs site, the README, CHANGELOG and versioning.
