#!/usr/bin/env bash
# codexbox installer — pulls the image and installs the `codexbox` wrapper.
#
# Linear install script (not a dispatcher), so strict mode is on: any step
# failing should abort rather than limp forward. User-facing progress goes to
# stdout via plain echo (this is an interactive installer, not a pipeline).
set -euo pipefail

readonly WRAPPER_URL="https://raw.githubusercontent.com/psyb0t/docker-codexbox/master/wrapper.sh"
readonly IMAGE="psyb0t/codexbox:latest"

BIN_NAME="${1:-${CODEXBOX_BIN_NAME:-codexbox}}"
INSTALL_DIR="${CODEXBOX_INSTALL_DIR:-/usr/local/bin}"
BIN_PATH="$INSTALL_DIR/$BIN_NAME"

echo "🚀 Starting codexbox setup (binary: $BIN_NAME)..."

if ! command -v docker &>/dev/null; then
    echo "❌ Docker is not installed. Please install Docker first." >&2
    exit 1
fi

echo "📁 Creating ~/.codex directory (CODEX_HOME — auth + config persist here)..."
mkdir -p "$HOME/.codex"

echo "🔐 Creating SSH directory for codexbox..."
mkdir -p "$HOME/.ssh/codexbox"

if [ -f "$HOME/.ssh/codexbox/id_ed25519" ]; then
    echo "🔑 SSH key already exists at $HOME/.ssh/codexbox/id_ed25519"
    read -rp "   Replace existing key? [y/N] " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "🗝️ Generating new SSH key for codexbox..."
        ssh-keygen -t ed25519 -C "codexbox" -f "$HOME/.ssh/codexbox/id_ed25519" -N ""
    else
        echo "   Keeping existing key."
    fi
else
    echo "🗝️ Generating SSH key for codexbox..."
    ssh-keygen -t ed25519 -C "codexbox" -f "$HOME/.ssh/codexbox/id_ed25519" -N ""
fi

echo "📦 Pulling codexbox image ($IMAGE)..."
docker pull "$IMAGE"

# get wrapper.sh — from same dir if running locally, otherwise download from GitHub
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-/dev/null}")" 2>/dev/null && pwd)"
WRAPPER_TMP="$(mktemp /tmp/codexbox-wrapper-XXXXXX.sh)"
trap 'rm -f "$WRAPPER_TMP"' EXIT

if [ -f "$SCRIPT_DIR/wrapper.sh" ]; then
    echo "📝 Using local wrapper.sh..."
    cp "$SCRIPT_DIR/wrapper.sh" "$WRAPPER_TMP"
else
    echo "📝 Downloading wrapper.sh..."
    if ! curl -fsSL "$WRAPPER_URL" -o "$WRAPPER_TMP"; then
        echo "❌ Failed to download wrapper.sh" >&2
        exit 1
    fi
fi

if [ ! -s "$WRAPPER_TMP" ]; then
    echo "❌ wrapper.sh is empty — download failed" >&2
    exit 1
fi

echo "📝 Installing $BIN_NAME to $BIN_PATH..."
sudo install -m 755 "$WRAPPER_TMP" "$BIN_PATH"

echo "✅ codexbox setup complete! You can now use '$BIN_NAME' from any directory."
echo ""
echo "🔑 Auth — pick ONE:"
echo "   • API key:      export OPENAI_API_KEY=sk-...   (then just run '$BIN_NAME')"
echo "   • Subscription: $BIN_NAME login --device-auth   (ChatGPT Plus/Pro; persists in ~/.codex)"
echo ""
echo "🔑 If you use git over SSH inside the container, add this public key to GitHub:"
echo "   $HOME/.ssh/codexbox/id_ed25519.pub"
