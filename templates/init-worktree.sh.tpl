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

# Write .env to .devcontainer directory
ENV_FILE="$SCRIPT_DIR/.env"
cat > "$ENV_FILE" <<EOF
COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}
EOF

echo "Devcontainer initialized: COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}"

# Generate empty docker-compose.local.yml stub if not present
LOCAL_COMPOSE="$SCRIPT_DIR/docker-compose.local.yml"
if [ ! -f "$LOCAL_COMPOSE" ]; then
  cat > "$LOCAL_COMPOSE" <<'STUBEOF'
# Personal docker-compose overrides (this file is gitignored).
services: {}
STUBEOF
  echo "Generated empty docker-compose.local.yml stub"
fi
