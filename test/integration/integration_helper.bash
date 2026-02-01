#!/usr/bin/env bash
# integration_helper.bash – Shared helpers for integration tests

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# Load bats helper libraries
load "${REPO_ROOT}/test/libs/bats-support/load"
load "${REPO_ROOT}/test/libs/bats-assert/load"

# Unique prefix for all test resources
TEST_RUN_ID="devsetup-itest-$$-${RANDOM}"

# --- Project scaffolding ---

# Create an isolated temp directory for a test project
# Usage: create_test_project <name>
# Prints the path to stdout
create_test_project() {
  local name="${1:-testproj}"
  local dir
  dir="$(mktemp -d "/tmp/${TEST_RUN_ID}-${name}-XXXXXX")"
  echo "$dir"
}

# --- stdin generation ---

# Generate the stdin sequence for devsetup.sh
# Usage: generate_stdin [options] > stdin_file
#   --project-name=NAME     (default: empty = accept default)
#   --git-mode=1|2          (default: 1 = readonly)
#   --base-image=1-7        (default: 1 = Ubuntu)
#   --custom-image=URL      (required if --base-image=7)
#   --services="1,3,5"      (1-based toggle numbers; default: none)
#   --postgres-dbs=NAMES    (comma-sep DB names if postgres selected)
#   --timezone=TZ           (default: empty = accept default)
#   --docker-mode=1|2|3     (default: 1 = none)
#   --dir-not-empty         (prepend confirm for non-empty dir)
#   --overwrite             (prepend confirm for existing .devcontainer)
generate_stdin() {
  local project_name=""
  local git_mode="1"
  local base_image="1"
  local custom_image=""
  local services=""
  local postgres_dbs=""
  local timezone=""
  local docker_mode="1"
  local dir_not_empty=false
  local overwrite=false

  while [ $# -gt 0 ]; do
    case "$1" in
      --project-name=*) project_name="${1#*=}" ;;
      --git-mode=*)     git_mode="${1#*=}" ;;
      --base-image=*)   base_image="${1#*=}" ;;
      --custom-image=*) custom_image="${1#*=}" ;;
      --services=*)     services="${1#*=}" ;;
      --postgres-dbs=*) postgres_dbs="${1#*=}" ;;
      --timezone=*)     timezone="${1#*=}" ;;
      --docker-mode=*)  docker_mode="${1#*=}" ;;
      --dir-not-empty)  dir_not_empty=true ;;
      --overwrite)      overwrite=true ;;
      *) echo "generate_stdin: unknown option: $1" >&2; return 1 ;;
    esac
    shift
  done

  # Conditional: overwrite existing .devcontainer
  if [ "$overwrite" = true ]; then
    echo "y"
  fi

  # Conditional: non-empty directory confirm
  if [ "$dir_not_empty" = true ]; then
    echo "y"
  fi

  # Project name (empty = accept default)
  echo "$project_name"

  # Git mode
  echo "$git_mode"

  # Base image
  echo "$base_image"

  # Custom image URL (only if base_image=7)
  if [ "$base_image" = "7" ]; then
    echo "$custom_image"
  fi

  # Services: each number toggles, then empty line confirms
  if [ -n "$services" ]; then
    IFS=',' read -ra svc_arr <<< "$services"
    for s in "${svc_arr[@]}"; do
      echo "$s"
    done
  fi
  # Empty line to confirm service selection
  echo ""

  # Postgres DB names (only if postgres was selected, i.e. service 1)
  if [ -n "$services" ]; then
    IFS=',' read -ra svc_arr <<< "$services"
    for s in "${svc_arr[@]}"; do
      if [ "$s" = "1" ]; then
        echo "$postgres_dbs"
        break
      fi
    done
  fi

  # Timezone (empty = accept default)
  echo "$timezone"

  # Docker mode
  echo "$docker_mode"

  # Final confirmation
  echo "y"
}

# --- devsetup execution ---

# Run devsetup.sh with piped stdin
# Usage: run_devsetup <target_dir> <stdin_file>
# Sets DEVSETUP_OUTPUT and DEVSETUP_STATUS
run_devsetup() {
  local target_dir="$1"
  local stdin_file="$2"
  DEVSETUP_OUTPUT="$(bash "$REPO_ROOT/devsetup.sh" --target "$target_dir" < "$stdin_file" 2>&1)" || true
  DEVSETUP_STATUS=$?
}

# --- Docker helpers ---

# Build compose file arguments for a project directory
# Usage: _compose_file_args <compose_dir>
# Sets COMPOSE_FILE_ARGS array
_compose_file_args() {
  local compose_dir="$1"
  COMPOSE_FILE_ARGS=("-f" "docker-compose.yml")
  if [ -f "$compose_dir/docker-compose.services.yml" ]; then
    COMPOSE_FILE_ARGS+=("-f" "docker-compose.services.yml")
  fi
  if [ -f "$compose_dir/docker-compose.override.yml" ]; then
    COMPOSE_FILE_ARGS+=("-f" "docker-compose.override.yml")
  fi
}

# Wait for a container to be running
# Usage: wait_for_service <compose_dir> <service> [timeout_seconds]
wait_for_service() {
  local compose_dir="$1"
  local service="$2"
  local timeout="${3:-60}"
  local elapsed=0

  _compose_file_args "$compose_dir"

  while [ "$elapsed" -lt "$timeout" ]; do
    local state
    state="$(cd "$compose_dir" && docker compose "${COMPOSE_FILE_ARGS[@]}" ps --format '{{.State}}' "$service" 2>/dev/null || true)"
    if [ "$state" = "running" ]; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  echo "Timeout waiting for $service to be running (waited ${timeout}s)" >&2
  return 1
}

# TCP connectivity check via throwaway alpine container
# Usage: check_tcp <network> <host> <port> [timeout]
check_tcp() {
  local network="$1"
  local host="$2"
  local port="$3"
  local timeout="${4:-5}"
  docker run --rm --network "$network" alpine:3.20 \
    sh -c "nc -zw${timeout} ${host} ${port}" 2>/dev/null
}

# Retry a command with delay between attempts
# Usage: retry <max_attempts> <delay_seconds> <command...>
retry() {
  local max_attempts="$1"
  local delay="$2"
  shift 2
  local attempt=1
  while [ "$attempt" -le "$max_attempts" ]; do
    if "$@" 2>&1; then
      return 0
    fi
    if [ "$attempt" -lt "$max_attempts" ]; then
      sleep "$delay"
    fi
    attempt=$((attempt + 1))
  done
  return 1
}

# Create a docker-compose override that neutralizes host-specific volumes
# Usage: create_test_compose_override <project_dir>
create_test_compose_override() {
  local project_dir="$1"
  local project_name
  project_name="$(grep '^PROJECT_NAME=' "$project_dir/.devcontainer/devsetup.conf" | cut -d= -f2)"
  local override_file="$project_dir/.devcontainer/docker-compose.override.yml"

  cat > "$override_file" <<YAML
services:
  dev:
    volumes:
      - ${project_dir}:/workspaces/${project_name}
    environment:
      - DISPLAY=
      - XAUTHORITY=
YAML
  echo "$override_file"
}

# Cleanup compose stack
# Usage: cleanup_compose <project_dir>
cleanup_compose() {
  local project_dir="$1"
  local compose_dir="$project_dir/.devcontainer"
  if [ -f "$compose_dir/docker-compose.yml" ]; then
    _compose_file_args "$compose_dir"
    (cd "$compose_dir" && docker compose "${COMPOSE_FILE_ARGS[@]}" down -v --remove-orphans 2>/dev/null) || true
  fi
}

# Build and start compose stack with override
# Usage: compose_up <project_dir> [extra_compose_files...]
compose_up() {
  local project_dir="$1"
  shift
  local compose_dir="$project_dir/.devcontainer"

  _compose_file_args "$compose_dir"
  local compose_args=("${COMPOSE_FILE_ARGS[@]}")

  # Add any extra files
  for f in "$@"; do
    compose_args+=("-f" "$f")
  done

  (cd "$compose_dir" && docker compose "${compose_args[@]}" build 2>&1) || return 1
  (cd "$compose_dir" && docker compose "${compose_args[@]}" up -d 2>&1) || return 1
}

# Run a command in the dev container
# Usage: compose_exec <project_dir> <command...>
compose_exec() {
  local project_dir="$1"
  shift
  local compose_dir="$project_dir/.devcontainer"

  _compose_file_args "$compose_dir"

  (cd "$compose_dir" && docker compose "${COMPOSE_FILE_ARGS[@]}" exec -T dev "$@" 2>&1)
}
