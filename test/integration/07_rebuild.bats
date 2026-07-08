#!/usr/bin/env bats
# 07_rebuild.bats – Tier: remove_dev_container_and_image teardown for --rebuild

load integration_helper

setup_file() {
  export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  export RB_PROJECT="devsetup-itest-rebuild-$$"
  export RB_IMAGE="${RB_PROJECT}-img"
  export RB_CONTAINER="${RB_PROJECT}-dev"
  export RB_VOLUME="${RB_PROJECT}-data"

  # Locally built throwaway image standing in for the built dev image.
  local build_dir
  build_dir="$(mktemp -d)"
  printf 'FROM busybox\n' > "$build_dir/Dockerfile"
  docker build -t "$RB_IMAGE" "$build_dir" >/dev/null 2>&1
  rm -rf "$build_dir"

  docker volume create "$RB_VOLUME" >/dev/null 2>&1

  # Container carrying the compose labels the teardown filters on, plus a
  # data volume that must survive.
  docker run -d --name "$RB_CONTAINER" \
    --label "com.docker.compose.project=${RB_PROJECT}" \
    --label "com.docker.compose.service=dev" \
    -v "${RB_VOLUME}:/data" \
    "$RB_IMAGE" sleep 3600 >/dev/null 2>&1

  # Run the real teardown helper.
  source "$REPO_ROOT/lib/rebuild.sh"
  remove_dev_container_and_image "$RB_PROJECT" "dev"
}

teardown_file() {
  docker rm -f "$RB_CONTAINER" >/dev/null 2>&1 || true
  docker rmi -f "$RB_IMAGE" >/dev/null 2>&1 || true
  docker volume rm -f "$RB_VOLUME" >/dev/null 2>&1 || true
}

@test "rebuild: dev container is removed" {
  run docker ps -aq --filter "name=^/${RB_CONTAINER}$"
  assert_success
  assert_output ""
}

@test "rebuild: built dev image is removed" {
  run docker image inspect "$RB_IMAGE"
  assert_failure
}

@test "rebuild: named data volume is preserved" {
  run docker volume inspect "$RB_VOLUME"
  assert_success
}
