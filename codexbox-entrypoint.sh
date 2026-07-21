#!/bin/bash
# codexbox entrypoint — thin wrapper around the aicodebox base entrypoint.
#
# Translates CODEXBOX_* env vars to their AICODEBOX_* equivalents so the
# image presents a codexbox-branded surface to users. AICODEBOX_* still works
# (and wins if both are set) for power users and backwards compatibility.
set -euo pipefail

# var-name pairs: CODEXBOX_X → AICODEBOX_X. If AICODEBOX_X is unset/empty and
# CODEXBOX_X is set, copy the value across. Internal vars (ADAPTER,
# AGENT_BINARY) are NOT exposed — the codexbox Dockerfile pins those.
_CODEXBOX_ALIASES=(
    API_MODE
    API_MODE_PORT
    API_MODE_TOKEN
    TELEGRAM_MODE
    TELEGRAM_MODE_TOKEN
    TELEGRAM_MODE_CONFIG
    TELEGRAM_MODE_OVERRIDES
    CRON_MODE
    CRON_MODE_FILE
    CRON_MODE_HISTORY_DIR
    MCP_MODE
    MCP_MODE_PORT
    MCP_MODE_TOKEN
    WORKSPACE
    AVAILABLE_MODELS
    AVAILABLE_EFFORTS
    CONTAINER_NAME
)

for _suffix in "${_CODEXBOX_ALIASES[@]}"; do
    _codexbox_var="CODEXBOX_${_suffix}"
    _aicode_var="AICODEBOX_${_suffix}"
    _codexbox_val="$(printenv "$_codexbox_var" 2>/dev/null || true)"
    _aicode_val="$(printenv "$_aicode_var" 2>/dev/null || true)"
    if [ -n "$_codexbox_val" ] && [ -z "$_aicode_val" ]; then
        export "$_aicode_var=$_codexbox_val"
    fi
done

unset _CODEXBOX_ALIASES _suffix _codexbox_var _aicode_var _codexbox_val _aicode_val

exec /usr/local/bin/aicodebox-entrypoint "$@"
