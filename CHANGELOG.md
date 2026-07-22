# Changelog

All notable changes per release. Versions follow [semver](https://semver.org)
pre-1.0 conventions: minor bumps may include breaking REST changes (called
out explicitly), patch bumps are docs / build / fixes only.

## v0.3.4 — 2026-07-22

Codexbox now pins the reusable Docker workflow at `v0.8.1`, so a GitHub
Actions cache-service error cannot cancel an otherwise successful image push.

## v0.3.3 — 2026-07-22

The full-image build retries its complete apt package transaction with freshly
downloaded indexes, preventing transient Ubuntu mirror publication races from
breaking the arm64 release build.

## v0.3.2 — 2026-07-21

The README now leads with copy-paste one-line installer commands for both the
minimal and full images, matching Claudebox's installation flow. Raw Docker
commands are documented only for intentional manual use.

## v0.3.1 — 2026-07-21

The release pipeline now publishes both minimal and `-full` multi-architecture
image variants, building the full image after its minimal parent is available.
Reusable GitHub Actions workflows are pinned to an immutable revision.

## v0.3.0 — 2026-07-21

Added `latest-full`, a Codex-native toolchain image layered on the minimal
image. It mirrors Claudebox's full-image capabilities across Go, Python,
JavaScript/TypeScript, database clients, editors, debuggers, network tools,
GitHub CLI, Terraform, kubectl, and Helm. Downloaded standalone toolchains and
CLIs are version-pinned and checksum-verified. The full image now also pins
its parent images by digest and installs Node, Python, and Go toolchains from
frozen, hash-verified dependency inputs; JavaScript lifecycle scripts are
disabled and a fixed seven-day release-age gate is enforced when locks change.

`CODEXBOX_FULL` now accepts exactly `0` (minimal, the default) or `1` (full).
The installer pulls the selected tag and bakes that exact image into the
installed wrapper. Hermetic regression coverage verifies installer/wrapper
agreement, and a full-image smoke test checks every advertised tool.

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
`CODEXBOX_MODE_CRON` daemon.
