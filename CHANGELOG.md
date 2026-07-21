# Changelog

All notable changes per release. Versions follow [semver](https://semver.org)
pre-1.0 conventions: minor bumps may include breaking REST changes (called
out explicitly), patch bumps are docs / build / fixes only.

## v0.2.0 — 2026-07-21

The interactive TUI (`codexbox` with no subcommand) now defaults to
continuing the most recent session for the current directory instead of
always starting fresh — the same default as docker-claudebox. codex's own
`resume --last` scopes its session lookup to the current directory and
falls back to a brand-new session automatically when nothing matches, so
this is safe even on a workspace with no prior history. Pass
`--no-continue` to opt out and force a new session, matching
docker-claudebox's flag of the same name. Other invocations (`codexbox
exec ...`, `codexbox login ...`, etc.) are unaffected.

## v0.1.0 — 2026-07-21

Initial release. OpenAI Codex CLI on the aicodebox base — thin child
mirroring docker-pibox / docker-claude-code. CodexAdapter (`codex exec
--json`, `--dangerously-bypass-approvals-and-sandbox`, native
`--output-schema`, `resume` subcommand, `model_reasoning_effort`). Dual
auth: `OPENAI_API_KEY` and ChatGPT subscription via `codex login`
(persisted through `CODEX_HOME`). Pinned `@openai/codex@0.144.6` on
`psyb0t/aicodebox:v0.14.0`.

The adapter honors the canonical run knobs the way codex exposes them:
`systemPrompt` replaces the built-in prompt (`-c instructions`),
`appendSystemPrompt` appends a developer message (`-c
developer_instructions`), `noTools` drops the shell + web-search tools and
runs the sandbox read-only, and a call with neither `resume` nor
`noContinue` continues the workspace's most recent session (`resume
--last`). `toolsAllowlist` is unsupported (codex has no name-based
built-in tool allowlist) and is ignored with a warning. Model slugs are
auth-dependent: ChatGPT subscriptions use the GPT-5.6 family
(`gpt-5.6-luna` / `-terra` / `-sol`); API keys use the `*-codex` catalog.

Host tooling: `install.sh` + `wrapper.sh` add a `codexbox` command on the
host (mirroring docker-claudebox) — mounts the current dir as the
workspace, persists `~/.codex` (auth + config + sessions), forwards
`OPENAI_API_KEY` / `OPENAI_BASE_URL` / `CODEXBOX_ENV_*` / `CODEXBOX_MOUNT_*`,
and manages a per-directory container: `codexbox` (interactive TUI),
`codexbox exec "…"` (one-shot), `codexbox login --device-auth`
(subscription OAuth), `codexbox stop`, `codexbox clear-session`, plus a
`CODEXBOX_MODE_CRON` daemon. Single image (no minimal/full split), so no
install-time variant to pick.
