#!/usr/bin/env bats
# 01_generation.bats – Tier 1: Verify generated file structure and content

load integration_helper

setup_file() {
  export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  # Temp dir for stdin files (separate from target dirs to avoid "non-empty" prompts)
  STDIN_TMPDIR="$(mktemp -d /tmp/devsetup-itest-stdin-XXXXXX)"
  export STDIN_TMPDIR

  # Szenario 1: Minimal, Ubuntu, keine Services, kein Docker
  MINIMAL_DIR="$(create_test_project "minimal")"
  local stdin_file="$STDIN_TMPDIR/minimal.txt"
  generate_stdin --base-image=1 --docker-mode=1 > "$stdin_file"
  run_devsetup "$MINIMAL_DIR" "$stdin_file"
  export MINIMAL_DIR

  # Szenario 2: Alle Services, Ubuntu, alle 6 Services
  ALLSVC_DIR="$(create_test_project "allsvc")"
  stdin_file="$STDIN_TMPDIR/allsvc.txt"
  # Dir will be non-empty because of .keep file
  generate_stdin --base-image=1 --services="1,2,3,4,5,6" \
    --postgres-dbs="appdb,testdb" --docker-mode=1 --dir-not-empty > "$stdin_file"
  touch "$ALLSVC_DIR/.keep"
  run_devsetup "$ALLSVC_DIR" "$stdin_file"
  export ALLSVC_DIR

  # Szenario 3: Go, keine Services, DinD privileged, Nur-Projekt-Mount (Scope per-worktree)
  WRITABLE_DIR="$(create_test_project "writable")"
  stdin_file="$STDIN_TMPDIR/writable.txt"
  generate_stdin --base-image=6 --docker-mode=2 > "$stdin_file"
  run_devsetup "$WRITABLE_DIR" "$stdin_file"
  export WRITABLE_DIR
}

teardown_file() {
  rm -rf "$MINIMAL_DIR" "$ALLSVC_DIR" "$WRITABLE_DIR" "$STDIN_TMPDIR"
}

# ── Minimal scenario ──

@test "minimal: .devcontainer/ directory exists" {
  [ -d "$MINIMAL_DIR/.devcontainer" ]
}

@test "minimal: Dockerfile has correct base image" {
  run grep "^FROM mcr.microsoft.com/devcontainers/base:noble" "$MINIMAL_DIR/.devcontainer/Dockerfile"
  assert_success
}

@test "minimal: docker-compose.yml exists and has sleep infinity" {
  [ -f "$MINIMAL_DIR/.devcontainer/docker-compose.yml" ]
  run grep "sleep infinity" "$MINIMAL_DIR/.devcontainer/docker-compose.yml"
  assert_success
}

@test "minimal: devcontainer.json is valid JSON" {
  run jq empty "$MINIMAL_DIR/.devcontainer/devcontainer.json"
  assert_success
}

@test "minimal: devcontainer.json compose files include local overlay" {
  local json="$MINIMAL_DIR/.devcontainer/devcontainer.json"
  run jq -r '.dockerComposeFile | length' "$json"
  assert_output "2"
  run jq -e '.dockerComposeFile | index("docker-compose.yml")' "$json"
  assert_success
  run jq -e '.dockerComposeFile | index("docker-compose.local.yml")' "$json"
  assert_success
}

@test "minimal: init-worktree.sh exists and is executable" {
  [ -f "$MINIMAL_DIR/.devcontainer/init-worktree.sh" ]
  [ -x "$MINIMAL_DIR/.devcontainer/init-worktree.sh" ]
}

@test "minimal: postCreateCommand.sh has default timezone" {
  run grep "Europe/Berlin" "$MINIMAL_DIR/.devcontainer/postCreateCommand.sh"
  assert_success
}

@test "minimal: postStartCommand.sh exists" {
  [ -f "$MINIMAL_DIR/.devcontainer/postStartCommand.sh" ]
  [ -x "$MINIMAL_DIR/.devcontainer/postStartCommand.sh" ]
}

@test "minimal: .env has COMPOSE_PROJECT_NAME" {
  run grep "^COMPOSE_PROJECT_NAME=" "$MINIMAL_DIR/.devcontainer/.env"
  assert_success
}

@test "minimal: devsetup.conf has all settings" {
  local conf="$MINIMAL_DIR/.devcontainer/devsetup.conf"
  [ -f "$conf" ]
  run grep "^PROJECT_NAME=" "$conf"
  assert_success
  run grep '^CONTAINER_SCOPE=' "$conf"
  assert_success
  run grep '^WORKSPACE_MOUNT=' "$conf"
  assert_success
  run grep "^BASE_IMAGE=" "$conf"
  assert_success
  run grep "^TIMEZONE=" "$conf"
  assert_success
  run grep '^DOCKER_MODE="none"' "$conf"
  assert_success
}

@test "minimal: no docker-compose.services.yml when no services" {
  [ ! -f "$MINIMAL_DIR/.devcontainer/docker-compose.services.yml" ]
}

@test "minimal: .gitignore ignoriert .devcontainer/.env" {
  run grep -qx '.devcontainer/.env' "$MINIMAL_DIR/.gitignore"
  assert_success
}

# ── All-Services scenario ──

@test "allsvc: docker-compose.services.yml exists" {
  [ -f "$ALLSVC_DIR/.devcontainer/docker-compose.services.yml" ]
}

@test "allsvc: services file contains all 8 services" {
  local svc_file="$ALLSVC_DIR/.devcontainer/docker-compose.services.yml"
  run grep "postgres:" "$svc_file"
  assert_success
  run grep "pgadmin:" "$svc_file"
  assert_success
  run grep "redis:" "$svc_file"
  assert_success
  run grep "rabbitmq:" "$svc_file"
  assert_success
  run grep "mysql:" "$svc_file"
  assert_success
  run grep "phpmyadmin:" "$svc_file"
  assert_success
  run grep "minio:" "$svc_file"
  assert_success
  run grep "mongodb:" "$svc_file"
  assert_success
}

@test "allsvc: postgres-init/ directory exists" {
  [ -d "$ALLSVC_DIR/.devcontainer/postgres-init" ]
  [ -f "$ALLSVC_DIR/.devcontainer/postgres-init/01-create-databases.sh" ]
}

@test "allsvc: postgres-init creates both databases" {
  local init="$ALLSVC_DIR/.devcontainer/postgres-init/01-create-databases.sh"
  run grep 'create_db "appdb"' "$init"
  assert_success
  run grep 'create_db "testdb"' "$init"
  assert_success
}

@test "allsvc: devcontainer.json has base, services and local compose files" {
  run jq -r '.dockerComposeFile | length' "$ALLSVC_DIR/.devcontainer/devcontainer.json"
  assert_success
  assert_output "3"
  run jq -e '.dockerComposeFile | index("docker-compose.services.yml")' \
    "$ALLSVC_DIR/.devcontainer/devcontainer.json"
  assert_success
}

@test "allsvc: devcontainer.json runServices includes all services" {
  local json="$ALLSVC_DIR/.devcontainer/devcontainer.json"
  for svc in dev postgres pgadmin redis rabbitmq mysql phpmyadmin minio mongodb; do
    run jq -e --arg s "$svc" '.runServices | index($s)' "$json"
    assert_success
  done
}

@test "allsvc: postStartCommand has start_forward lines" {
  run grep "start_forward" "$ALLSVC_DIR/.devcontainer/postStartCommand.sh"
  assert_success
}

# ── Writable scenario (Nur-Projekt-Mount) ──

@test "writable: no :ro for .git in compose" {
  run grep ".git:ro" "$WRITABLE_DIR/.devcontainer/docker-compose.yml"
  assert_failure
}

@test "project mount: compose marks .git as part of workspace" {
  run grep "Workspace-Mounts" "$WRITABLE_DIR/.devcontainer/docker-compose.yml"
  assert_success
}

@test "project mount: devsetup.conf has per-worktree scope" {
  run grep '^CONTAINER_SCOPE="per-worktree"' "$WRITABLE_DIR/.devcontainer/devsetup.conf"
  assert_success
}

@test "writable: Dockerfile has Go base image" {
  run grep "^FROM mcr.microsoft.com/devcontainers/go:latest" "$WRITABLE_DIR/.devcontainer/Dockerfile"
  assert_success
}

@test "writable: privileged mode in docker-compose.yml" {
  run grep "privileged: true" "$WRITABLE_DIR/.devcontainer/docker-compose.yml"
  assert_success
}

@test "writable: docker-in-docker feature in devcontainer.json" {
  run grep "docker-in-docker" "$WRITABLE_DIR/.devcontainer/devcontainer.json"
  assert_success
}
