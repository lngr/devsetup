#!/usr/bin/env bash
set -euo pipefail

# postStartCommand – runs on every devcontainer start.
# Sets up localhost port forwards and calls personal overlay hook.

if [ -f /etc/profile ]; then
  # Profile snippets may expand unset variables (e.g. snapd's apps-bin-path.sh
  # reads XDG_DATA_DIRS); suspend nounset while sourcing so set -u does not
  # abort the shell.
  # shellcheck disable=SC1091
  set +u
  . /etc/profile || true
  set -u
fi
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"
export PATH="$HOME/.local/bin:$PATH"

# Port forward helpers for services running in sibling containers
if ! command -v socat >/dev/null 2>&1; then
  echo "WARN: socat not found; skipping localhost port forwards." >&2
  exit 0
fi

is_pid_running() {
  local pid="$1"
  [ -n "$pid" ] && kill -0 "$pid" >/dev/null 2>&1
}

is_listening() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -ltn "sport = :${port}" 2>/dev/null | grep -q LISTEN
    return $?
  fi
  return 1
}

start_forward() {
  local name="$1" bind_addr="$2" local_port="$3" target_host="$4" target_port="$5"
  local pidfile="/tmp/${name}.pid"

  if [ -f "$pidfile" ]; then
    local existing_pid
    existing_pid="$(cat "$pidfile" 2>/dev/null || true)"
    if is_pid_running "$existing_pid"; then
      return 0
    fi
  fi

  if is_listening "$local_port"; then
    return 0
  fi

  setsid socat \
    "TCP-LISTEN:${local_port},fork,reuseaddr,bind=${bind_addr}" \
    "TCP:${target_host}:${target_port}" \
    >/dev/null 2>&1 &

  local pid=$!
  disown "$pid" 2>/dev/null || true
  echo "$pid" >"$pidfile"
}

# PORT_FORWARDS_MARKER

# --- Personal overlay hook ---
if [ -f ".devcontainer/postStartCommand.local.sh" ]; then
  echo "=== Running personal postStart hook ==="
  bash .devcontainer/postStartCommand.local.sh
fi
