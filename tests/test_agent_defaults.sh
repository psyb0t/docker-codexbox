#!/usr/bin/env bash
# Checks that CODEXBOX_MODEL and CODEXBOX_REASONING_EFFORT reach Codex on the
# shell path as -c overrides that the caller's own flags can still replace,
# and that the init script no longer writes them where Codex ignores them.
# A fake codex on PATH records argv, so no image or network is needed.
set -euo pipefail

for launch_var in "${!AICODEBOX_HOST_@}"; do
    unset "$launch_var"
done
unset CODEXBOX_MODEL CODEXBOX_REASONING_EFFORT OPENAI_API_KEY

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO
TMP_ROOT="$(mktemp -d)"
readonly TMP_ROOT
trap 'rm -rf "$TMP_ROOT"' EXIT
readonly FAKE_BIN="$TMP_ROOT/bin"
mkdir -p "$FAKE_BIN"

cat >"$FAKE_BIN/codex" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@"
EOF
chmod +x "$FAKE_BIN/codex"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

agent() {
    PATH="$FAKE_BIN:$PATH" bash "$REPO/codexbox-agent.sh" "$@" | paste -sd ' ' -
}

readonly BYPASS='--dangerously-bypass-approvals-and-sandbox'

out="$(agent exec hi)"
[[ "$out" == "exec $BYPASS hi" ]] || fail "unset variables changed argv: $out"

export CODEXBOX_MODEL=example-model CODEXBOX_REASONING_EFFORT=low
readonly DEFAULTS='-c model="example-model" -c model_reasoning_effort="low"'

out="$(agent exec hi)"
[[ "$out" == "exec $BYPASS $DEFAULTS hi" ]] || fail "exec defaults: $out"
out="$(agent e -m other hi)"
[[ "$out" == "e $BYPASS $DEFAULTS -m other hi" ]] || fail "caller flags must follow defaults: $out"
out="$(agent exec "$BYPASS" hi)"
[[ "$out" == "exec $DEFAULTS $BYPASS hi" ]] || fail "exec with bypass: $out"
out="$(agent)"
[[ "$out" == "resume --last $BYPASS $DEFAULTS" ]] || fail "bare continue: $out"
out="$(agent --no-continue hi)"
[[ "$out" == "$BYPASS $DEFAULTS hi" ]] || fail "bare fresh: $out"
out="$(agent login --device-auth)"
[[ "$out" == "login --device-auth" ]] || fail "management subcommand changed: $out"

CODEXBOX_MODEL='a"b\c' CODEXBOX_REASONING_EFFORT='' out="$(agent exec hi)"
[[ "$out" == "exec $BYPASS -c model=\"a\\\"b\\\\c\" hi" ]] || fail "TOML escaping: $out"

CODEX_HOME="$TMP_ROOT/codex" AICODEBOX_WORKSPACE=/ws PATH="$FAKE_BIN:$PATH" \
    bash "$REPO/codexbox/init.d/10-codex-auth-config.sh"
grep -qF '[projects."/ws"]' "$TMP_ROOT/codex/config.toml" || fail "workspace table missing"
if grep -qE '^(model|model_reasoning_effort) *=' "$TMP_ROOT/codex/config.toml"; then
    fail "init script still writes model settings into config.toml"
fi

printf 'agent model defaults test passed\n'
