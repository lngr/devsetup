#!/usr/bin/env bash
set -euo pipefail

# Installs coding agents: Claude Code, @openai/codex, opencode-ai

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

GLOBAL_ROOT="$(NPM_CONFIG_PREFIX="$PREFIX" "$NPM_BIN" root -g 2>/dev/null || true)"
if [ -z "$GLOBAL_ROOT" ]; then
  GLOBAL_ROOT="$PREFIX/lib/node_modules"
fi

# Install npm-based agents
read -r -a DEFAULT_PACKAGES <<<"${DEVCONTAINER_NPM_GLOBAL_PACKAGES:-@openai/codex opencode-ai}"
PACKAGES=("${DEFAULT_PACKAGES[@]}")

for pkg in "${PACKAGES[@]}"; do
  if [ -d "$GLOBAL_ROOT/$pkg" ]; then
    echo "npm tool already installed, skipping: $pkg"
    continue
  fi
  echo "Installing npm tool: $pkg (prefix: $PREFIX)"
  NPM_CONFIG_PREFIX="$PREFIX" "$NODE_BIN" "$NPM_BIN" i -g --progress=false --loglevel=warn "$pkg"
done

# Install Claude Code CLI
if ! command -v claude >/dev/null 2>&1; then
  echo "Installing Claude Code CLI..."
  if curl -fsSL https://claude.ai/install.sh | bash; then
    command -v claude >/dev/null 2>&1 || echo "WARNING: Claude Code install finished but 'claude' is still not on PATH."
  else
    echo "WARNING: Claude Code installation failed (network issue?). You can install it later with: curl -fsSL https://claude.ai/install.sh | bash"
  fi
fi

# Sanity checks
if printf '%s\n' "${PACKAGES[@]}" | grep -qx "@openai/codex"; then
  command -v codex >/dev/null 2>&1 || die "@openai/codex installed but 'codex' not on PATH."
fi
if printf '%s\n' "${PACKAGES[@]}" | grep -qx "opencode-ai"; then
  command -v opencode >/dev/null 2>&1 || die "opencode-ai installed but 'opencode' not on PATH."
fi
