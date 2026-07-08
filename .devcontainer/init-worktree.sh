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

WORKSPACE_MOUNT="${WORKSPACE_MOUNT:-project}"
CONTAINER_SCOPE="${CONTAINER_SCOPE:-per-worktree}"

if [ "$WORKSPACE_MOUNT" = "project" ]; then
  CONTAINER_SCOPE="per-worktree"
fi

if [ "$CONTAINER_SCOPE" = "shared" ] || [ "$SANITIZED_NAME" = "devsetup" ]; then
  COMPOSE_PROJECT_NAME="devcontainer-devsetup"
else
  COMPOSE_PROJECT_NAME="devcontainer-devsetup-${SANITIZED_NAME}"
fi

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

# Host-Identität festhalten, damit der Container-User dem Host-User entspricht.
for _host_var in HOST_USER HOST_UID HOST_GID HOST_HOME; do
  sed -i "/^${_host_var}=/d" "$ENV_FILE" 2>/dev/null || true
done
{
  echo "HOST_USER=$(id -un)"
  echo "HOST_UID=$(id -u)"
  echo "HOST_GID=$(id -g)"
  echo "HOST_HOME=$HOME"
} >> "$ENV_FILE"

echo "Devcontainer initialized: COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}"

# Ensure docker-compose.local.yml stub exists for personal overlays
LOCAL_COMPOSE="$SCRIPT_DIR/docker-compose.local.yml"
if [ ! -f "$LOCAL_COMPOSE" ]; then
  cat > "$LOCAL_COMPOSE" <<'YAMLEOF'
# Personal docker-compose overrides (generated, gitignored).
# Overwritten by exec-devcontainer with personal settings.
services: {}
YAMLEOF
  echo "Created docker-compose.local.yml stub"
fi
