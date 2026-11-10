---
title: "Telegram mode"
description: "Run Codex from Telegram with codexbox: allowed chats and users, per-chat workspaces, file transfer, bot commands and per-chat overrides."
nav_order: 2
parent: "Modes"
---

# Telegram mode

`CODEXBOX_TELEGRAM_MODE=1` with `CODEXBOX_TELEGRAM_MODE_TOKEN=<token>` lets you talk to Codex from Telegram, with a workspace per chat and settings that survive restarts.

## Setup

1. Create a bot with [@BotFather](https://t.me/BotFather) and copy the token.
2. Find the chat IDs you want to allow. A group's ID is negative, such as `-100123`.
3. Write a config file and point the container at it.

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
      - CODEXBOX_AVAILABLE_MODELS=gpt-5.1-codex,gpt-5.1-codex-mini
      - OPENAI_API_KEY=sk-...
    volumes:
      - ~/.aicodebox:/home/aicode/.aicodebox
      - ~/workspaces:/workspace
```

The config is read from `$HOME/.aicodebox/telegram.yml` unless `CODEXBOX_TELEGRAM_MODE_CONFIG` points elsewhere.

## What it does

- A text message runs Codex, and the Markdown answer comes back rendered as Telegram HTML.
- Uploaded files land in the chat's workspace. `[SEND_FILE: path]` in Codex's answer sends that workspace file back as an attachment.
- Per-chat overrides: `/model`, `/effort` (Codex's `model_reasoning_effort` levels), `/system_prompt` and `/append_system_prompt`. They are stored in `CODEXBOX_TELEGRAM_MODE_OVERRIDES` and survive restarts.
- `/cancel` kills the run in flight, `/reload` reads the config again, `/config` shows the merged settings and `/fetch <path>` downloads a file.
- Replying to a cron message adds that job's instruction and result to the prompt, so Codex has the context for a follow-up.

## Telegram mode settings

| Variable | Default | What it does |
| --- | --- | --- |
| `CODEXBOX_TELEGRAM_MODE` | `0` | Run the Telegram bot in the foreground |
| `CODEXBOX_TELEGRAM_MODE_TOKEN` | none | Bot token from @BotFather |
| `CODEXBOX_TELEGRAM_MODE_CONFIG` | `~/.aicodebox/telegram.yml` | Path to the config file |
| `CODEXBOX_TELEGRAM_MODE_OVERRIDES` | `~/.aicodebox/telegram_overrides.json` | Per-chat override store for model, effort and system prompts |

The `/model` and `/effort` pickers list `CODEXBOX_AVAILABLE_MODELS` and `CODEXBOX_AVAILABLE_EFFORTS`. Without `CODEXBOX_AVAILABLE_MODELS`, `/model` answers with a request to set it; unlike API mode, the bot still starts.

Every `CODEXBOX_*` name is an alias for the `AICODEBOX_*` name the base reads. If both are set, `AICODEBOX_*` wins.

## With cron mode

Telegram and cron are the one foreground pair that runs together. Set both flags and the scheduler runs in a thread inside the bot, which lets a job post its result into a chat and lets you reply to it. See [Cron mode](cron.md).
