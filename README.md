# docker-codexbox

[![CI](https://github.com/psyb0t/docker-codexbox/actions/workflows/pipeline.yml/badge.svg?branch=main)](https://github.com/psyb0t/docker-codexbox/actions/workflows/pipeline.yml)
[![version](https://raw.githubusercontent.com/psyb0t/docker-codexbox/badges/version.svg)](https://github.com/psyb0t/docker-codexbox/releases)
[![license](https://raw.githubusercontent.com/psyb0t/docker-codexbox/badges/license.svg)](https://github.com/psyb0t/docker-codexbox/blob/main/LICENSE)
[![Docker Pulls](https://img.shields.io/docker/pulls/psyb0t/codexbox?style=flat-square)](https://hub.docker.com/r/psyb0t/codexbox)

[OpenAI Codex CLI](https://github.com/openai/codex) inside an [aicodebox](https://github.com/psyb0t/docker-aicodebox) container. Minimal and toolchain-loaded images, and six ways in: interactive shell, one-shot exec, an HTTP API with an OpenAI-compatible endpoint, an MCP server, a Telegram bot, and a cron scheduler that fires codex on whatever schedule you want.

You talk to codexbox. codexbox talks to codex. codex talks to OpenAI, or to your ChatGPT subscription. Nobody cares about the middle.

**Documentation: <https://psyb0t.github.io/docker-codexbox/>**

## Table of Contents

- [Quick start](#quick-start)
- [Image variants](#image-variants)
- [Modes](#modes)
- [Documentation](#documentation)
- [Agent integrations](#agent-integrations)
- [Development](#development)
- [Sponsor](#sponsor)
- [License](#license)

## Quick start

Docker installed and running is the only prerequisite. The installer pulls the image, creates `~/.codex` and `~/.ssh/codexbox`, and installs the `codexbox` command on your `PATH`.

```bash
# minimal image, the default
curl -fsSL https://raw.githubusercontent.com/psyb0t/docker-codexbox/main/install.sh | bash

# full image, every development tool installed
export CODEXBOX_FULL=1 && curl -fsSL https://raw.githubusercontent.com/psyb0t/docker-codexbox/main/install.sh | bash
```

Then log in once and go:

```bash
codexbox login --device-auth                     # ChatGPT subscription, or: export OPENAI_API_KEY=sk-...
codexbox                                         # Codex TUI, continuing the last session for THIS directory
codexbox --no-continue                           # same, but a brand-new session
codexbox exec "fix the failing test in ./app"    # one-shot, output to your terminal
echo "summarize README.md" | codexbox exec -     # prompt via stdin
codexbox stop                                    # stop this directory's containers
```

The wrapper mounts the current directory, keeps `~/.codex` so the login and sessions survive, and passes any other `codex` subcommand straight through. The sandbox-bypass flag is added inside the container; the container is the sandbox. Install routes, local builds and every wrapper setting are in [Install](https://psyb0t.github.io/docker-codexbox/install/) and [The codexbox wrapper](https://psyb0t.github.io/docker-codexbox/wrapper/).

## Image variants

- `psyb0t/codexbox:latest`: Codex, Node.js, Python, `uv`, Docker, Git, `jq` and `curl`, on `psyb0t/aicodebox:latest`.
- `psyb0t/codexbox:latest-full`: the same Codex layer on `psyb0t/aicodebox:latest-full`, with Go, Python, JavaScript and TypeScript tooling, GitHub CLI, Terraform, kubectl, Helm, debuggers and database clients.

The full image bundles Terraform, which is BUSL-1.1 and not OSI-approved open source. The [variant list and licensing notes](https://psyb0t.github.io/docker-codexbox/install/#image-variants) have the details, and [THIRD_PARTY.md](https://github.com/psyb0t/docker-codexbox/blob/main/THIRD_PARTY.md) lists every bundled component.

## Modes

Set a mode flag and the container becomes a service. API, Telegram and cron run in the foreground (API wins; Telegram and cron can run together). MCP runs next to any of them.

| Flag | What you get |
| --- | --- |
| `CODEXBOX_API_MODE=1` | `POST /run`, workspace files over HTTP, and an OpenAI-compatible `chat/completions` endpoint on `:8080`. Needs `CODEXBOX_AVAILABLE_MODELS`. |
| `CODEXBOX_TELEGRAM_MODE=1` | Codex in Telegram, one workspace per chat, per-chat `/model` and `/effort` |
| `CODEXBOX_CRON_MODE=1` | YAML jobs on 6-field cron schedules, with run history |
| `CODEXBOX_MCP_MODE=1` | `run_prompt` and workspace file tools over streamable HTTP |

```yaml
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
      - ~/workspaces:/workspace
```

An empty token means no auth on that surface. Each mode's page in the [documentation](https://psyb0t.github.io/docker-codexbox/modes/) has its settings and examples.

## Documentation

The full documentation lives at **<https://psyb0t.github.io/docker-codexbox/>**.

| Section | What it covers |
| --- | --- |
| [Install](https://psyb0t.github.io/docker-codexbox/install/) | Installer, local builds, upgrading, image variants and licensing |
| [The codexbox wrapper](https://psyb0t.github.io/docker-codexbox/wrapper/) | Commands, host settings, `CODEXBOX_ENV_` forwarding, sibling boxes, SSH agents |
| [Authentication](https://psyb0t.github.io/docker-codexbox/auth/) | API key or ChatGPT subscription, models and reasoning effort |
| [Configuration](https://psyb0t.github.io/docker-codexbox/configuration/) | Container settings, `AICODEBOX_` aliases, Git identity, init scripts, ports |
| [Modes](https://psyb0t.github.io/docker-codexbox/modes/) | [API](https://psyb0t.github.io/docker-codexbox/modes/api/), [Telegram](https://psyb0t.github.io/docker-codexbox/modes/telegram/), [cron](https://psyb0t.github.io/docker-codexbox/modes/cron/) and [MCP](https://psyb0t.github.io/docker-codexbox/modes/mcp/) |
| [Codex adapter](https://psyb0t.github.io/docker-codexbox/codex-adapter/) | How run options map to Codex flags, and session continuation |
| [Agent integrations](https://psyb0t.github.io/docker-codexbox/agents/) | The skill and plugins for Claude Code, Codex and OpenClaw |
| [Troubleshooting](https://psyb0t.github.io/docker-codexbox/troubleshooting/) | Error messages and their fixes |
| [Development](https://psyb0t.github.io/docker-codexbox/development/) | Building, linting, testing, CI and releases |

## Agent integrations

The [skill](https://github.com/psyb0t/docker-codexbox/tree/main/.agents/skills/codexbox) works in any agent that reads `.agents/skills/` (such as [peen](https://github.com/psyb0t/peen)) and installs natively in Claude Code, Codex and OpenClaw:

```bash
claude plugin marketplace add psyb0t/agents && claude plugin install codexbox@psyb0t
codex plugin marketplace add psyb0t/agents && codex plugin add codexbox@psyb0t
openclaw skills install @psyb0t/codexbox
```

The [`@psyb0t/codexbox`](https://github.com/psyb0t/docker-codexbox/tree/main/.agents/plugins/codexbox) OpenClaw plugin bridges stdio MCP clients to a running box. See [Agent integrations](https://psyb0t.github.io/docker-codexbox/agents/).

## Development

```bash
make help        # every target
make build       # minimal image on the published aicodebox base
make build-full  # full image
make lint        # shellcheck, shfmt, ruff and pyright, all in containers
make test-ci     # the credential-free tests CI runs
make test        # the end-to-end suite (needs .env.test)
make docs        # build the documentation site into .testing/docs-site
```

Details in [Development](https://psyb0t.github.io/docker-codexbox/development/).

## Sponsor

<a href="https://www.buymeacoffee.com/psyb0t"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-blue.png" alt="Buy Me a Coffee" height="60" width="217"></a>

## License

WTFPL, see [LICENSE](https://github.com/psyb0t/docker-codexbox/blob/main/LICENSE). Do what the fuck you want.

Third-party components bundled in the published images (Codex, and in the full image only Terraform, gh, kubectl, Helm and golangci-lint) keep their own licenses; see [THIRD_PARTY.md](https://github.com/psyb0t/docker-codexbox/blob/main/THIRD_PARTY.md).
