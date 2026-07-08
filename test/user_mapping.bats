#!/usr/bin/env bats
# Tests für das Host-User-Mapping in Templates und Wrapper.

load test_helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
  TEST_TMP="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# --- init-worktree: Host-Identität in .env ---

@test "init-worktree.tpl schreibt HOST_USER/UID/GID/HOME in .env" {
  local tpl="$REPO_ROOT/templates/init-worktree.sh.tpl"
  run grep -E '^\s*echo "HOST_USER=\$\(id -un\)"' "$tpl"
  assert_success
  run grep -E '^\s*echo "HOST_UID=\$\(id -u\)"' "$tpl"
  assert_success
  run grep -E '^\s*echo "HOST_GID=\$\(id -g\)"' "$tpl"
  assert_success
  run grep -E '^\s*echo "HOST_HOME=\$HOME"' "$tpl"
  assert_success
}

@test "generiertes init-worktree schreibt HOST_* Werte wirklich in .env" {
  mkdir -p "$TEST_TMP/proj/.devcontainer"
  render_template "$REPO_ROOT/templates/init-worktree.sh.tpl" \
    "$TEST_TMP/proj/.devcontainer/init-worktree.sh" "PROJECT_NAME=demo"
  chmod +x "$TEST_TMP/proj/.devcontainer/init-worktree.sh"
  ( cd "$TEST_TMP/proj" && bash .devcontainer/init-worktree.sh )
  local env_file="$TEST_TMP/proj/.devcontainer/.env"
  run grep -E "^HOST_USER=$(id -un)$" "$env_file"
  assert_success
  run grep -E "^HOST_UID=$(id -u)$" "$env_file"
  assert_success
  run grep -E "^HOST_GID=$(id -g)$" "$env_file"
  assert_success
  run grep -E "^HOST_HOME=$HOME$" "$env_file"
  assert_success
}

# --- Dockerfile: User-Remap ---

@test "generierter Dockerfile enthält den User-Remap-Block" {
  mkdir -p "$TEST_TMP/proj"
  # devsetup erzeugt den Dockerfile inline; hier nur den erzeugten Inhalt prüfen.
  # Der Remap ist an den ARG-Deklarationen und usermod erkennbar.
  run grep -q 'ARG HOST_USER' "$REPO_ROOT/templates/Dockerfile.tpl"
  assert_success
  run grep -q 'usermod -l "\$HOST_USER"' "$REPO_ROOT/templates/Dockerfile.tpl"
  assert_success
  run grep -q 'usermod -d "\$HOST_HOME" -m "\$HOST_USER"' "$REPO_ROOT/templates/Dockerfile.tpl"
  assert_success
}

@test "devsetup.sh erzeugt Dockerfile mit User-Remap" {
  run grep -q 'ARG HOST_USER' "$REPO_ROOT/devsetup.sh"
  assert_success
  run grep -q 'usermod -l' "$REPO_ROOT/devsetup.sh"
  assert_success
}
