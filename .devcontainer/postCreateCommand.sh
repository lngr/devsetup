#!/usr/bin/env bash
set -euo pipefail

# postCreateCommand – runs once after devcontainer is created.
# Installs coding agents (Claude Code, Codex, OpenCode).

# Ensure devcontainer feature PATH (e.g. Node via nvm) is loaded
if [ -f /etc/profile ]; then
  # shellcheck disable=SC1091
  . /etc/profile || true
fi
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"
export PATH="$HOME/.local/bin:$PATH"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

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

: "${TZ:=Europe/Berlin}"
export TZ

# Setup timezone
if [ -f "/usr/share/zoneinfo/$TZ" ]; then
  sudo ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime 2>/dev/null || true
  echo "$TZ" | sudo tee /etc/timezone >/dev/null 2>/dev/null || true
fi

# Verify critical tools
command -v curl >/dev/null 2>&1 || die "curl not found"
command -v node >/dev/null 2>&1 || die "node not found"
command -v npm  >/dev/null 2>&1 || die "npm not found"

# Install coding agents
bash .devcontainer/scripts/install-agents.sh

# Setup aliases for coding agents
ALIASES_FILE="$HOME/.devcontainer_aliases"
cat >"$ALIASES_FILE" <<'ALIASES'
export PATH="$HOME/.local/bin:$PATH"
alias claude='command claude --dangerously-skip-permissions --ide'
alias codex='command codex --dangerously-bypass-approvals-and-sandbox'
ALIASES

SOURCE_LINE='[ -f "$HOME/.devcontainer_aliases" ] && . "$HOME/.devcontainer_aliases"'
for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [ -f "$rc_file" ]; then
    grep -qxF "$SOURCE_LINE" "$rc_file" || printf '\n%s\n' "$SOURCE_LINE" >>"$rc_file"
  else
    printf '%s\n' "$SOURCE_LINE" >"$rc_file"
  fi
done

# Ensure ~/.local/bin is on PATH for bash
BASH_PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
if [ -f "$HOME/.bashrc" ]; then
  grep -qxF "$BASH_PATH_LINE" "$HOME/.bashrc" || printf '\n%s\n' "$BASH_PATH_LINE" >>"$HOME/.bashrc"
fi
