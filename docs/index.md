---
title: "Home"
description: "codexbox runs the OpenAI Codex CLI in a Docker container, with a host wrapper, an HTTP API, an OpenAI-compatible endpoint, MCP, Telegram and cron."
nav_order: 1
permalink: /
seo:
  type: WebSite
---

# codexbox

[OpenAI Codex CLI](https://github.com/openai/codex) inside an [aicodebox](https://github.com/psyb0t/docker-aicodebox) container. You talk to codexbox, codexbox talks to Codex, and Codex talks to OpenAI with an API key or your ChatGPT subscription.

The image is `psyb0t/codexbox`. It ships in a minimal variant and a full variant with every common development toolchain installed. The `codexbox` command on your host mounts the current directory into the container and runs Codex there with its approval prompts and its own sandbox turned off, because the container is the sandbox.

## Ways in

| Way in | What you get | Page |
| --- | --- | --- |
| Interactive shell | The Codex TUI in your current directory, continuing the last session | [The codexbox wrapper](wrapper.md) |
| One-shot exec | `codexbox exec "..."`, output to your terminal | [The codexbox wrapper](wrapper.md#commands) |
| API mode | `POST /run`, workspace files over HTTP, an OpenAI-compatible `chat/completions` endpoint | [API mode](modes/api.md) |
| MCP mode | `run_prompt` and workspace file tools over streamable HTTP | [MCP mode](modes/mcp.md) |
| Telegram mode | Codex in a Telegram chat, one workspace per chat | [Telegram mode](modes/telegram.md) |
| Cron mode | Codex jobs on 6-field cron schedules, with run history | [Cron mode](modes/cron.md) |

## Quick start

Docker is the only prerequisite.

```bash
curl -fsSL https://raw.githubusercontent.com/psyb0t/docker-codexbox/main/install.sh | bash

codexbox login --device-auth   # ChatGPT subscription, or export OPENAI_API_KEY=sk-...
codexbox                       # Codex TUI in the current directory
codexbox exec "fix the failing test in ./app"
```

[Install](install.md) covers the full image, local builds and the installer settings. [Authentication](auth.md) explains the two ways Codex logs in.

## What codexbox adds to aicodebox

The HTTP API, MCP server, Telegram bot and cron scheduler belong to the shared [aicodebox](https://psyb0t.github.io/docker-aicodebox/) base image. codexbox adds the Codex side:

- the Codex CLI, installed under `/home/aicode/.local` so `codex update` works as the runtime user;
- the [Codex adapter](codex-adapter.md), which turns a run request into `codex exec` arguments and reads Codex's JSON event stream back;
- an [init script](https://github.com/psyb0t/docker-codexbox/blob/main/codexbox/init.d/10-codex-auth-config.sh) that seeds API-key auth and trusts the workspace;
- an [entrypoint](https://github.com/psyb0t/docker-codexbox/blob/main/codexbox-entrypoint.sh) that accepts every setting under a `CODEXBOX_` name;
- the [host wrapper](wrapper.md) and its installer.

## Pages

- [Install](install.md): installer, local builds, image variants and licensing.
- [The codexbox wrapper](wrapper.md): host commands, host settings, nested launches and SSH.
- [Authentication](auth.md): API key or ChatGPT subscription, models and reasoning effort.
- [Configuration](configuration.md): container settings, name aliasing, init scripts and ports.
- [Modes](modes.md): how the server modes combine, with a page for each.
- [Codex adapter](codex-adapter.md): how run options map to Codex flags, and session continuation.
- [Agent integrations](agents.md): the skill and plugins for Claude Code, Codex and OpenClaw.
- [Troubleshooting](troubleshooting.md): error messages and their fixes.
- [Development](development.md): building, linting, testing, CI and releases.
