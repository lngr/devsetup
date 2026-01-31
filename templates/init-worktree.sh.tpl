#!/usr/bin/env bash
set -euo pipefail

# Automatically initialize worktree with unique devcontainer configuration.
# Called by devcontainer.json initializeCommand before container creation.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Get the directory name (worktree or project root)
WORKTREE_NAME="$(basename "$PROJECT_DIR")"

# Sanitize: lowercase, only alphanum + hyphens
SANITIZED_NAME="$(echo "$WORKTREE_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g; s/--*/-/g; s/^-//; s/-$//')"

# Build unique compose project name
COMPOSE_PROJECT_NAME="devcontainer-{{PROJECT_NAME}}-${SANITIZED_NAME}"

# Detect X11 socket and Xauthority paths
if [[ "${OSTYPE:-}" == linux-gnu* ]]; then
  X11_SOCKET_DIR="/tmp/.X11-unix"
  XAUTHORITY_PATH="${XAUTHORITY:-$HOME/.Xauthority}"
else
  # Fallback for Windows/macOS: create dummy paths so Docker doesn't fail
  mkdir -p "$SCRIPT_DIR/.x11-dummy/socket"
  touch "$SCRIPT_DIR/.x11-dummy/xauthority"
  X11_SOCKET_DIR="$SCRIPT_DIR/.x11-dummy/socket"
  XAUTHORITY_PATH="$SCRIPT_DIR/.x11-dummy/xauthority"
fi

# Write .env to .devcontainer directory
ENV_FILE="$SCRIPT_DIR/.env"
cat > "$ENV_FILE" <<EOF
COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}
X11_SOCKET_DIR=${X11_SOCKET_DIR}
XAUTHORITY_PATH=${XAUTHORITY_PATH}
EOF

echo "Devcontainer initialized: COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}"
