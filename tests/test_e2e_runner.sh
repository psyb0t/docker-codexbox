#!/usr/bin/env bash
# Checks that test.sh loads only end-to-end test files and leaves the
# standalone scripts in tests/ alone. Runs test.sh from a copy with a fake
# docker and a placeholder .env.test, so it needs no daemon or credentials.
set -euo pipefail

for launch_var in "${!AICODEBOX_HOST_@}"; do
    unset "$launch_var"
done

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO
TMP_ROOT="$(mktemp -d)"
readonly TMP_ROOT
trap 'rm -rf "$TMP_ROOT"' EXIT
readonly FAKE_BIN="$TMP_ROOT/bin"
readonly COPY="$TMP_ROOT/repo"
mkdir -p "$FAKE_BIN" "$COPY"

cp "$REPO/test.sh" "$COPY/test.sh"
cp -R "$REPO/tests" "$COPY/tests"
# Drop this file from the copy so an unfixed runner cannot start itself again.
rm -rf "$COPY/tests/.logs" "$COPY/tests/$(basename "${BASH_SOURCE[0]}")"
printf 'OPENAI_API_KEY=placeholder\nCODEXBOX_MODEL=\n' >"$COPY/.env.test"

cat >"$FAKE_BIN/docker" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$TMP_ROOT/docker.log"
[[ "\$*" == *--version* ]] && printf 'codex-cli fake\n'
exit 0
EOF
chmod +x "$FAKE_BIN/docker"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

: >"$TMP_ROOT/docker.log"
rc=0
out="$(PATH="$FAKE_BIN:$PATH" SKIP_BASE_PULL=1 SKIP_BUILD=1 KEEP_IMAGE=1 \
    TEST_LOG_DIR="$TMP_ROOT/logs" TEST_LOG_FILE="$TMP_ROOT/identity.log" \
    timeout 60 bash "$COPY/test.sh" test_build 2>&1)" || rc=$?

[[ "$rc" == 0 ]] || fail "test.sh exited $rc: ${out:0:500}"
[[ "$out" == *"passed: 1"* ]] || fail "test_build did not run: ${out:0:500}"
if grep -q 'codexbox-identity' "$TMP_ROOT/docker.log"; then
    fail "test.sh ran the standalone entrypoint identity test"
fi
[[ ! -e "$TMP_ROOT/identity.log" ]] || fail "test.sh sourced a test that redirects its output"

# .env.test.example must only name test files that exist.
while IFS= read -r named; do
    [[ -f "$REPO/tests/$named" ]] || fail ".env.test.example names missing tests/$named"
done < <(grep -oE 'test_[a-z0-9_]+\.sh' "$REPO/.env.test.example" || true)

printf 'e2e runner loading test passed\n'
