#!/bin/bash
# codexbox agent launcher — passthrough wrapper pointed at by
# AICODEBOX_AGENT_BINARY.
#
# aicodebox's passthrough runs `exec $AICODEBOX_AGENT_BINARY "$@"` for BOTH
# interactive (`codexbox`) and one-shot (`codexbox exec ...`) invocations.
# Pointing AICODEBOX_AGENT_BINARY at this script lets codexbox make the
# sandboxed-container defaults (no approval prompts) apply to the
# interactive TUI too, and lets auth/maintenance subcommands (login, logout,
# mcp, doctor, update, ...) run verbatim so `docker run -it ... codexbox
# login --device-auth` can drive the ChatGPT subscription OAuth flow.
#
# Server modes (API/telegram/cron/MCP) build argv via the adapter
# (codexbox.adapter:CodexAdapter, hardcoded binary "codex") and spawn codex
# directly — they never reach this script and are unaffected by it.
set -euo pipefail

readonly CODEX_BIN="codex"
readonly BYPASS='--dangerously-bypass-approvals-and-sandbox'
readonly NO_CONTINUE_FLAG='--no-continue'

dbg() {
    [ "${DEBUG:-}" = "true" ] && printf '[codexbox-agent] %s\n' "$*" >&2
    return 0
}

# CODEXBOX_MODEL and CODEXBOX_REASONING_EFFORT become -c overrides placed
# before the caller's arguments, so a later -m or -c from the caller wins.
# Codex ignores these keys inside a [projects.*] table, and writing them at
# the top level of config.toml would change the mounted host config for every
# workspace. Values are quoted as TOML strings.
toml_string() {
    local value="${1//\\/\\\\}"
    printf '"%s"' "${value//\"/\\\"}"
}
defaults=()
if [ -n "${CODEXBOX_MODEL:-}" ]; then
    defaults+=(-c "model=$(toml_string "$CODEXBOX_MODEL")")
fi
if [ -n "${CODEXBOX_REASONING_EFFORT:-}" ]; then
    defaults+=(-c "model_reasoning_effort=$(toml_string "$CODEXBOX_REASONING_EFFORT")")
fi

# Subcommands (and version/help flags) that must run verbatim — no bypass
# flag injected, no interactive-TUI treatment. Critical for the
# login/logout/login-status subscription-OAuth flow.
case "${1:-}" in
    login | logout | mcp | mcp-server | app-server | remote-control | completion | update | \
        doctor | sandbox | debug | plugin | review | apply | a | resume | archive | delete | \
        unarchive | fork | cloud | exec-server | features | help | -V | --version | -h | --help)
        dbg "passthrough subcommand: ${1}"
        exec "$CODEX_BIN" "$@"
        ;;
    exec | e)
        # Inject the bypass flag right after the subcommand, unless already present.
        sub="$1"
        shift
        already_bypassed=0
        for arg in "$@"; do
            [ "$arg" = "$BYPASS" ] && already_bypassed=1
        done
        if [ "$already_bypassed" -eq 1 ]; then
            dbg "passthrough subcommand: ${sub} (bypass already present)"
            exec "$CODEX_BIN" "$sub" ${defaults[@]+"${defaults[@]}"} "$@"
        fi
        dbg "passthrough subcommand: ${sub} (injecting bypass)"
        exec "$CODEX_BIN" "$sub" "$BYPASS" ${defaults[@]+"${defaults[@]}"} "$@"
        ;;
esac

# Bare interactive TUI / prompt — no recognized subcommand. Defaults to
# continuing the workspace's most recent session (matches claudebox's
# --continue default). `codex resume --last` already cwd-scopes its session
# lookup and falls back to a fresh session internally when nothing matches
# (SessionSelection::StartFresh in codex's own source) — no shell-side
# `|| fresh-session` fallback needed here, unlike claude. --no-continue opts
# out and forces a fresh session; it's a codexbox-only flag, stripped before
# exec since codex itself doesn't recognize it.
want_continue=1
args=()
for arg in "$@"; do
    if [ "$arg" = "$NO_CONTINUE_FLAG" ]; then
        want_continue=0
        continue
    fi
    args+=("$arg")
done

if [ "$want_continue" -eq 1 ]; then
    dbg "launching interactive TUI, continuing last session for this workspace"
    exec "$CODEX_BIN" resume --last "$BYPASS" ${defaults[@]+"${defaults[@]}"} ${args[@]+"${args[@]}"}
fi

dbg "launching interactive TUI, $NO_CONTINUE_FLAG requested — fresh session"
exec "$CODEX_BIN" "$BYPASS" ${defaults[@]+"${defaults[@]}"} ${args[@]+"${args[@]}"}
