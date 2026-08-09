# Telegram Mode

`CODEXBOX_TELEGRAM_MODE=1` + `CODEXBOX_TELEGRAM_MODE_TOKEN=<token>`. Talk to codex from Telegram, with per-chat workspaces and settings that survive restarts.

## Setup

1. Create a bot with [@BotFather](https://t.me/BotFather) and copy the token.
2. Find the chat IDs you want to allow (a group's ID is negative, e.g. `-100123`).
3. Write a config yaml and point the container at it.

```yaml
# ~/.aicodebox/telegram.yml
allowed_chats: [-100123, 42]
default:
  model: gpt-5.1-codex
  workspace: shared
chats:
  -100123:
    workspace: alpha
    allowed_users: [10, 20]
```

```yaml
# docker-compose.yml
services:
  codexbox:
    image: psyb0t/codexbox:latest
    environment:
      - CODEXBOX_TELEGRAM_MODE=1
      - CODEXBOX_TELEGRAM_MODE_TOKEN=123456:ABC
    volumes:
      - ~/.aicodebox:/home/aicode/.aicodebox
      - ~/workspaces:/workspace
```

Config lives at `$HOME/.aicodebox/telegram.yml` by default — override with `CODEXBOX_TELEGRAM_MODE_CONFIG`.

## What it does

- Text in → codex runs → Markdown→HTML rendered response back.
- File uploads land in the chat's workspace. `[SEND_FILE: path]` in codex's output delivers workspace files as Telegram attachments.
- Per-chat overrides: `/model`, `/effort` (maps to codex's `model_reasoning_effort` levels), `/system_prompt`, `/append_system_prompt`. Persisted across restarts.
- `/cancel` kills the in-flight run. `/reload` re-reads config. `/config` dumps merged settings. `/fetch <path>` downloads a file.
- Replies to cron messages inject the job's instruction + result so codex has full context for follow-ups.

## Telegram mode environment variables

| Var | Default | What it does |
|-----|---------|---------------|
| `CODEXBOX_TELEGRAM_MODE` | `0` | Boot the Telegram bot (foreground) |
| `CODEXBOX_TELEGRAM_MODE_TOKEN` | — | Bot token from @BotFather |
| `CODEXBOX_TELEGRAM_MODE_CONFIG` | `~/.aicodebox/telegram.yml` | Path to the telegram config yaml |
| `CODEXBOX_TELEGRAM_MODE_OVERRIDES` | `~/.aicodebox/telegram_overrides.json` | Per-chat override store (model/effort/system prompts) |

The `/model` and `/effort` pickers are populated from `CODEXBOX_AVAILABLE_MODELS` and `CODEXBOX_AVAILABLE_EFFORTS`. Without `CODEXBOX_AVAILABLE_MODELS` the `/model` picker degrades to a "set this env var" reply — unlike API mode, telegram still boots.

> Every `CODEXBOX_*` variable is an alias for the `AICODEBOX_*` equivalent read by the base image. If both are set, `AICODEBOX_*` wins.

## Combined with cron mode

Telegram and cron are the one foreground pair that runs together — set both flags and cron runs in-thread inside telegram, which is what lets a job post its result into a chat and lets you reply to it. See [cron.md](cron.md).
