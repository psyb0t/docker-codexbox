# Changelog

All notable changes per release. Versions follow [semver](https://semver.org)
pre-1.0 conventions: minor bumps may include breaking REST changes (called
out explicitly), patch bumps are docs / build / fixes only.

## v0.5.3 — 2026-08-01

Infrastructure only. Nothing in the images or the wrapper changed — every
commit in this release touches `.github/workflows/`.

### Changed

- The pipeline was split: building and publishing stay in `pipeline.yml`, and
  everything that leaves the host now lives beside it in
  `mirror-and-archive.yml`.
- The repository is mirrored to Codeberg as well as GitLab.
- It is archived to the Wayback Machine, Software Heritage, and archive.org.
- Pull requests are switched off on both mirrors. They are force-pushed from
  GitHub, so anything merged on a mirror would be destroyed by the next sync.
  Issues and forking stay enabled.

### Added

- Issues opened on either mirror are copied back to GitHub every six hours, and
  the GitHub copy is closed when the original closes.

## v0.5.2 — 2026-07-31

### Fixed

- `collaborators-only.yml` referenced the shared reusable workflow by commit SHA
  while the rest of the pipeline already tracked `@master`, so that one caller
  would have kept running a months-old revision after every other job had moved
  on. All first-party references now track `@master`; third-party actions still
  pin by full commit SHA.

## v0.5.1 — 2026-07-29

Fixes host-wrapper command routing and adds a wrapper-only local install path.

- Codex management commands, including `plugin`, now run in throwaway containers instead of the per-workspace interactive container, so they cannot leave it busy and block later commands.
- Added `make install-wrapper` to replace the installed wrapper against an existing local image without rebuilding or pulling it.

## v0.5.0 — 2026-07-29

Adds local source installation and fixes Codex CLI command routing.

- `codexbox` now forwards every top-level command supported by its pinned Codex CLI, including plugin marketplace management, session lifecycle operations, cloud access, server controls, and the `apply` alias. These commands no longer get mistaken for interactive prompts and routed through `resume --last`.
- Local checkouts can now run `make install` or `make install-full` to build the selected image and install the wrapper without pulling a published codexbox image. `make install-wrapper` updates only the local wrapper against an existing selected image. `CODEXBOX_SRC_LOCAL=true` is also available for direct local `install.sh` use and fails if that image has not been built.

## v0.4.9 — 2026-07-27

Fixes the `-full` image build. Build only, no runtime behavior change.

- `Dockerfile.full` now removes the NodeSource apt source before the mirror-rotation block runs. That block rewrites only `ubuntu.sources`, but `apt-get update` reads every configured source — and the base image installs Node from NodeSource and leaves that source configured. So all three mirror attempts failed on `deb.nodesource.com`, which began returning `403 Forbidden` to CI runner address ranges, over a repository this image never installs from. No `-full` image published for v0.4.7 or v0.4.8 as a result.
- Node is already installed in the base image and is unaffected — only the now-purposeless package source is removed, which also reduces what a later `apt-get install` trusts.

## v0.4.8 — 2026-07-27

README Codex install command fix. Documentation only, no behavior change.

- The Codex subsection of `## Agent integrations` told you to add the marketplace but never told you how to actually install the plugin. Added the missing install line, `codex plugin add codexbox@psyb0t`, right after the marketplace-add command.
- Corrected the invocation prose: installed via the marketplace, the skill is invoked as `$codexbox:codexbox`; picked up automatically (no install) from this repo's own `.agents/skills/`, it's invoked as plain `$codexbox`.

## v0.4.7 — 2026-07-27

Claude Code and Codex plugin manifests, and a README `Agent integrations` section. No behavior change.

- Added `.agents/.claude-plugin/plugin.json` (`userConfig` for the codexbox URL and the two independent bearer tokens) and `.agents/.codex-plugin/plugin.json` so the existing `.agents/skills/codexbox` skill installs natively via `claude plugin install codexbox@psyb0t` and `codex plugin marketplace add psyb0t/agents`.
- Added a README `## Agent integrations` section (with Table of Contents entry) documenting the Claude Code, Codex, and OpenClaw install commands, including the existing `@psyb0t/codexbox` MCP-bridge plugin.

## v0.4.6 — 2026-07-27

README badge. Documentation only, no behavior change.

- Added a GitHub Actions CI status badge to the README.

## v0.4.5 — 2026-07-27

README badges. Documentation / CI only, no behavior change.

- Added self-hosted version and license badges plus a Docker Hub pulls badge; wired a badges job into pipeline.yml.

## v0.4.4 — 2026-07-26

Listed on the official MCP Registry — no behavior change.

- Added `server.json` — published to the official Model Context Protocol Registry (`registry.modelcontextprotocol.io`) as `io.github.psyb0t/codexbox`, pointing at the `psyb0t/codexbox` Docker image. Ownership is proven by an `io.modelcontextprotocol.server.name` LABEL on the image; publishing runs on tag pushes via GitHub OIDC (secretless). Also added a `glama.json` maintainer claim.

## v0.4.3 — 2026-07-26

Third-party license notices. Documentation only, no behavior change.

- Added `THIRD_PARTY.md` + `LICENSES/` documenting the image-bundled OpenAI Codex CLI (Apache-2.0) and, in the full image, BUSL-1.1 Terraform; corrected the README license note. The project's own code stays WTFPL.

## v0.4.2 — 2026-07-26

Skill docs de-duplicated. Documentation only, no behavior change.

- Merged the duplicated API/MCP no-auth notes in `.agents/skills/codexbox/` into one, consolidated the file-deletion note, and simplified the install docs to the download-inspect-run flow (dropped the redundant piped one-liner variants).

## v0.4.1 — 2026-07-26

Skill docs hardened with explicit destructive-operation guardrails and auth warnings.

- **`SKILL.md` and `references/setup.md`** now carry a `Security & safety` section plus inline warnings at every relevant call site: the API and MCP surfaces are called out as unauthenticated when `CODEXBOX_API_MODE_TOKEN` / `CODEXBOX_MCP_MODE_TOKEN` are left empty, `DELETE /files/{path}` / `delete_file` is marked destructive-and-irreversible with agent-confirmation guidance, and the one-line installer now documents a download-inspect-run path alongside the existing piped `curl | bash` form.
- No behavior change — documentation only.

## v0.4.0 — 2026-07-25

ClawHub skill + plugin, and README endpoint corrections.

- **New `codexbox` agent skill** (`.agents/skills/codexbox/`) documenting every mode the box exposes — interactive shell, one-shot exec, the REST API, the OpenAI-compatible `/openai/v1/chat/completions` endpoint, the streamable-HTTP MCP server, the Telegram bot, and the cron scheduler.
- **New `@psyb0t/codexbox` code plugin** (`.agents/plugins/codexbox/`) — a stdio↔HTTP MCP bridge (`mcp-remote`) so an OpenClaw/MCP agent can drive a running box's `/mcp` endpoint. MIT-licensed.
- **CI publishes both to ClawHub** on tag pushes via the reusable `clawhub-publish.yml` (validate → publish, skills + plugins).
- **README corrected** to match the actual REST surface: `POST /run` returns `{runId, workspace, exitCode, text, …}` and takes `"async": true` in the body (there is no `/run/async`); async polling is `GET /run/result?runId=<id>`; cancel is `DELETE /run/{run_id}`; codex system-prompt injection is `-c instructions=…`.

## v0.3.5 — 2026-07-22

Full-image apt installation now enforces bounded network timeouts and retries
amd64 package downloads through verified Ubuntu mirrors when the primary
archive is slow or unavailable.

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
