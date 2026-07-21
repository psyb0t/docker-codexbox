#!/usr/bin/env bash
# codexbox host wrapper — the `codexbox` command installed on your machine.
#
# Interactive host launcher (NOT a pipeline/automation script): it prints
# human-readable status to the terminal via plain `echo` and gates diagnostics
# behind DEBUG via dbg() — the same idiom as the sibling claudebox wrapper.
# `set -euo pipefail` is intentionally omitted: this is a dispatcher built on
# expected-nonzero probes (`docker ps | grep -q`, `docker stop` of a
# maybe-absent container) where a non-match is normal control flow, not an error.
#
# It only does host-side plumbing: resolve the image, mount the workspace + the
# persisted ~/.codex (CODEX_HOME — holds auth.json for BOTH the API-key and the
# ChatGPT-subscription login, plus config.toml + session rollouts) + the docker
# socket, forward auth/env vars, and manage the per-workspace container
# lifecycle. All codex-flag logic (exec vs interactive TUI, the
# --dangerously-bypass-approvals-and-sandbox injection, login/logout
# passthrough) lives INSIDE the image in codexbox-agent — the wrapper forwards
# "$@" untouched and lets the container decide.
#
# install.sh rewrites this line so its minimal/full choice persists.
CODEXBOX_INSTALLED_IMAGE="psyb0t/codexbox:latest"

DEBUG="${CODEXBOX_ENV_DEBUG:-${DEBUG:-}}"
dbg() {
    [ "${DEBUG:-}" = "true" ] && echo "[DEBUG $(date +%H:%M:%S.%3N)] $*" >&2
    return 0
}

CODEX_IMAGE="${CODEXBOX_IMAGE:-}"
if [ -z "$CODEX_IMAGE" ]; then
    case "${CODEXBOX_FULL:-}" in
        "") CODEX_IMAGE="$CODEXBOX_INSTALLED_IMAGE" ;;
        0) CODEX_IMAGE="psyb0t/codexbox:latest" ;;
        1) CODEX_IMAGE="psyb0t/codexbox:latest-full" ;;
        *)
            echo "❌ CODEXBOX_FULL must be 0 or 1" >&2
            exit 1
            ;;
    esac
fi
CODEX_DIR="${CODEXBOX_DATA_DIR:-$HOME/.codex}"
CODEX_SSH="${CODEXBOX_SSH_DIR:-$HOME/.ssh/codexbox}"
CODEX_MAX_MEM="${CODEXBOX_MAX_MEM:-10g}"

# Container path the codex config+auth dir is mounted at — matches CODEX_HOME
# baked into the image's Dockerfile.
readonly CONTAINER_CODEX_HOME="/home/aicode/.codex"

# auth: prefer CODEXBOX_ENV_*, fall back to bare vars. codex reads OPENAI_API_KEY
# (seeded into auth.json on first boot) and OPENAI_BASE_URL for compatible
# endpoints. A ChatGPT-subscription login (codex login) is stored in the mounted
# ~/.codex/auth.json and needs no env var at all.
OPENAI_API_KEY="${CODEXBOX_ENV_OPENAI_API_KEY:-${OPENAI_API_KEY:-}}"
OPENAI_BASE_URL="${CODEXBOX_ENV_OPENAI_BASE_URL:-${OPENAI_BASE_URL:-}}"

mkdir -p "$CODEX_DIR" "$CODEX_SSH"

# Convert PWD to a valid container name (slashes to underscores)
sanitized_pwd=$(echo "$PWD" | sed 's/\//_/g')
container_name="${CODEXBOX_CONTAINER_NAME:-codex-${sanitized_pwd}}"
dbg "container_name=$container_name CODEX_DIR=$CODEX_DIR PWD=$PWD"

DOCKER_ARGS=(
    --network host
    -e CODEXBOX_WORKSPACE="$PWD"
    -e CODEXBOX_CONTAINER_NAME="$container_name"
    -v "$CODEX_SSH:/home/aicode/.ssh"
    -v "$CODEX_DIR:$CONTAINER_CODEX_HOME"
    -v "$PWD:$PWD"
    -v /var/run/docker.sock:/var/run/docker.sock
)

# Forward auth via -e. The key value is never echoed/logged (only its presence
# gates the arg) — per the never-log-secrets rule.
[ -n "$OPENAI_API_KEY" ] && DOCKER_ARGS+=(-e "OPENAI_API_KEY=$OPENAI_API_KEY")
[ -n "$OPENAI_BASE_URL" ] && DOCKER_ARGS+=(-e "OPENAI_BASE_URL=$OPENAI_BASE_URL")
[ "$DEBUG" = "true" ] && DOCKER_ARGS+=(-e "DEBUG=true")

# forward CODEXBOX_ENV_* vars (strip prefix: FOO=bar)
while IFS='=' read -r name value; do
    stripped="${name#CODEXBOX_ENV_}"
    DOCKER_ARGS+=(-e "$stripped=$value")
    dbg "forwarding env: $stripped"
done < <(env | grep -E "^CODEXBOX_ENV_")

# mount extra volumes via CODEXBOX_MOUNT_* (value with a ':' is passed as raw
# docker -v syntax; otherwise the same path is mounted on both sides)
while IFS='=' read -r _name value; do
    case "$value" in
        *:*) DOCKER_ARGS+=(-v "$value") ;;
        *) DOCKER_ARGS+=(-v "$value:$value") ;;
    esac
    dbg "mounting volume: $value"
done < <(env | grep -E "^CODEXBOX_MOUNT_")

# TTY flags: -it only when both stdin and stdout are terminals, so piped /
# captured invocations (`codexbox exec "..." | jq`) don't error with
# "input device is not a TTY".
if [ -t 0 ] && [ -t 1 ]; then
    IT=(-it)
else
    IT=(-i)
fi

# stop — kill the running interactive + cron container for this workspace
if [ "${1:-}" = "stop" ]; then
    stopped=0
    for name in "$container_name" "${container_name}_cron"; do
        if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
            docker stop "$name" >/dev/null 2>&1
            echo "stopped $name"
            stopped=1
        fi
    done
    [ "$stopped" = "0" ] && echo "nothing running"
    exit 0
fi

# clear-session — remove codex's recorded session rollouts (leaves auth.json +
# config.toml intact). codex stores sessions under $CODEX_HOME/sessions and
# archived_sessions (confirmed from the codex source: SESSIONS_SUBDIR).
if [ "${1:-}" = "clear-session" ]; then
    removed=0
    for sub in sessions archived_sessions; do
        if [ -d "$CODEX_DIR/$sub" ]; then
            rm -rf "${CODEX_DIR:?}/$sub"
            removed=1
        fi
    done
    if [ "$removed" = "1" ]; then
        echo "cleared codex sessions in $CODEX_DIR"
    else
        echo "no sessions found in $CODEX_DIR"
    fi
    exit 0
fi

# cron mode — long-running daemon container, named <base>_cron
_mode_cron="${CODEXBOX_MODE_CRON:-}"
_mode_cron_file="${CODEXBOX_MODE_CRON_FILE:-}"
if [ -n "$_mode_cron" ]; then
    cron_name="${container_name}_cron"
    dbg "cron container: $cron_name"

    if docker ps --format '{{.Names}}' | grep -q "^${cron_name}$"; then
        echo "cron already running ($cron_name)"
        echo "  docker logs -f $cron_name"
        exit 0
    fi

    CRON_ARGS=(
        -e "CODEXBOX_CRON_MODE=1"
        -e "CODEXBOX_WORKSPACE=$PWD"
        -e "CODEXBOX_CONTAINER_NAME=$cron_name"
    )
    [ -n "$_mode_cron_file" ] && CRON_ARGS+=(-e "CODEXBOX_CRON_MODE_FILE=$_mode_cron_file")
    [ "$DEBUG" = "true" ] && CRON_ARGS+=(-e "DEBUG=true")

    if docker ps -a --format '{{.Names}}' | grep -q "^${cron_name}$"; then
        echo "restarting cron container ($cron_name)..."
        docker start "$cron_name"
    else
        echo "starting cron container ($cron_name)..."
        docker run -d --name "$cron_name" "${DOCKER_ARGS[@]}" "${CRON_ARGS[@]}" "$CODEX_IMAGE"
    fi
    echo "  docker logs -f $cron_name"
    exit 0
fi

# Passthrough subcommands — throwaway --rm container. login/logout/mcp need a
# TTY for the interactive OAuth device flow; codex writes auth.json to the
# mounted ~/.codex so a `codexbox login --device-auth` persists on the host.
case "${1:-}" in
    -V | --version | -h | --help | doctor | completion | features | \
        login | logout | mcp | mcp-server | update)
        docker run --rm "${IT[@]}" "${DOCKER_ARGS[@]}" "$CODEX_IMAGE" "$@"
        exit $?
        ;;
esac

# One-shot codex exec — throwaway --rm container (sessions persist via the
# ~/.codex mount, so no long-lived container is needed). The image's
# codexbox-agent injects the sandbox-bypass flag.
if [ "${1:-}" = "exec" ] || [ "${1:-}" = "e" ]; then
    prog_name="${container_name}_prog"
    dbg "one-shot exec container: $prog_name"
    docker run --rm "${IT[@]}" "${DOCKER_ARGS[@]}" \
        -e CODEXBOX_CONTAINER_NAME="$prog_name" "$CODEX_IMAGE" "$@"
    exit $?
fi

# Interactive TUI (bare `codexbox`, or any other args) — persistent per-workspace
# container so its in-container state survives across sessions.
if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
    echo "⏳ Container '$container_name' is busy. Waiting for it to finish..."
    for i in 1 2 3; do
        sleep $((5 * i))
        docker ps --format '{{.Names}}' | grep -q "^${container_name}$" || break
        echo "   attempt $i/3..."
    done
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo "❌ Container is still busy after 3 attempts. Try again later." >&2
        exit 1
    fi
fi

if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
    echo "🔄 Starting container '$container_name'..."
    docker update --memory="$CODEX_MAX_MEM" --memory-swap="$CODEX_MAX_MEM" "$container_name" 2>/dev/null || true
    docker start -ai "$container_name"
else
    echo "🔧 Creating container '$container_name'..."
    docker run "${IT[@]}" --name "$container_name" \
        --memory="$CODEX_MAX_MEM" \
        --memory-swap="$CODEX_MAX_MEM" \
        "${DOCKER_ARGS[@]}" "$CODEX_IMAGE" "$@"
fi
