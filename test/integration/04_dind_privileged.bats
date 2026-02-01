#!/usr/bin/env bats
# 04_dind_privileged.bats – Tier 3: Docker-in-Docker privileged mode

load integration_helper

setup_file() {
  export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  # Generate with Docker-mode=2 (privileged)
  DIND_DIR="$(create_test_project "dind")"
  STDIN_TMPDIR="$(mktemp -d /tmp/devsetup-itest-stdin-XXXXXX)"
  export STDIN_TMPDIR
  generate_stdin --git-mode=1 --base-image=1 --docker-mode=2 > "$STDIN_TMPDIR/dind.txt"
  run_devsetup "$DIND_DIR" "$STDIN_TMPDIR/dind.txt"

  # Create override to neutralize host-specific volumes
  create_test_compose_override "$DIND_DIR"

  # Build and start
  compose_up "$DIND_DIR"

  local compose_dir="$DIND_DIR/.devcontainer"
  wait_for_service "$compose_dir" "dev" 60

  export DIND_DIR
}

teardown_file() {
  cleanup_compose "$DIND_DIR"
  rm -rf "$DIND_DIR" "$STDIN_TMPDIR"
}

@test "dind: docker-compose.yml has privileged: true" {
  run grep "privileged: true" "$DIND_DIR/.devcontainer/docker-compose.yml"
  assert_success
}

@test "dind: devcontainer.json has docker-in-docker feature" {
  run grep "docker-in-docker" "$DIND_DIR/.devcontainer/devcontainer.json"
  assert_success
}

@test "dind: container runs in privileged mode" {
  local compose_dir="$DIND_DIR/.devcontainer"
  local container_id
  container_id="$(cd "$compose_dir" && docker compose ps -q dev)"
  run docker inspect --format '{{.HostConfig.Privileged}}' "$container_id"
  assert_success
  assert_output "true"
}
