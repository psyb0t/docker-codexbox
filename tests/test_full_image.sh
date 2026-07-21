#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
# shellcheck source=common.sh
source "$TEST_DIR/common.sh"

readonly IMAGE="${IMAGE:-psyb0t/codexbox:latest-full}"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    log ERROR "image not found: $IMAGE"
    exit 1
fi

docker run --rm --entrypoint /bin/bash "$IMAGE" -lc '
    set -euo pipefail

    [ "${CODEXBOX_IMAGE_VARIANT:-}" = "full" ]
    codex --version
    go version | grep -F "go1.26.1"
    python --version 2>&1 | grep -F "Python 3.12.11"

    tools=(
        go gofmt golangci-lint gopls dlv staticcheck gomodifytags impl gotests gofumpt
        python pip pytest black flake8 mypy pyright
        node npm eslint prettier tsc ts-node yarn pnpm
        gh terraform kubectl helm
        make cmake nano vim htop tmux zip unzip
        ping dig tree fdfind rg batcat eza ag shellcheck shfmt http
        clang-format valgrind gdb strace ltrace
        sqlite3 psql mysql redis-cli
    )

    for tool in "${tools[@]}"; do
        command -v "$tool" >/dev/null || {
            echo "missing full-image tool: $tool" >&2
            exit 1
        }
    done
'

log INFO "full image toolchain passed ($IMAGE)"
