---
title: "Modes"
description: "How codexbox's API, Telegram, cron and MCP modes start, which ones run together, and where MCP is served in each combination."
nav_order: 6
has_children: true
---

# Modes

Without a mode flag the container is a plain Codex shell: the [wrapper](wrapper.md) or `docker run ... psyb0t/codexbox` runs the Codex TUI or a Codex subcommand. A mode flag turns the container into a long-running service instead. The modes come from the [aicodebox](https://psyb0t.github.io/docker-aicodebox/) base; codexbox supplies the Codex adapter they run.

## Foreground modes

API, Telegram and cron are foreground modes, and the container lives as long as the one that runs. The base entrypoint picks one in this order:

1. `CODEXBOX_API_MODE=1` runs the API server, whatever else is set.
2. `CODEXBOX_TELEGRAM_MODE=1` with `CODEXBOX_CRON_MODE=1` runs the bot, with the scheduler in a thread inside it. This is the only pair that runs together.
3. `CODEXBOX_TELEGRAM_MODE=1` runs the bot.
4. `CODEXBOX_CRON_MODE=1` runs the scheduler.

## MCP

`CODEXBOX_MCP_MODE=1` is not a foreground mode. It runs alongside any of them, or alongside a plain shell:

| Foreground | Where MCP is served |
| --- | --- |
| API mode | `/mcp/` on the API port, in the same process |
| Telegram, cron, or none | A separate server on `CODEXBOX_MCP_MODE_PORT` (default `8081`), at the port root `/` |

## Pages

- [API mode](modes/api.md): agent runs, workspace files and the OpenAI-compatible endpoint over HTTP.
- [Telegram mode](modes/telegram.md): Codex in Telegram chats.
- [Cron mode](modes/cron.md): scheduled Codex jobs from a YAML file.
- [MCP mode](modes/mcp.md): Codex and workspace files as MCP tools.
