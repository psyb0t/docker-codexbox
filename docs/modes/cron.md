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

  - name: silent-check
    schedule: "0 */15 * * * *"
    instruction: Write the current UTC timestamp to ./status.txt.
    telegram_chat_id: 0
```

Set a job's `telegram_chat_id` to `0` to opt that job out of an inherited root-level `telegram_chat_id`.

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

Each job workspace keeps one top-level Codex `exec` session across ticks.
Codexbox records that root's exact ID and resumes it directly instead of using
Codex's unfiltered `resume --last`, which can select a newer subagent rollout
that cannot accept a cron turn. Existing job workspaces migrate their newest
top-level `exec` rollout automatically; no cron configuration change is needed.

## Run history

`CODEXBOX_CRON_MODE_HISTORY_DIR` (default `$HOME/.aicodebox/cron`) is the whole cron state root. Each run gets a history dir at `<root>/history/<workspace>/<timestamp>-<job>/` with `meta.json`, `stdout.log`, `stderr.log`, `result.txt`. If telegram is configured, `telegram.json` lands there too and the next run's prompt gets a "prior run" hint so codex can reference its own history without you wiring it up. A per-job summary jsonl also lands at `<root>/<job>.jsonl`, and the telegram bot reads its cron→telegram message inbox (`telegram_messages.json`) from the same root.

Setting `CODEXBOX_CRON_MODE_HISTORY_DIR` relocates all of it, so the scheduler and the telegram reply bridge agree on one directory. Mount that directory as a volume to persist history across container recreation.

## Cron mode environment variables

| Var | Default | What it does |
|-----|---------|---------------|
| `CODEXBOX_CRON_MODE` | `0` | Boot the cron scheduler (foreground; in-thread when telegram is also on) |
| `CODEXBOX_CRON_MODE_FILE` | — | Path to the cron yaml |
| `CODEXBOX_CRON_MODE_HISTORY_DIR` | `~/.aicodebox/cron` | Cron state root, holding run history, job summary jsonl files, and the telegram message inbox |

> Every `CODEXBOX_*` variable is an alias for the `AICODEBOX_*` equivalent read by the base image. If both are set, `AICODEBOX_*` wins.

## Combined with telegram mode

Setting `CODEXBOX_TELEGRAM_MODE=1` alongside cron is supported — cron then runs in-thread inside telegram, which is what makes `telegram_chat_id` on a job deliver its result to a chat. A job with an explicit `telegram_chat_id` still notifies on a successful run with empty result text (it posts a "finished (no output)" notice); a run that fails reports the exit code instead. See [telegram.md](telegram.md).

## Combined with MCP mode

Cron is a foreground mode, so [mcp.md](mcp.md) runs as a sidecar next to it — scheduled jobs on their own schedule, the same box reachable as a tool the whole time.
