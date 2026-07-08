#!/usr/bin/env bats
# Tests für die Compose-Namensbildung in templates/init-worktree.sh.tpl

load test_helper

setup() {
  TEST_TMP="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# Rendert das Template in ein Worktree-Verzeichnis und führt es aus.
# Usage: render_and_run <dir_basename> <project_name> <workspace_mount> <container_scope> [env_scope]
# Setzt CPN auf den erzeugten COMPOSE_PROJECT_NAME.
render_and_run() {
  local dir_basename="$1" project="$2" mount="$3" scope="$4" env_scope="${5:-}"
  local wt="$TEST_TMP/$dir_basename"
  mkdir -p "$wt/.devcontainer"
  render_template "$REPO_ROOT/templates/init-worktree.sh.tpl" \
    "$wt/.devcontainer/init-worktree.sh" \
    "PROJECT_NAME=$project" "WORKSPACE_MOUNT=$mount" "CONTAINER_SCOPE=$scope"
  chmod +x "$wt/.devcontainer/init-worktree.sh"
  if [ -n "$env_scope" ]; then
    CONTAINER_SCOPE="$env_scope" bash "$wt/.devcontainer/init-worktree.sh" >/dev/null
  else
    bash "$wt/.devcontainer/init-worktree.sh" >/dev/null
  fi
  CPN="$(grep '^COMPOSE_PROJECT_NAME=' "$wt/.devcontainer/.env" | cut -d= -f2-)"
}

@test "shared: stabiler Name auch in abweichendem Worktree-Verzeichnis" {
  render_and_run "featurex" "myproj" "parent" "shared"
  assert_equal "$CPN" "devcontainer-myproj"
}

@test "per-worktree: Haupt-Checkout ohne Verdopplung" {
  render_and_run "myproj" "myproj" "parent" "per-worktree"
  assert_equal "$CPN" "devcontainer-myproj"
}

@test "per-worktree: abweichendes Verzeichnis erhält Suffix" {
  render_and_run "featurex" "myproj" "parent" "per-worktree"
  assert_equal "$CPN" "devcontainer-myproj-featurex"
}

@test "project mount erzwingt per-worktree trotz shared-Default" {
  render_and_run "featurex" "myproj" "project" "shared"
  assert_equal "$CPN" "devcontainer-myproj-featurex"
}

@test "Env-Override gewinnt über gebackenen Default" {
  render_and_run "featurex" "myproj" "parent" "shared" "per-worktree"
  assert_equal "$CPN" "devcontainer-myproj-featurex"
}
