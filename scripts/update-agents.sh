#!/usr/bin/env bash
set -euo pipefail

# Updates coding agents: Claude Code, @openai/codex, opencode-ai

die() {
  echo "ERROR: $*" >&2
  exit 1
}

if [ -f /etc/profile ]; then
  # shellcheck disable=SC1091
  . /etc/profile || true
fi
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

maybe_add_nvm_node_to_path() {
  local base bin_dir
  for base in "${NVM_DIR:-}" "/usr/local/share/nvm" "$HOME/.nvm"; do
    [ -n "$base" ] || continue
    bin_dir="$(ls -1d "$base/versions/node"/*/bin 2>/dev/null | sort -V | tail -n 1 || true)"
    if [ -n "$bin_dir" ] && [ -x "$bin_dir/node" ]; then
      export PATH="$bin_dir:$PATH"
      return 0
    fi
  done
  return 1
}

maybe_add_nvm_node_to_path || true

PREFIX="${DEVCONTAINER_NPM_PREFIX:-${NPM_CONFIG_PREFIX:-$HOME/.local}}"
export PATH="$PREFIX/bin:$PATH"
mkdir -p "$PREFIX/bin"

command -v node >/dev/null 2>&1 || die "node not found"
command -v npm  >/dev/null 2>&1 || die "npm not found"

NPM_BIN="$(command -v npm)"
NODE_BIN="$(command -v node)"
export PATH="$(dirname "$NODE_BIN"):$PATH"

# Update npm-based agents
read -r -a DEFAULT_PACKAGES <<<"${DEVCONTAINER_NPM_GLOBAL_PACKAGES:-@openai/codex opencode-ai}"
PACKAGES=("${DEFAULT_PACKAGES[@]}")

echo "Updating npm tools (prefix: $PREFIX): ${PACKAGES[*]}"
NPM_CONFIG_PREFIX="$PREFIX" "$NODE_BIN" "$NPM_BIN" i -g "${PACKAGES[@]}"

# Update Claude Code
if command -v claude >/dev/null 2>&1; then
  echo "Updating Claude Code..."
  claude update 2>/dev/null || curl -fsSL https://claude.ai/install.sh | bash || true
fi
