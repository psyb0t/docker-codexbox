#!/bin/bash
# First-run auth/config seeding for the OpenAI Codex CLI.
#
# TWO auth modes, both must keep working:
#   1. API key (OPENAI_API_KEY env) — seeded here via
#      `codex login --with-api-key` (env-var alone doesn't send a bearer;
#      the CLI must write $CODEX_HOME/auth.json itself).
#   2. ChatGPT subscription (OAuth via `codex login` / `codex login
#      --device-auth`, run manually by the user against a persisted
#      $CODEX_HOME). An existing OAuth auth.json ALWAYS wins — this script
#      never overwrites it, even when OPENAI_API_KEY is also set.
#
# Idempotent — safe to re-run on every container start.
# Invoked from the base entrypoint via `sudo -E -u aicode -H`, so it always
# runs as the aicode user with HOME=/home/aicode.
set -euo pipefail
trap 'echo "[10-codex-auth-config] ${BASH_SOURCE[0]}:${LINENO} — command failed (exit $?)" >&2' ERR

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
WORKSPACE_DIR="${AICODEBOX_WORKSPACE:-${AICODE_WORKSPACE:-/workspace}}"
AUTH_JSON="$CODEX_HOME/auth.json"
CONFIG_TOML="$CODEX_HOME/config.toml"

mkdir -p "$CODEX_HOME"

# ── (b) API-key seeding — subscription-safe ─────────────────────────────────
# auth_mode read from any existing auth.json. A missing/empty/malformed file
# is treated the same as "absent" (never blocks apikey seeding on a corrupt
# file; never crashes on it either).
existing_auth_mode=""
if [ -s "$AUTH_JSON" ] && command -v jq >/dev/null 2>&1; then
    existing_auth_mode="$(jq -r '.auth_mode // empty' "$AUTH_JSON" 2>/dev/null || true)"
fi

if [ -n "${OPENAI_API_KEY:-}" ]; then
    if [ -z "$existing_auth_mode" ] || [ "$existing_auth_mode" = "apikey" ]; then
        if ! command -v codex >/dev/null 2>&1; then
            echo "[10-codex-auth-config] codex CLI missing; skipping API-key seed" >&2
        elif ! command -v jq >/dev/null 2>&1; then
            echo "[10-codex-auth-config] jq missing; skipping API-key seed" >&2
        else
            printf '%s' "$OPENAI_API_KEY" | codex login --with-api-key
            [ -f "$AUTH_JSON" ] && chmod 600 "$AUTH_JSON"
        fi
    else
        echo "[10-codex-auth-config] existing auth_mode=$existing_auth_mode (subscription) — not overwriting with API key" >&2
    fi
fi

# ── (c) config.toml — trust the workspace + optional model/effort defaults ──
# codex writes TOML (not JSON), so seed it with a simple idempotent
# append: only touch the file when the workspace trust entry is missing.
if [ ! -f "$CONFIG_TOML" ] || ! grep -qF "[projects.\"$WORKSPACE_DIR\"]" "$CONFIG_TOML"; then
    {
        printf '\n[projects."%s"]\n' "$WORKSPACE_DIR"
        printf 'trust_level = "trusted"\n'
        if [ -n "${CODEXBOX_MODEL:-}" ]; then
            printf 'model = "%s"\n' "$CODEXBOX_MODEL"
        fi
        if [ -n "${CODEXBOX_REASONING_EFFORT:-}" ]; then
            printf 'model_reasoning_effort = "%s"\n' "$CODEXBOX_REASONING_EFFORT"
        fi
    } >> "$CONFIG_TOML"
    chmod 600 "$CONFIG_TOML"
fi
