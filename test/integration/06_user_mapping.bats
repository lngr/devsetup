#!/usr/bin/env bats
# 06_user_mapping.bats – Tier: Build mit abweichendem Host-User, Remap prüfen

load integration_helper

setup_file() {
  export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  UM_DIR="$(create_test_project "usermap")"
  STDIN_TMPDIR="$(mktemp -d /tmp/devsetup-itest-stdin-XXXXXX)"
  export STDIN_TMPDIR
  generate_stdin --base-image=1 --docker-mode=1 > "$STDIN_TMPDIR/usermap.txt"
  run_devsetup "$UM_DIR" "$STDIN_TMPDIR/usermap.txt"

  create_test_compose_override "$UM_DIR"

  # Abweichende Host-Identität simulieren (nicht vscode, andere UID).
  cat >> "$UM_DIR/.devcontainer/.env" <<'ENVEOF'
HOST_USER=devtester
HOST_UID=1234
HOST_GID=1234
HOST_HOME=/home/devtester
ENVEOF

  compose_up "$UM_DIR"
  wait_for_service "$UM_DIR/.devcontainer" "dev" 60
  export UM_DIR
}

teardown_file() {
  cleanup_compose "$UM_DIR"
  rm -rf "$UM_DIR" "$STDIN_TMPDIR"
}

@test "usermap: Container hat User devtester" {
  run compose_exec "$UM_DIR" id -un devtester
  assert_success
  assert_output "devtester"
}

@test "usermap: devtester hat UID 1234" {
  run compose_exec "$UM_DIR" id -u devtester
  assert_success
  assert_output "1234"
}

@test "usermap: Home von devtester ist /home/devtester" {
  run compose_exec "$UM_DIR" bash -c 'getent passwd devtester | cut -d: -f6'
  assert_success
  assert_output "/home/devtester"
}

@test "usermap: kein vscode-User mehr vorhanden" {
  run compose_exec "$UM_DIR" id -un vscode
  assert_failure
}
