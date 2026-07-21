#!/bin/bash
# Smoke tests: build verification + "say HELLO" round-trip via codex.
# Every invocation runs inside a fresh `docker run` — there is no host-side
# execution.

ALL_TESTS+=(
    test_build
    test_smoke_codex
)

# Image build is exercised by setup() in common.sh; this test just verifies
# the image exists and `codex --version` works through the entrypoint
# passthrough.
test_build() {
    local rc=0

    if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
        log "  FAIL: image $IMAGE not found"
        return 1
    fi
    log "  OK: image $IMAGE present"

    # Entrypoint passthrough: `docker run codexbox:local --version` should
    # invoke `codex --version` and print codex's version string with rc=0.
    local out
    out=$(docker run --rm "$IMAGE" --version 2>&1)
    local codex_rc=$?
    if [ "$codex_rc" != "0" ]; then
        log "  FAIL: codex --version via entrypoint exited $codex_rc"
        log "  output: ${out:0:500}"
        return 1
    fi
    assert_not_empty "$out" "codex --version produced output" || rc=1

    return $rc
}

# HELLO round-trip through codex.
test_smoke_codex() {
    local prompt="Reply with exactly one word: HELLO. Nothing else."
    local out
    out=$(run_codex "$prompt" 2>&1) || {
        log "  FAIL: codex exited non-zero"
        log "  output: ${out:0:1000}"
        return 1
    }
    assert_contains "$out" "HELLO" "codex produced HELLO"
}
