#!/usr/bin/env bats
# 03_compose_services.bats – Tier 3: Service connectivity via docker compose

load integration_helper

setup_file() {
  export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  # Generate all-services scenario
  SVC_DIR="$(create_test_project "services")"
  STDIN_TMPDIR="$(mktemp -d /tmp/devsetup-itest-stdin-XXXXXX)"
  export STDIN_TMPDIR
  generate_stdin --git-mode=1 --base-image=1 \
    --services="1,2,3,4,5,6" --postgres-dbs="testdb" \
    --docker-mode=1 > "$STDIN_TMPDIR/services.txt"
  run_devsetup "$SVC_DIR" "$STDIN_TMPDIR/services.txt"

  # Create override to neutralize host-specific volumes
  create_test_compose_override "$SVC_DIR"

  # Build and start
  compose_up "$SVC_DIR"

  # Wait for key services to be running (longer timeouts for slow pulls)
  local compose_dir="$SVC_DIR/.devcontainer"
  wait_for_service "$compose_dir" "dev" 120
  wait_for_service "$compose_dir" "postgres" 120
  wait_for_service "$compose_dir" "redis" 120
  wait_for_service "$compose_dir" "rabbitmq" 120
  wait_for_service "$compose_dir" "mysql" 120
  wait_for_service "$compose_dir" "minio" 120
  wait_for_service "$compose_dir" "mongodb" 120

  export SVC_DIR
}

teardown_file() {
  cleanup_compose "$SVC_DIR"
  rm -rf "$SVC_DIR" "$STDIN_TMPDIR"
}

# Helper to get the network name from the compose project
_get_network() {
  local project_name
  project_name="$(grep '^COMPOSE_PROJECT_NAME=' "$SVC_DIR/.devcontainer/.env" | cut -d= -f2)"
  echo "${project_name}_devnet"
}

@test "services: dev container is running" {
  local compose_dir="$SVC_DIR/.devcontainer"
  _compose_file_args "$compose_dir"
  run bash -c "cd '$compose_dir' && docker compose ${COMPOSE_FILE_ARGS[*]} ps --format '{{.State}}' dev"
  assert_success
  assert_output "running"
}

@test "services: PostgreSQL accepts connections" {
  local network
  network="$(_get_network)"
  run retry 5 3 docker run --rm --network "$network" \
    postgres:16-alpine pg_isready -h postgres -p 5432 -U postgres
  assert_success
}

@test "services: PostgreSQL SELECT 1 query succeeds" {
  local network
  network="$(_get_network)"
  run retry 3 3 docker run --rm --network "$network" \
    -e PGPASSWORD=postgres \
    postgres:16-alpine psql -h postgres -U postgres -d postgres -c "SELECT 1"
  assert_success
}

@test "services: Redis responds to PING" {
  local network
  network="$(_get_network)"
  run retry 3 3 docker run --rm --network "$network" \
    redis:7-alpine redis-cli -h redis ping
  assert_success
  assert_output --partial "PONG"
}

@test "services: RabbitMQ TCP port 5672 is open" {
  local network
  network="$(_get_network)"
  run retry 5 5 check_tcp "$network" "rabbitmq" "5672" 10
  assert_success
}

@test "services: MySQL accepts connections" {
  local network
  network="$(_get_network)"
  run retry 5 5 docker run --rm --network "$network" \
    mysql:8 mysqladmin ping -h mysql -u root --password=root --silent
  assert_success
}

@test "services: MinIO health endpoint responds" {
  local network
  network="$(_get_network)"
  run retry 5 3 docker run --rm --network "$network" \
    alpine:3.20 sh -c "wget -q -O- http://minio:9000/minio/health/live"
  assert_success
}

@test "services: MongoDB responds to ping" {
  local network
  network="$(_get_network)"
  run retry 5 3 docker run --rm --network "$network" \
    mongo:7 mongosh --host mongodb --eval "db.runCommand({ping:1})" --quiet
  assert_success
}
