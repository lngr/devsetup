#!/usr/bin/env bash
# rebuild.sh – Teardown helper for exec-devcontainer's --rebuild flag.

# Stop and remove the dev service container and its locally built image for a
# compose project, forcing a fresh build on the next start. Named data volumes
# and other service containers (databases, caches) are kept.
# Usage: remove_dev_container_and_image <compose_project_name> <service_name>
remove_dev_container_and_image() {
  local project="$1" service="$2"
  [ -n "$project" ] || return 0
  : "${service:=dev}"

  local containers
  containers="$(docker ps -aq \
    --filter "label=com.docker.compose.project=${project}" \
    --filter "label=com.docker.compose.service=${service}" 2>/dev/null || true)"

  local images=""
  if [ -n "$containers" ]; then
    # shellcheck disable=SC2086
    images="$(docker inspect -f '{{.Image}}' $containers 2>/dev/null | sort -u || true)"
    # shellcheck disable=SC2086
    docker rm -f $containers >/dev/null 2>&1 || true
  fi

  if [ -n "$images" ]; then
    # shellcheck disable=SC2086
    docker rmi -f $images >/dev/null 2>&1 || true
  fi

  # Also drop the image under its compose default name, in case the container
  # was already gone but a stale image lingered.
  docker rmi -f "${project}-${service}" >/dev/null 2>&1 || true
}
