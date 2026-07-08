#!/usr/bin/env bats
# 05_postcreate.bats – Tier 3: postCreateCommand effects in running container

load integration_helper

setup_file() {
  export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  # Use Ubuntu base image (has vscode user)
  POST_DIR="$(create_test_project "postcreate")"
  STDIN_TMPDIR="$(mktemp -d /tmp/devsetup-itest-stdin-XXXXXX)"
  export STDIN_TMPDIR
  generate_stdin --base-image=1 --timezone="America/New_York" \
    --docker-mode=1 > "$STDIN_TMPDIR/postcreate.txt"
  run_devsetup "$POST_DIR" "$STDIN_TMPDIR/postcreate.txt"

  # Create override to neutralize host-specific volumes
  create_test_compose_override "$POST_DIR"

  # Remap zum No-Op machen: Container-User bleibt vscode/1000 unter /home/vscode.
  cat >> "$POST_DIR/.devcontainer/.env" <<'ENVEOF'
HOST_USER=vscode
HOST_UID=1000
HOST_GID=1000
HOST_HOME=/home/vscode
ENVEOF

  # Personal overlay hook: exec-devcontainer normally generates this; here we drop
  # in a marker overlay to verify postCreateCommand.sh actually runs it.
  cat > "$POST_DIR/.devcontainer/postCreateCommand.local.sh" <<'OVL'
#!/usr/bin/env bash
echo "overlay-ran" > "$HOME/.postcreate_overlay_marker"
OVL
  chmod +x "$POST_DIR/.devcontainer/postCreateCommand.local.sh"

  # Build and start
  compose_up "$POST_DIR"

  local compose_dir="$POST_DIR/.devcontainer"
  wait_for_service "$compose_dir" "dev" 60

  # Get the actual project name from devsetup.conf
  local project_name
  project_name="$(grep '^PROJECT_NAME=' "$POST_DIR/.devcontainer/devsetup.conf" | cut -d= -f2)"
  export PROJECT_NAME_PC="$project_name"

  # Run postCreateCommand.sh inside the container as vscode user
  compose_exec "$POST_DIR" su -l vscode -c \
    "cd /workspaces/${project_name} && bash .devcontainer/postCreateCommand.sh" || true

  export POST_DIR
}

teardown_file() {
  cleanup_compose "$POST_DIR"
  rm -rf "$POST_DIR" "$STDIN_TMPDIR"
}

@test "postcreate: timezone is correctly set in /etc/timezone" {
  run compose_exec "$POST_DIR" cat /etc/timezone
  assert_success
  assert_output "America/New_York"
}

@test "postcreate: /etc/localtime is a symlink to correct zone" {
  run compose_exec "$POST_DIR" readlink -f /etc/localtime
  assert_success
  assert_output --partial "America/New_York"
}

@test "postcreate: personal overlay hook is executed" {
  run compose_exec "$POST_DIR" cat /home/vscode/.postcreate_overlay_marker
  assert_success
  assert_output "overlay-ran"
}
