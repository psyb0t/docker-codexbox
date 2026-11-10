#!/usr/bin/env bash
# Checks the URL the OpenClaw MCP bridge hands to mcp-remote: /mcp/ on the API
# port by default, and the port root of a standalone MCP server when
# CODEXBOX_MCP_PATH=/ is set. A stub mcp-remote records its argv, so only node
# is needed; `make test-mcp-bridge` runs it in the base image.
set -euo pipefail

for launch_var in "${!AICODEBOX_HOST_@}"; do
    unset "$launch_var"
done
unset CODEXBOX_URL CODEXBOX_MCP_PATH CODEXBOX_MCP_MODE_TOKEN

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO
TMP_ROOT="$(mktemp -d)"
readonly TMP_ROOT
trap 'rm -rf "$TMP_ROOT"' EXIT
readonly PLUGIN="$TMP_ROOT/plugin"
readonly STUB_DIR="$PLUGIN/node_modules/mcp-remote/dist"
mkdir -p "$PLUGIN/bin" "$STUB_DIR"

cp "$REPO/.agents/plugins/codexbox/bin/cli.js" "$PLUGIN/bin/cli.js"
cp "$REPO/.agents/plugins/codexbox/package.json" "$PLUGIN/package.json"
cat >"$STUB_DIR/proxy.js" <<'EOF'
const fs = require("node:fs");
fs.writeFileSync(process.env.BRIDGE_ARGV_FILE, process.argv.slice(2).join("\n"));
EOF
printf '{"type":"commonjs"}\n' >"$PLUGIN/node_modules/mcp-remote/package.json"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

bridge_url() {
    rm -f "$TMP_ROOT/argv"
    BRIDGE_ARGV_FILE="$TMP_ROOT/argv" "$@" node "$PLUGIN/bin/cli.js" >"$TMP_ROOT/stdout"
    [[ ! -s "$TMP_ROOT/stdout" ]] || fail "bridge wrote to stdout"
    head -n 1 "$TMP_ROOT/argv"
}

url="$(bridge_url env CODEXBOX_URL=http://localhost:8080)"
[[ "$url" == http://localhost:8080/mcp/ ]] || fail "default path: $url"
url="$(bridge_url env CODEXBOX_URL=http://localhost:8080/)"
[[ "$url" == http://localhost:8080/mcp/ ]] || fail "trailing slash: $url"
url="$(bridge_url env CODEXBOX_URL=http://localhost:8081 CODEXBOX_MCP_PATH=/)"
[[ "$url" == http://localhost:8081/ ]] || fail "standalone root: $url"
url="$(bridge_url env CODEXBOX_URL=https://proxy.example.invalid/box CODEXBOX_MCP_PATH=mcp)"
[[ "$url" == https://proxy.example.invalid/box/mcp ]] || fail "path without slash: $url"

if bridge_url env CODEXBOX_URL= >/dev/null 2>&1; then
    fail "bridge started without CODEXBOX_URL"
fi

printf 'MCP bridge URL test passed\n'
