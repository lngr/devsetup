#!/usr/bin/env bash
set -euo pipefail

# Install devsetup by creating a symlink in ~/.local/bin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p ~/.local/bin
ln -sf "$SCRIPT_DIR/devsetup.sh" ~/.local/bin/devsetup
chmod +x "$SCRIPT_DIR/devsetup.sh"

echo "devsetup installed → ~/.local/bin/devsetup"
echo "Make sure ~/.local/bin is in your PATH."
