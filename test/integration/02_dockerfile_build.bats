#!/usr/bin/env bats
# 02_dockerfile_build.bats – Tier 2: Docker build for all base images

load integration_helper

setup_file() {
  export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export BUILD_TAG_PREFIX="devsetup-itest-build-$$"

  STDIN_TMPDIR="$(mktemp -d /tmp/devsetup-itest-stdin-XXXXXX)"
  export STDIN_TMPDIR

  # Scenario: Ubuntu Noble
  UBUNTU_DIR="$(create_test_project "build-ubuntu")"
  generate_stdin --git-mode=1 --base-image=1 --docker-mode=1 > "$STDIN_TMPDIR/ubuntu.txt"
  run_devsetup "$UBUNTU_DIR" "$STDIN_TMPDIR/ubuntu.txt"
  export UBUNTU_DIR
  export UBUNTU_TAG="${BUILD_TAG_PREFIX}-ubuntu"
  docker build -t "$UBUNTU_TAG" "$UBUNTU_DIR/.devcontainer" 2>&1

  # Scenario: Node.js 22
  NODE_DIR="$(create_test_project "build-node")"
  generate_stdin --git-mode=1 --base-image=2 --docker-mode=1 > "$STDIN_TMPDIR/node.txt"
  run_devsetup "$NODE_DIR" "$STDIN_TMPDIR/node.txt"
  export NODE_DIR
  export NODE_TAG="${BUILD_TAG_PREFIX}-node"
  docker build -t "$NODE_TAG" "$NODE_DIR/.devcontainer" 2>&1

  # Scenario: Python 3
  PYTHON_DIR="$(create_test_project "build-python")"
  generate_stdin --git-mode=1 --base-image=5 --docker-mode=1 > "$STDIN_TMPDIR/python.txt"
  run_devsetup "$PYTHON_DIR" "$STDIN_TMPDIR/python.txt"
  export PYTHON_DIR
  export PYTHON_TAG="${BUILD_TAG_PREFIX}-python"
  docker build -t "$PYTHON_TAG" "$PYTHON_DIR/.devcontainer" 2>&1
}

teardown_file() {
  docker rmi -f "$UBUNTU_TAG" "$NODE_TAG" "$PYTHON_TAG" 2>/dev/null || true
  rm -rf "$UBUNTU_DIR" "$NODE_DIR" "$PYTHON_DIR" "$STDIN_TMPDIR"
}

# ── Build success ──

@test "ubuntu: docker build succeeds" {
  run docker image inspect "$UBUNTU_TAG"
  assert_success
}

@test "node: docker build succeeds" {
  run docker image inspect "$NODE_TAG"
  assert_success
}

@test "python: docker build succeeds" {
  run docker image inspect "$PYTHON_TAG"
  assert_success
}

# ── Tool availability ──

@test "ubuntu: image has tmux, socat, curl, jq, git" {
  for tool in tmux socat curl jq git; do
    run docker run --rm "$UBUNTU_TAG" which "$tool"
    assert_success
  done
}

@test "node: image has node and npm" {
  run docker run --rm "$NODE_TAG" bash -lc "which node"
  assert_success
  run docker run --rm "$NODE_TAG" bash -lc "which npm"
  assert_success
}

@test "python: image has python3 and pip3" {
  run docker run --rm "$PYTHON_TAG" bash -lc "which python3"
  assert_success
  run docker run --rm "$PYTHON_TAG" bash -lc "which pip3"
  assert_success
}
