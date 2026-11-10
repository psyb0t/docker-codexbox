---
title: "Cron mode"
description: "Schedule Codex jobs with codexbox cron mode: the YAML job file, 6-field schedules, run history, session continuity and Telegram delivery."
nav_order: 3
parent: "Modes"
---

# Cron mode

`CODEXBOX_CRON_MODE=1` with `CODEXBOX_CRON_MODE_FILE=/path/to/cron.yaml` runs jobs from a YAML file on 6-field schedules, parsed by croniter. Each job runs Codex with its instruction.

## Setup

```yaml
# cron.yaml
jobs:
  - name: morning-standup
    schedule: "0 0 9 * * 1-5"
    instruction: |
      Summarize what changed in /workspace since yesterday.
      Be brief. One paragraph max.
    workspace: myproject
    telegram_chat_id: -100123
    model: gpt-5.1-codex
    thinking: low

  - name: silent-check
    schedule: "0 */15 * * * *"
    instruction: Write the current UTC timestamp to ./status.txt.
    telegram_chat_id: 0
```

The schedule has six fields with seconds first, so `"0 0 9 * * 1-5"` is 09:00:00 on weekdays. Set a job's `telegram_chat_id` to `0` to opt it out of a root-level `telegram_chat_id`.

```yaml
# docker-compose.yml
services:
  codexbox:
    image: psyb0t/codexbox:latest
    environment:
      - CODEXBOX_CRON_MODE=1
      - CODEXBOX_CRON_MODE_FILE=/home/aicode/.aicodebox/cron.yaml
      - OPENAI_API_KEY=sk-...
    volumes:
      - ~/.aicodebox:/home/aicode/.aicodebox
      - ~/workspaces:/workspace
```

From your current directory, the [wrapper](../wrapper.md#cron-through-the-wrapper) starts the same thing as a background container:

```bash
CODEXBOX_MODE_CRON=1 \
CODEXBOX_MODE_CRON_FILE="$PWD/cron.yaml" \
codexbox
```

## Sessions

Each job workspace keeps one top-level Codex `exec` session across runs. codexbox records that session's exact ID and resumes it directly, instead of Codex's `resume --last`, which can pick a newer subagent rollout that cannot take a cron turn. Workspaces from older versions take over their newest top-level `exec` rollout automatically. [Codex adapter](../codex-adapter.md#session-continuation) has the details.

## Run history

`CODEXBOX_CRON_MODE_HISTORY_DIR` (default `$HOME/.aicodebox/cron`) is the whole cron state root:

- `<root>/history/<workspace>/<timestamp>-<job>/` for each run, with `meta.json`, `stdout.log`, `stderr.log` and `result.txt`. With Telegram configured, `telegram.json` lands there too, and the next run's prompt gets a hint about the prior run, so Codex can read its own history.
- `<root>/<job>.jsonl`, a summary per job.
- `<root>/telegram_messages.json`, the inbox the bot reads to connect replies to cron messages.

Setting `CODEXBOX_CRON_MODE_HISTORY_DIR` moves all of it, so the scheduler and the bot always agree on one directory. Mount it to keep history across container recreation.

## Cron mode settings

| Variable | Default | What it does |
| --- | --- | --- |
| `CODEXBOX_CRON_MODE` | `0` | Run the scheduler in the foreground, or inside the bot when Telegram is on |
| `CODEXBOX_CRON_MODE_FILE` | none | Path to the job file |
| `CODEXBOX_CRON_MODE_HISTORY_DIR` | `~/.aicodebox/cron` | Cron state root: run history, job summaries and the Telegram inbox |

Every `CODEXBOX_*` name is an alias for the `AICODEBOX_*` name the base reads. If both are set, `AICODEBOX_*` wins.

## With Telegram mode

With `CODEXBOX_TELEGRAM_MODE=1` as well, the scheduler runs inside the bot, which is what makes a job's `telegram_chat_id` deliver its result to a chat. A job with an explicit `telegram_chat_id` posts a "finished (no output)" notice when a successful run has empty result text, and a failed run reports its exit code. See [Telegram mode](telegram.md).

## With MCP mode

Cron is a foreground mode, so [MCP](mcp.md) runs as a separate server next to it. Jobs run on their schedule while the same box answers as a tool.
