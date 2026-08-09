# Cron Mode

`CODEXBOX_CRON_MODE=1` + `CODEXBOX_CRON_MODE_FILE=/path/to/cron.yaml`. YAML-defined scheduled jobs — 6-field schedules via croniter. Each job fires codex with the given instruction.

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
```

```yaml
# docker-compose.yml
services:
  codexbox:
    image: psyb0t/codexbox:latest
    environment:
      - CODEXBOX_CRON_MODE=1
      - CODEXBOX_CRON_MODE_FILE=/home/aicode/.aicodebox/cron.yaml
    volumes:
      - ~/.aicodebox:/home/aicode/.aicodebox
      - ~/workspaces:/workspace
```

The schedule field is 6-field (seconds first), so `"0 0 9 * * 1-5"` is 09:00:00 on weekdays.

## Run history

Each run gets a history dir at `$HOME/.aicodebox/cron/history/<workspace>/<timestamp>-<job>/` with `meta.json`, `stdout.log`, `stderr.log`, `result.txt`. If telegram is configured, `telegram.json` lands there too and the next run's prompt gets a "prior run" hint so codex can reference its own history without you wiring it up.

That path is fixed — the scheduler builds it from `$HOME` and does not read `CODEXBOX_CRON_MODE_HISTORY_DIR`. To relocate run history, mount a volume at `$HOME/.aicodebox/cron`. The env var exists for a narrower job: it tells the telegram bot which directory to read `telegram_messages.json` from, and only matters when telegram and cron run in the same container.

## Cron mode environment variables

| Var | Default | What it does |
|-----|---------|---------------|
| `CODEXBOX_CRON_MODE` | `0` | Boot the cron scheduler (foreground; in-thread when telegram is also on) |
| `CODEXBOX_CRON_MODE_FILE` | — | Path to the cron yaml |
| `CODEXBOX_CRON_MODE_HISTORY_DIR` | `~/.aicodebox/cron` | Directory the **telegram bot** reads the cron→telegram message inbox (`telegram_messages.json`) from. It does **not** move where the scheduler writes run history — see below |

> Every `CODEXBOX_*` variable is an alias for the `AICODEBOX_*` equivalent read by the base image. If both are set, `AICODEBOX_*` wins.

## Combined with telegram mode

Setting `CODEXBOX_TELEGRAM_MODE=1` alongside cron is supported — cron then runs in-thread inside telegram, which is what makes `telegram_chat_id` on a job deliver its result to a chat. See [telegram.md](telegram.md).

## Combined with MCP mode

Cron is a foreground mode, so [mcp.md](mcp.md) runs as a sidecar next to it — scheduled jobs on their own schedule, the same box reachable as a tool the whole time.
