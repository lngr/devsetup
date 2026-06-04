#!/usr/bin/env bats
# End-to-end tests for devsetup.sh

load test_helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
  TEST_TMP="$(mktemp -d)"
  mkdir -p "$TEST_TMP/project"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# Pipe answers for a minimal devsetup run (empty target dir):
#   1. Project name      → testproj
#   2. Git mode          → 1 (readonly)
#   3. Workspace mount   → 1 (project only)
#   4. Claude config     → n (do not share)
#   5. Base image        → 1 (Ubuntu Noble)
#   6. Services          → (empty = none)
#   7. Timezone          → Europe/Berlin (default)
#   8. Docker mode       → 1 (none)
#   9. Confirm           → y
run_devsetup_minimal() {
  local target="${1:-$TEST_TMP/project}"
  printf 'testproj\n1\n1\nn\n1\n\nEurope/Berlin\n1\ny\n' | \
    bash "$REPO_ROOT/devsetup.sh" --target "$target"
}

# Re-run devsetup on a project that already has a devsetup.conf (reconfigure mode).
# No overwrite/not-empty prompts appear; every prompt is pre-filled, so an empty
# answer keeps the saved value. Order: project, git, workspace, claude, base,
# services, timezone, docker, then the final confirm.
run_devsetup_reconfigure_keep() {
  local target="${1:-$TEST_TMP/project}"
  printf '\n\n\n\n\n\n\n\ny\n' | \
    bash "$REPO_ROOT/devsetup.sh" --target "$target"
}

# --- File structure tests ---

@test "devsetup: generates .devcontainer directory" {
  run_devsetup_minimal
  [ -d "$TEST_TMP/project/.devcontainer" ]
}

@test "devsetup: generates devcontainer.json" {
  run_devsetup_minimal
  [ -f "$TEST_TMP/project/.devcontainer/devcontainer.json" ]
}

@test "devsetup: generates docker-compose.yml" {
  run_devsetup_minimal
  [ -f "$TEST_TMP/project/.devcontainer/docker-compose.yml" ]
}

@test "devsetup: generates Dockerfile" {
  run_devsetup_minimal
  [ -f "$TEST_TMP/project/.devcontainer/Dockerfile" ]
}

@test "devsetup: generates init-worktree.sh" {
  run_devsetup_minimal
  [ -f "$TEST_TMP/project/.devcontainer/init-worktree.sh" ]
  [ -x "$TEST_TMP/project/.devcontainer/init-worktree.sh" ]
}

@test "devsetup: generates postCreateCommand.sh" {
  run_devsetup_minimal
  [ -f "$TEST_TMP/project/.devcontainer/postCreateCommand.sh" ]
  [ -x "$TEST_TMP/project/.devcontainer/postCreateCommand.sh" ]
}

@test "devsetup: generates postStartCommand.sh" {
  run_devsetup_minimal
  [ -f "$TEST_TMP/project/.devcontainer/postStartCommand.sh" ]
  [ -x "$TEST_TMP/project/.devcontainer/postStartCommand.sh" ]
}

@test "devsetup: generates devsetup.conf" {
  run_devsetup_minimal
  [ -f "$TEST_TMP/project/.devcontainer/devsetup.conf" ]
}

@test "devsetup: generates .env" {
  run_devsetup_minimal
  [ -f "$TEST_TMP/project/.devcontainer/.env" ]
}

# --- No personal files ---

@test "devsetup: does NOT generate docker-compose.local.yml" {
  run_devsetup_minimal
  [ ! -f "$TEST_TMP/project/.devcontainer/docker-compose.local.yml" ]
}

@test "devsetup: does NOT generate postCreateCommand.local.sh" {
  run_devsetup_minimal
  [ ! -f "$TEST_TMP/project/.devcontainer/postCreateCommand.local.sh" ]
}

@test "devsetup: does NOT generate postStartCommand.local.sh" {
  run_devsetup_minimal
  [ ! -f "$TEST_TMP/project/.devcontainer/postStartCommand.local.sh" ]
}

@test "devsetup: does NOT generate exec-devcontainer.sh in project" {
  run_devsetup_minimal
  [ ! -f "$TEST_TMP/project/exec-devcontainer.sh" ]
}

@test "devsetup: does NOT generate scripts/ directory" {
  run_devsetup_minimal
  [ ! -d "$TEST_TMP/project/.devcontainer/scripts" ]
}

# --- Content tests ---

@test "devsetup: devcontainer.json references docker-compose.local.yml" {
  run_devsetup_minimal
  run grep "docker-compose.local.yml" "$TEST_TMP/project/.devcontainer/devcontainer.json"
  assert_success
}

@test "devsetup: devcontainer.json has correct project name" {
  run_devsetup_minimal
  run grep '"name": "testproj"' "$TEST_TMP/project/.devcontainer/devcontainer.json"
  assert_success
}

@test "devsetup: docker-compose.yml has no X11 volumes" {
  run_devsetup_minimal
  run grep "X11" "$TEST_TMP/project/.devcontainer/docker-compose.yml"
  assert_failure
}

@test "devsetup: docker-compose.yml has no DISPLAY env" {
  run_devsetup_minimal
  run grep "DISPLAY" "$TEST_TMP/project/.devcontainer/docker-compose.yml"
  assert_failure
}

@test "devsetup: postCreateCommand.sh calls local hook" {
  run_devsetup_minimal
  run grep "postCreateCommand.local.sh" "$TEST_TMP/project/.devcontainer/postCreateCommand.sh"
  assert_success
}

@test "devsetup: postStartCommand.sh calls local hook" {
  run_devsetup_minimal
  run grep "postStartCommand.local.sh" "$TEST_TMP/project/.devcontainer/postStartCommand.sh"
  assert_success
}

@test "devsetup: postCreateCommand.sh does NOT install agents directly" {
  run_devsetup_minimal
  run grep "install-agents" "$TEST_TMP/project/.devcontainer/postCreateCommand.sh"
  assert_failure
}

# --- devsetup.conf content ---

@test "devsetup: devsetup.conf contains PROJECT_NAME" {
  run_devsetup_minimal
  run grep 'PROJECT_NAME="testproj"' "$TEST_TMP/project/.devcontainer/devsetup.conf"
  assert_success
}

@test "devsetup: devsetup.conf contains GIT_MODE" {
  run_devsetup_minimal
  run grep 'GIT_MODE="readonly"' "$TEST_TMP/project/.devcontainer/devsetup.conf"
  assert_success
}

@test "devsetup: devsetup.conf contains DOCKER_MODE" {
  run_devsetup_minimal
  run grep 'DOCKER_MODE="none"' "$TEST_TMP/project/.devcontainer/devsetup.conf"
  assert_success
}

# --- .gitignore ---

@test "devsetup: creates .gitignore with overlay entries" {
  run_devsetup_minimal
  [ -f "$TEST_TMP/project/.gitignore" ]
  run grep "docker-compose.local.yml" "$TEST_TMP/project/.gitignore"
  assert_success
  run grep "postCreateCommand.local.sh" "$TEST_TMP/project/.gitignore"
  assert_success
  run grep "postStartCommand.local.sh" "$TEST_TMP/project/.gitignore"
  assert_success
  run grep "devsetup.conf" "$TEST_TMP/project/.gitignore"
  assert_success
}

@test "devsetup: .gitignore is idempotent" {
  run_devsetup_minimal
  local first_size
  first_size=$(wc -c < "$TEST_TMP/project/.gitignore")

  # Run again – reconfigure mode keeps every value.
  run_devsetup_reconfigure_keep

  local second_size
  second_size=$(wc -c < "$TEST_TMP/project/.gitignore")
  assert_equal "$first_size" "$second_size"
}

# --- Reconfigure mode ---

@test "devsetup: reconfigure keeps devsetup.conf unchanged" {
  run_devsetup_minimal
  local first
  first="$(cat "$TEST_TMP/project/.devcontainer/devsetup.conf")"

  run_devsetup_reconfigure_keep

  local second
  second="$(cat "$TEST_TMP/project/.devcontainer/devsetup.conf")"
  assert_equal "$first" "$second"
}

@test "devsetup: reconfigure announces existing config, not overwrite prompt" {
  run_devsetup_minimal
  run run_devsetup_reconfigure_keep
  assert_success
  assert_output --partial "Bestehende Konfiguration gefunden"
  refute_output --partial "already exists. Overwrite?"
}

@test "devsetup: reconfigure changes only the edited value" {
  run_devsetup_minimal
  run grep 'DOCKER_MODE="none"' "$TEST_TMP/project/.devcontainer/devsetup.conf"
  assert_success

  # Reconfigure, keep everything except docker mode → 2 (privileged).
  printf '\n\n\n\n\n\n\n2\ny\n' | \
    bash "$REPO_ROOT/devsetup.sh" --target "$TEST_TMP/project"

  run grep 'DOCKER_MODE="privileged"' "$TEST_TMP/project/.devcontainer/devsetup.conf"
  assert_success
  run grep 'PROJECT_NAME="testproj"' "$TEST_TMP/project/.devcontainer/devsetup.conf"
  assert_success
  run grep 'GIT_MODE="readonly"' "$TEST_TMP/project/.devcontainer/devsetup.conf"
  assert_success
}

@test "devsetup: reconfigure keeps selected services" {
  # First run selecting PostgreSQL (1) + Redis (2): project, git, workspace,
  # claude, base, toggle 1, toggle 2, confirm, postgres dbs, timezone, docker, confirm.
  printf 'svcproj\n1\n1\nn\n1\n1\n2\n\nsvcproj\nEurope/Berlin\n1\ny\n' | \
    bash "$REPO_ROOT/devsetup.sh" --target "$TEST_TMP/project"
  run grep 'SELECTED_SERVICES="0 1"' "$TEST_TMP/project/.devcontainer/devsetup.conf"
  assert_success

  # Reconfigure keeping all – postgres prompt reappears because postgres stays
  # selected, so one extra empty line before timezone/docker/confirm.
  printf '\n\n\n\n\n\n\n\n\ny\n' | \
    bash "$REPO_ROOT/devsetup.sh" --target "$TEST_TMP/project"
  run grep 'SELECTED_SERVICES="0 1"' "$TEST_TMP/project/.devcontainer/devsetup.conf"
  assert_success
  [ -f "$TEST_TMP/project/.devcontainer/docker-compose.services.yml" ]
}

@test "devsetup: fresh run on non-empty dir still prompts (no devsetup.conf)" {
  echo "existing" > "$TEST_TMP/project/README.md"
  # No devsetup.conf → not-empty confirm appears first. Decline it → abort.
  run bash -c "printf 'n\n' | bash '$REPO_ROOT/devsetup.sh' --target '$TEST_TMP/project'"
  assert_output --partial "Target directory is not empty"
  [ ! -d "$TEST_TMP/project/.devcontainer" ]
}

# --- init-worktree.sh ---

@test "devsetup: init-worktree.sh generates empty local compose stub" {
  run_devsetup_minimal
  # Run init-worktree.sh
  (cd "$TEST_TMP/project" && bash .devcontainer/init-worktree.sh)
  [ -f "$TEST_TMP/project/.devcontainer/docker-compose.local.yml" ]
  run grep "services: {}" "$TEST_TMP/project/.devcontainer/docker-compose.local.yml"
  assert_success
}

@test "devsetup: init-worktree.sh does not overwrite existing local compose" {
  run_devsetup_minimal
  echo "# custom" > "$TEST_TMP/project/.devcontainer/docker-compose.local.yml"
  (cd "$TEST_TMP/project" && bash .devcontainer/init-worktree.sh)
  run grep "# custom" "$TEST_TMP/project/.devcontainer/docker-compose.local.yml"
  assert_success
}

# --- --install ---

@test "devsetup: --install symlinks both devsetup and exec-devcontainer" {
  local test_bin="$TEST_TMP/bin"
  mkdir -p "$test_bin"
  HOME="$TEST_TMP" XDG_DATA_HOME="$TEST_TMP" \
    bash "$REPO_ROOT/devsetup.sh" --install
  [ -L "$TEST_TMP/.local/bin/devsetup" ]
  [ -L "$TEST_TMP/.local/bin/exec-devcontainer" ]
}
