#!/usr/bin/env bash
# test_helper.bash – Shared setup for all bats tests

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# Load bats helper libraries
load "${REPO_ROOT}/test/libs/bats-support/load"
load "${REPO_ROOT}/test/libs/bats-assert/load"

# Source the library modules under test
source "${REPO_ROOT}/lib/prompts.sh"
source "${REPO_ROOT}/lib/templates.sh"
