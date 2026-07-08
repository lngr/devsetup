#!/usr/bin/env bash
set -euo pipefail

# run_integration.sh – Runner for devsetup integration tests
# Usage: ./test/run_integration.sh [all|1|2|3]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INTEGRATION_DIR="$SCRIPT_DIR/integration"
BATS="$REPO_ROOT/test/libs/bats-core/bin/bats"

TIER="${1:-all}"
TIMEOUT=900  # 15 minutes per test file
EXIT_CODE=0

# ── Pre-flight checks ──

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not available" >&2
  exit 1
fi

if [ ! -x "$BATS" ]; then
  echo "ERROR: bats not found at $BATS" >&2
  echo "  Run: git submodule update --init --recursive" >&2
  exit 1
fi

# ── Tier definitions ──

TIER1_FILES=(
  "$INTEGRATION_DIR/01_generation.bats"
)

TIER2_FILES=(
  "$INTEGRATION_DIR/02_dockerfile_build.bats"
  "$INTEGRATION_DIR/06_user_mapping.bats"
)

TIER3_FILES=(
  "$INTEGRATION_DIR/03_compose_services.bats"
  "$INTEGRATION_DIR/04_dind_privileged.bats"
  "$INTEGRATION_DIR/05_postcreate.bats"
  "$INTEGRATION_DIR/07_rebuild.bats"
)

run_tier() {
  local tier_name="$1"
  shift
  local files=("$@")

  echo ""
  echo "════════════════════════════════════════════"
  echo "  Running ${tier_name}"
  echo "════════════════════════════════════════════"
  echo ""

  for f in "${files[@]}"; do
    if [ ! -f "$f" ]; then
      echo "WARN: Test file not found: $f" >&2
      continue
    fi
    local basename
    basename="$(basename "$f")"
    echo "── $basename ──"
    if timeout "$TIMEOUT" "$BATS" --tap "$f"; then
      echo "  PASS: $basename"
    else
      echo "  FAIL: $basename"
      EXIT_CODE=1
    fi
    echo ""
  done
}

# ── Run selected tiers ──

case "$TIER" in
  1)
    run_tier "Tier 1: Generation Tests" "${TIER1_FILES[@]}"
    ;;
  2)
    run_tier "Tier 2: Docker Build Tests" "${TIER2_FILES[@]}"
    ;;
  3)
    run_tier "Tier 3: Compose & Service Tests" "${TIER3_FILES[@]}"
    ;;
  all)
    run_tier "Tier 1: Generation Tests" "${TIER1_FILES[@]}"
    run_tier "Tier 2: Docker Build Tests" "${TIER2_FILES[@]}"
    run_tier "Tier 3: Compose & Service Tests" "${TIER3_FILES[@]}"
    ;;
  *)
    echo "Usage: $0 [all|1|2|3]"
    exit 1
    ;;
esac

# ── Global cleanup ──

echo ""
echo "── Cleaning up devsetup-itest-* resources ──"

# Remove containers
containers="$(docker ps -aq --filter "name=devsetup-itest" 2>/dev/null || true)"
if [ -n "$containers" ]; then
  echo "$containers" | xargs docker rm -f 2>/dev/null || true
fi

# Remove networks
networks="$(docker network ls -q --filter "name=devsetup-itest" 2>/dev/null || true)"
if [ -n "$networks" ]; then
  echo "$networks" | xargs docker network rm 2>/dev/null || true
fi

# Remove volumes
volumes="$(docker volume ls -q --filter "name=devsetup-itest" 2>/dev/null || true)"
if [ -n "$volumes" ]; then
  echo "$volumes" | xargs docker volume rm 2>/dev/null || true
fi

# Remove temp directories
rm -rf /tmp/devsetup-itest-* 2>/dev/null || true

echo ""
if [ "$EXIT_CODE" -eq 0 ]; then
  echo "All integration tests PASSED."
else
  echo "Some integration tests FAILED."
fi

exit "$EXIT_CODE"
