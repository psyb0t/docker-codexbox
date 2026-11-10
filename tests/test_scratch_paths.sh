#!/usr/bin/env bash
# Checks that no tracked first-party file points at the local planning
# directory, which is ignored and never committed (rule STY8). The ignore
# files and the rule that names it are the only allowed mentions.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO
readonly SCRATCH='.plan-and-delegate'

if hits="$(git -C "$REPO" grep -n -F "$SCRATCH" -- . \
    ':!.gitignore' ':!.dockerignore' ':!.agents/rules/code-style.md' \
    ':!tests/test_scratch_paths.sh')"; then
    printf 'FAIL: tracked files mention %s:\n%s\n' "$SCRATCH" "$hits" >&2
    exit 1
fi

printf 'scratch path test passed\n'
