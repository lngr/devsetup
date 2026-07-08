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

# --- docker-compose: build.args und gitconfig-Ziel ---

@test "compose-Template reicht HOST_* als build.args durch" {
  local tpl="$REPO_ROOT/templates/docker-compose.yml.tpl"
  run grep -q 'HOST_USER: ${HOST_USER:-vscode}' "$tpl"
  assert_success
  run grep -q 'HOST_UID: ${HOST_UID:-1000}' "$tpl"
  assert_success
  run grep -q 'HOST_GID: ${HOST_GID:-1000}' "$tpl"
  assert_success
  run grep -q 'HOST_HOME: ${HOST_HOME:-/home/vscode}' "$tpl"
  assert_success
}

@test "compose-Template mountet gitconfig unter Host-Home" {
  run grep -q '${HOST_HOME:-/home/vscode}/.gitconfig' "$REPO_ROOT/templates/docker-compose.yml.tpl"
  assert_success
}

@test "compose-Template mountet gitconfig nicht mehr unter /home/vscode fix" {
  run grep -q ':/home/vscode/.gitconfig' "$REPO_ROOT/templates/docker-compose.yml.tpl"
  assert_failure
}

# --- devcontainer.json: remoteUser ---

@test "devcontainer-Template setzt remoteUser auf localEnv USER" {
  run grep -q '"remoteUser": "${localEnv:USER}"' "$REPO_ROOT/templates/devcontainer.json.tpl"
  assert_success
}

@test "devcontainer-Template hat kein fixes remoteUser vscode" {
  run grep -q '"remoteUser": "vscode"' "$REPO_ROOT/templates/devcontainer.json.tpl"
  assert_failure
}
