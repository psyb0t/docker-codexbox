#!/usr/bin/env bash
# Authenticated E2E bootstrap. Source tests/common.sh first.

IMAGE="codexbox:local"
# Use the published aicodebox base — we no longer develop the two repos
# in parallel, so the suite tests codexbox on top of whatever the released
# base ships. Override with CODEXBOX_BASE_IMAGE if you need to test against
# a local fork of the base.
BASE_IMAGE="${CODEXBOX_BASE_IMAGE:-psyb0t/aicodebox:v0.14.0}"
CONTAINER_PREFIX="codexbox-test"
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXTRA_CONTAINERS=()
ALL_TESTS=()

# load .env.test from repo root
ENV_FILE="$WORKDIR/.env.test"
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ $ENV_FILE not found — copy .env.test.example and fill it in" >&2
    exit 1
fi
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

# Auth: an OpenAI API key OR a ChatGPT-subscription login persisted in a
# mounted ~/.codex (auth.json written by `codex login`). One is required.
CODEX_DATA_DIR="${CODEXBOX_DATA_DIR:-$HOME/.codex}"
if [ -z "${OPENAI_API_KEY:-}" ] && [ ! -f "$CODEX_DATA_DIR/auth.json" ]; then
    echo "❌ no auth: set OPENAI_API_KEY in .env.test, or run 'codex login' so" >&2
    echo "   $CODEX_DATA_DIR/auth.json exists (subscription)" >&2
    exit 1
fi

# Model — server-driven, so empty means the codex account default (the
# flagship: slow + pricey). .env.test.example steers you to a small one
# (gpt-5.6-luna on a subscription). Only pass -m when it's actually set.
TEST_MODEL="${CODEXBOX_MODEL:-}"

# common docker run args — every test uses these
DOCKER_RUN_BASE=(
    --rm
    --network host
    -e "AICODEBOX_WORKSPACE=/workspace"
)

# auth: prefer the API key; otherwise mount the subscription codex home so the
# persisted login is used.
if [ -n "${OPENAI_API_KEY:-}" ]; then
    DOCKER_RUN_BASE+=(-e "OPENAI_API_KEY=$OPENAI_API_KEY")
else
    DOCKER_RUN_BASE+=(-v "$CODEX_DATA_DIR:/home/aicode/.codex")
fi

# optional OpenAI-compatible endpoint override
if [ -n "${OPENAI_BASE_URL:-}" ]; then
    DOCKER_RUN_BASE+=(-e "OPENAI_BASE_URL=$OPENAI_BASE_URL")
fi

CURRENT_LOG_FILE=""

_begin_test_log() {
    local name="$1"
    CURRENT_LOG_FILE="${TEST_LOG_DIR:-/tmp}/${name}.log"
    : > "$CURRENT_LOG_FILE"
    export CURRENT_LOG_FILE
}

setup() {
    # Base image: pulled fresh by default (so the suite always tests against
    # the current released base). Skip with SKIP_BASE_PULL=1 when you've
    # already got it locally and just want to iterate on codexbox changes fast.
    if [ "${SKIP_BASE_PULL:-0}" != "1" ]; then
        echo "pulling base image ($BASE_IMAGE)..."
        if ! docker pull "$BASE_IMAGE" >"$TEST_LOG_DIR/pull.log" 2>&1; then
            echo "❌ base image pull failed; see $TEST_LOG_DIR/pull.log" >&2
            tail -30 "$TEST_LOG_DIR/pull.log" >&2
            exit 1
        fi
        echo "✅ base image present"
    else
        if ! docker image inspect "$BASE_IMAGE" >/dev/null 2>&1; then
            echo "❌ SKIP_BASE_PULL=1 but $BASE_IMAGE not found locally" >&2
            exit 1
        fi
        echo "✅ SKIP_BASE_PULL=1 — using existing $BASE_IMAGE"
    fi

    # codexbox image: SKIP_BUILD=1 reuses an existing $IMAGE tag, otherwise
    # always rebuild so test runs reflect current source.
    if [ "${SKIP_BUILD:-0}" = "1" ]; then
        if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
            echo "❌ SKIP_BUILD=1 but $IMAGE not found" >&2
            exit 1
        fi
        echo "✅ SKIP_BUILD=1 — using existing $IMAGE"
        return 0
    fi

    echo "building codexbox image ($IMAGE) on top of $BASE_IMAGE..."
    if ! docker build --build-arg "BASE_IMAGE=$BASE_IMAGE" \
            -t "$IMAGE" "$WORKDIR" \
            >"$TEST_LOG_DIR/build.log" 2>&1; then
        echo "❌ codexbox image build failed; see $TEST_LOG_DIR/build.log" >&2
        tail -50 "$TEST_LOG_DIR/build.log" >&2
        exit 1
    fi
    echo "✅ codexbox image built"
}

_sweep_test_containers() {
    local names
    names=$(docker ps -a --filter "name=^${CONTAINER_PREFIX}-" --format '{{.Names}}' 2>/dev/null)
    if [ -n "$names" ]; then
        echo "$names" | xargs -r docker rm -f >/dev/null 2>&1 || true
    fi
}

cleanup() {
    _sweep_test_containers
    # Do NOT remove the base image — would force a slow rebuild next run.
    if [ "${KEEP_IMAGE:-0}" != "1" ]; then
        docker rmi -f "$IMAGE" >/dev/null 2>&1 || true
    fi
}

test_setup() { :; }
test_teardown() {
    _sweep_test_containers
    EXTRA_CONTAINERS=()
}

usage() {
    echo "usage: $0 [test_name ...]"
    echo ""
    echo "available tests:"
    for t in "${ALL_TESTS[@]}"; do
        echo "  $t"
    done
}

# ── helper: run codex inside the test image and capture stdout ────────────────
# args: <prompt>
# The image entrypoint passes argv straight through to codexbox-agent, so
# `exec <prompt>` triggers a one-shot `codex exec` run (the agent injects the
# bypass-approvals flag). We pass -m "$TEST_MODEL" only when it's non-empty —
# leaving it unset lets codex fall back to the account default model.
run_codex() {
    local prompt="$1"
    local cname="${CONTAINER_PREFIX}-codex-$$"
    EXTRA_CONTAINERS+=("$cname")

    local args=(exec)
    if [ -n "$TEST_MODEL" ]; then
        args+=(-m "$TEST_MODEL")
    fi
    args+=("$prompt")

    docker run --name "$cname" "${DOCKER_RUN_BASE[@]}" \
        -e "AICODEBOX_CONTAINER_NAME=$cname" \
        "$IMAGE" "${args[@]}"
    RC=$?
    docker rm -f "$cname" >/dev/null 2>&1 || true
    return $RC
}
