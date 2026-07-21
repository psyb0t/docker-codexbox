#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
# shellcheck source=common.sh
source "$TEST_DIR/common.sh"

REPO="$(cd "$TEST_DIR/.." && pwd)"
readonly REPO
readonly WRAPPER="$REPO/wrapper.sh"
readonly INSTALLER="$REPO/install.sh"
readonly MINIMAL_IMAGE="psyb0t/codexbox:latest"
readonly FULL_IMAGE="psyb0t/codexbox:latest-full"
readonly OVERRIDE_IMAGE="example.invalid/codexbox:custom"

TMPROOT="$(mktemp -d)"
cleanup() {
    rm -rf "$TMPROOT"
}
trap cleanup EXIT INT TERM

readonly FAKEBIN="$TMPROOT/bin"
mkdir -p "$FAKEBIN" "$TMPROOT/codex" "$TMPROOT/ssh" "$TMPROOT/install"
cat >"$FAKEBIN/docker" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$TMPROOT/docker.log"
EOF
cat >"$FAKEBIN/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
chmod +x "$FAKEBIN/docker" "$FAKEBIN/sudo"

image_token() {
    grep -oE '[^[:space:]]*codexbox:[^[:space:]]+' <<<"$1" | head -1
}

wrapper_image() {
    local wrapper="$1"
    local full_value="$2"
    local override_image="$3"
    : >"$TMPROOT/docker.log"
    (
        cd "$TMPROOT"
        PATH="$FAKEBIN:$PATH" \
            CODEXBOX_DATA_DIR="$TMPROOT/codex" \
            CODEXBOX_SSH_DIR="$TMPROOT/ssh" \
            CODEXBOX_FULL="$full_value" \
            CODEXBOX_IMAGE="$override_image" \
            bash "$wrapper" exec "hi" >/dev/null 2>&1
    ) || true
    image_token "$(grep -m1 '^run ' "$TMPROOT/docker.log" || true)"
}

installed_wrapper_image() {
    local wrapper="$1"
    : >"$TMPROOT/docker.log"
    (
        cd "$TMPROOT"
        PATH="$FAKEBIN:$PATH" \
            CODEXBOX_DATA_DIR="$TMPROOT/codex" \
            CODEXBOX_SSH_DIR="$TMPROOT/ssh" \
            env -u CODEXBOX_FULL -u CODEXBOX_IMAGE \
            bash "$wrapper" exec "hi" >/dev/null 2>&1
    ) || true
    image_token "$(grep -m1 '^run ' "$TMPROOT/docker.log" || true)"
}

install_variant() {
    local full_value="$1"
    local install_dir="$2"
    local install_home="$3"
    : >"$TMPROOT/docker.log"
    mkdir -p "$install_dir" "$install_home"
    (
        HOME="$install_home" \
            PATH="$FAKEBIN:$PATH" \
            CODEXBOX_INSTALL_DIR="$install_dir" \
            CODEXBOX_FULL="$full_value" \
            bash "$INSTALLER" >/dev/null 2>&1
    ) || fail "installer failed for CODEXBOX_FULL=$full_value"
    image_token "$(grep -m1 '^pull ' "$TMPROOT/docker.log" || true)"
}

assert_image() {
    local name="$1"
    local got="$2"
    local want="$3"
    [ "$got" = "$want" ] || fail "$name resolved '$got', expected '$want'"
    log INFO "$name passed ($got)"
}

assert_image "wrapper/default" "$(wrapper_image "$WRAPPER" "" "")" "$MINIMAL_IMAGE"
assert_image "wrapper/full-0" "$(wrapper_image "$WRAPPER" "0" "")" "$MINIMAL_IMAGE"
assert_image "wrapper/full-1" "$(wrapper_image "$WRAPPER" "1" "")" "$FULL_IMAGE"
assert_image \
    "wrapper/explicit-image" \
    "$(wrapper_image "$WRAPPER" "1" "$OVERRIDE_IMAGE")" \
    "$OVERRIDE_IMAGE"

case_index=0
for full_value in 0 1; do
    case_index=$((case_index + 1))
    install_dir="$TMPROOT/install/$case_index"
    install_home="$TMPROOT/home/$case_index"
    expected="$MINIMAL_IMAGE"
    [ "$full_value" = "1" ] && expected="$FULL_IMAGE"

    pulled="$(install_variant "$full_value" "$install_dir" "$install_home")"
    launched="$(installed_wrapper_image "$install_dir/codexbox")"
    assert_image "installer/full-$full_value pull" "$pulled" "$expected"
    assert_image "installer/full-$full_value baked wrapper" "$launched" "$expected"
done

if CODEXBOX_FULL=2 bash "$INSTALLER" >/dev/null 2>&1; then
    fail "installer accepted invalid CODEXBOX_FULL=2"
fi

if CODEXBOX_FULL=2 CODEXBOX_DATA_DIR="$TMPROOT/codex" \
    CODEXBOX_SSH_DIR="$TMPROOT/ssh" PATH="$FAKEBIN:$PATH" \
    bash "$WRAPPER" exec "hi" >/dev/null 2>&1; then
    fail "wrapper accepted invalid CODEXBOX_FULL=2"
fi

log INFO "all image-selection tests passed"
