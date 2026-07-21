#!/usr/bin/env bash

log() {
    local level="$1"
    shift
    printf '{"time":"%s","level":"%s","file":"%s","line":%d,"func":"%s","msg":"%s"}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" \
        "$level" \
        "${BASH_SOURCE[1]##*/}" \
        "${BASH_LINENO[0]}" \
        "${FUNCNAME[1]:-main}" \
        "$*" >&2
}

fail() {
    log ERROR "$*"
    exit 1
}

assert_eq() {
    local actual="$1"
    local expected="$2"
    local name="$3"

    if [ "$actual" = "$expected" ]; then
        log INFO "$name passed"
        return 0
    fi

    log ERROR "$name failed: expected '$expected', got '$actual'"
    return 1
}

assert_contains() {
    local actual="$1"
    local expected="$2"
    local name="$3"

    if [[ "$actual" == *"$expected"* ]]; then
        log INFO "$name passed"
        return 0
    fi

    log ERROR "$name failed: expected output to contain '$expected'"
    return 1
}

assert_not_empty() {
    local actual="$1"
    local name="$2"

    if [ -n "$actual" ]; then
        log INFO "$name passed"
        return 0
    fi

    log ERROR "$name failed: expected non-empty output"
    return 1
}

assert_exit_code() {
    local actual="$1"
    local expected="$2"
    local name="$3"
    assert_eq "$actual" "$expected" "$name (exit code)"
}
