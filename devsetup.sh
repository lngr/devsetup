#!/usr/bin/env bash
set -euo pipefail

# devsetup – Dev Container Bootstrapping Tool
# Scaffolds a complete .devcontainer setup in any project directory.

DEVSETUP_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# shellcheck source=lib/prompts.sh
source "$DEVSETUP_DIR/lib/prompts.sh"
# shellcheck source=lib/templates.sh
source "$DEVSETUP_DIR/lib/templates.sh"

# --- Self-install ---
if [ "${1:-}" = "--install" ]; then
  mkdir -p ~/.local/bin
  ln -sf "$DEVSETUP_DIR/devsetup.sh" ~/.local/bin/devsetup
  echo "devsetup installed → ~/.local/bin/devsetup"
  exit 0
fi

# --- Parse arguments ---
TARGET_DIR="$PWD"
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET_DIR="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: devsetup [--target <dir>] [--install]"
      echo "  Scaffolds a .devcontainer setup in the target directory."
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# ============================================================
# Interactive Prompt Flow
# ============================================================

prompt_header "devsetup – Dev Container Setup"
echo "Target directory: $TARGET_DIR"

# 1. Check for existing .devcontainer
if [ -d "$TARGET_DIR/.devcontainer" ]; then
  if ! prompt_confirm "Directory .devcontainer/ already exists. Overwrite?"; then
    echo "Aborted."
    exit 0
  fi
fi

# 1b. Warn if target directory is not empty
if [ -n "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
  echo "Warning: Target directory is not empty."
  if ! prompt_confirm "Add devcontainer setup to this existing project?"; then
    echo "Aborted."
    exit 0
  fi
fi

# 2. Project name
BASENAME="$(basename "$TARGET_DIR")"
DEFAULT_PROJECT="$(sanitize_name "$BASENAME")"
prompt_input "Project name" "$DEFAULT_PROJECT"
PROJECT_NAME="$(sanitize_name "$REPLY")"

# 3. Git mode
prompt_header "Git Mode"
prompt_select "How should .git be mounted?" \
  "Read-only  (Worktrees managed on host, per-worktree containers)" \
  "Writable   (Full git access in container, single container)"
case "$REPLY" in
  Read-only*) GIT_MODE="readonly" ;;
  *)          GIT_MODE="writable" ;;
esac

# 4. Base image
prompt_header "Base Image"
prompt_select "Select base image:" \
  "Ubuntu Noble (generic)" \
  "Node.js 22" \
  ".NET 8" \
  ".NET 9" \
  "Python 3" \
  "Go" \
  "Custom"

BASE_IMAGE=""
EXTRA_PACKAGES=""
case "$REPLY" in
  "Ubuntu Noble"*)
    BASE_IMAGE="mcr.microsoft.com/devcontainers/base:noble"
    ;;
  "Node.js"*)
    BASE_IMAGE="mcr.microsoft.com/devcontainers/javascript-node:22"
    EXTRA_PACKAGES="nodejs npm"
    ;;
  ".NET 8"*)
    BASE_IMAGE="mcr.microsoft.com/devcontainers/dotnet:8.0-noble"
    ;;
  ".NET 9"*)
    BASE_IMAGE="mcr.microsoft.com/devcontainers/dotnet:9.0-noble"
    ;;
  "Python"*)
    BASE_IMAGE="mcr.microsoft.com/devcontainers/python:3"
    EXTRA_PACKAGES="python3-pip python3-venv"
    ;;
  "Go"*)
    BASE_IMAGE="mcr.microsoft.com/devcontainers/go:latest"
    ;;
  "Custom"*)
    prompt_input "Enter custom image URL" ""
    BASE_IMAGE="$REPLY"
    ;;
esac

# 5. Services
prompt_header "Services"
SERVICE_OPTIONS=(
  "PostgreSQL + PgAdmin"
  "Redis"
  "RabbitMQ"
  "MySQL + phpMyAdmin"
  "MinIO (S3)"
  "MongoDB"
)
prompt_multiselect "Select optional services:" "${SERVICE_OPTIONS[@]}"
SELECTED_SERVICES=("${SELECTED_INDICES[@]}")

# PostgreSQL DB names
POSTGRES_DBS=""
HAS_POSTGRES=false
for idx in "${SELECTED_SERVICES[@]}"; do
  if [ "$idx" -eq 0 ]; then
    HAS_POSTGRES=true
    prompt_input "PostgreSQL database names (comma-separated)" "$PROJECT_NAME"
    POSTGRES_DBS="$REPLY"
  fi
done

# 6. Timezone
prompt_header "Timezone"
prompt_input "Timezone" "Europe/Berlin"
TIMEZONE="$REPLY"

# 7. Docker-in-Docker
prompt_header "Docker-in-Docker"
prompt_select "Docker-Zugriff im Container?" \
  "Kein Docker" \
  "Docker-in-Docker (privileged)    – Eigener Docker-Daemon, braucht privileged mode" \
  "Docker-in-Docker (Sysbox)        – Eigener Docker-Daemon, braucht Sysbox auf dem Host"
case "$REPLY" in
  "Kein"*)     DOCKER_MODE="none" ;;
  *"privileged"*) DOCKER_MODE="privileged" ;;
  *"Sysbox"*)  DOCKER_MODE="sysbox" ;;
esac

# ============================================================
# Summary & Confirmation
# ============================================================

prompt_header "Summary"
echo "  Project:    $PROJECT_NAME"
echo "  Target:     $TARGET_DIR"
echo "  Git mode:   $GIT_MODE"
echo "  Base image: $BASE_IMAGE"
echo "  Timezone:   $TIMEZONE"
echo "  Docker:     $DOCKER_MODE"

printf '  Services:   '
if [ ${#SELECTED_SERVICES[@]} -eq 0 ]; then
  echo "(none)"
else
  for idx in "${SELECTED_SERVICES[@]}"; do
    printf '%s  ' "${SERVICE_OPTIONS[$idx]}"
  done
  echo
fi

if [ "$HAS_POSTGRES" = true ]; then
  echo "  Postgres DBs: $POSTGRES_DBS"
fi

echo
if ! prompt_confirm "Generate devcontainer setup?"; then
  echo "Aborted."
  exit 0
fi

# ============================================================
# Generation
# ============================================================

OUTDIR="$TARGET_DIR/.devcontainer"
mkdir -p "$OUTDIR/scripts"

TPL="$DEVSETUP_DIR/templates"

# --- Docker-in-Docker settings ---
DOCKER_FEATURE=""
DOCKER_COMPOSE_EXTRAS=""
if [ "$DOCKER_MODE" != "none" ]; then
  DOCKER_FEATURE=',
    "ghcr.io/devcontainers/features/docker-in-docker:2": { "dockerDashComposeVersion": "v2" }'
fi
if [ "$DOCKER_MODE" = "privileged" ]; then
  DOCKER_COMPOSE_EXTRAS='    privileged: true
    cgroupns: private
'
elif [ "$DOCKER_MODE" = "sysbox" ]; then
  DOCKER_COMPOSE_EXTRAS='    runtime: sysbox-runc
'
fi

# --- Git volume line ---
if [ "$GIT_MODE" = "readonly" ]; then
  GIT_VOLUME="      - ../.git:/workspaces/${PROJECT_NAME}/.git:ro"
else
  GIT_VOLUME="      # .git mounted rw via parent volume"
fi

# --- Dockerfile ---
{
  echo "FROM $BASE_IMAGE"
  echo ""
  echo "# Install base packages for dev container"
  echo "RUN apt-get update && \\"
  echo "    export DEBIAN_FRONTEND=noninteractive && \\"
  printf '    apt-get install -y \\\n'
  for pkg in tmux screen socat telnet netcat-openbsd xauth xclip xsel xdg-utils tzdata curl git jq $EXTRA_PACKAGES; do
    printf '        %s \\\n' "$pkg"
  done
  echo "    && apt-get clean \\"
  echo "    && rm -rf /var/lib/apt/lists/*"
} > "$OUTDIR/Dockerfile"

# --- docker-compose.yml ---
render_template "$TPL/docker-compose.yml.tpl" "$OUTDIR/docker-compose.yml" \
  "PROJECT_NAME=$PROJECT_NAME" \
  "GIT_VOLUME=$GIT_VOLUME" \
  "DOCKER_COMPOSE_EXTRAS=$DOCKER_COMPOSE_EXTRAS"

# --- Services ---
COMPOSE_FILES='"docker-compose.yml"'
RUN_SERVICES='["dev"]'
SERVICE_NAMES=("dev")

if [ ${#SELECTED_SERVICES[@]} -gt 0 ]; then
  # Build services compose file
  SERVICES_BLOCK=""
  VOLUMES_BLOCK="volumes:"
  RENDERED_FRAGMENTS=()

  for idx in "${SELECTED_SERVICES[@]}"; do
    case "$idx" in
      0) # PostgreSQL + PgAdmin
        POSTGRES_DEFAULT_DB="${POSTGRES_DBS%%,*}"
        frag_pg="$(render_template_stdout "$TPL/services/postgres.yml.tpl" "POSTGRES_DEFAULT_DB=$POSTGRES_DEFAULT_DB")"
        frag_pga="$(render_template_stdout "$TPL/services/pgadmin.yml.tpl")"
        SERVICES_BLOCK="${SERVICES_BLOCK}${frag_pg}"$'\n'"${frag_pga}"$'\n'
        VOLUMES_BLOCK="${VOLUMES_BLOCK}"$'\n'"  postgres_data:"$'\n'"  pgadmin_data:"
        SERVICE_NAMES+=("postgres" "pgadmin")
        ;;
      1) # Redis
        frag="$(render_template_stdout "$TPL/services/redis.yml.tpl")"
        SERVICES_BLOCK="${SERVICES_BLOCK}${frag}"$'\n'
        VOLUMES_BLOCK="${VOLUMES_BLOCK}"$'\n'"  redis_data:"
        SERVICE_NAMES+=("redis")
        ;;
      2) # RabbitMQ
        frag="$(render_template_stdout "$TPL/services/rabbitmq.yml.tpl")"
        SERVICES_BLOCK="${SERVICES_BLOCK}${frag}"$'\n'
        VOLUMES_BLOCK="${VOLUMES_BLOCK}"$'\n'"  rabbitmq_data:"
        SERVICE_NAMES+=("rabbitmq")
        ;;
      3) # MySQL + phpMyAdmin
        frag_my="$(render_template_stdout "$TPL/services/mysql.yml.tpl" "PROJECT_NAME=$PROJECT_NAME")"
        frag_pma="$(render_template_stdout "$TPL/services/phpmyadmin.yml.tpl")"
        SERVICES_BLOCK="${SERVICES_BLOCK}${frag_my}"$'\n'"${frag_pma}"$'\n'
        VOLUMES_BLOCK="${VOLUMES_BLOCK}"$'\n'"  mysql_data:"
        SERVICE_NAMES+=("mysql" "phpmyadmin")
        ;;
      4) # MinIO
        frag="$(render_template_stdout "$TPL/services/minio.yml.tpl")"
        SERVICES_BLOCK="${SERVICES_BLOCK}${frag}"$'\n'
        VOLUMES_BLOCK="${VOLUMES_BLOCK}"$'\n'"  minio_data:"
        SERVICE_NAMES+=("minio")
        ;;
      5) # MongoDB
        frag="$(render_template_stdout "$TPL/services/mongodb.yml.tpl")"
        SERVICES_BLOCK="${SERVICES_BLOCK}${frag}"$'\n'
        VOLUMES_BLOCK="${VOLUMES_BLOCK}"$'\n'"  mongodb_data:"
        SERVICE_NAMES+=("mongodb")
        ;;
    esac
  done

  # Write services compose file directly (multi-line content)
  {
    printf 'name: ${COMPOSE_PROJECT_NAME:-devcontainer-%s}\n\n' "$PROJECT_NAME"
    printf 'services:\n'
    printf '%s\n' "$SERVICES_BLOCK"
    printf '\nnetworks:\n  devnet:\n    driver: bridge\n'
    printf '\n%s\n' "$VOLUMES_BLOCK"
  } > "$OUTDIR/docker-compose.services.yml"

  COMPOSE_FILES='["docker-compose.yml", "docker-compose.services.yml"]'

  # Build run services JSON array
  RUN_SERVICES='['
  for i in "${!SERVICE_NAMES[@]}"; do
    [ "$i" -gt 0 ] && RUN_SERVICES+=', '
    RUN_SERVICES+="\"${SERVICE_NAMES[$i]}\""
  done
  RUN_SERVICES+=']'
fi

# --- Postgres init script ---
if [ "$HAS_POSTGRES" = true ]; then
  mkdir -p "$OUTDIR/postgres-init"
  {
    echo '#!/usr/bin/env bash'
    echo 'set -euo pipefail'
    echo ''
    echo 'if [ -z "${POSTGRES_USER:-}" ]; then'
    echo '  echo "POSTGRES_USER is not set" >&2'
    echo '  exit 1'
    echo 'fi'
    echo ''
    echo 'db_exists() {'
    echo '  local db="$1"'
    echo '  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='"'"'${db}'"'"'" | grep -q 1'
    echo '}'
    echo ''
    echo 'create_db() {'
    echo '  local db="$1"'
    echo '  if db_exists "$db"; then'
    echo '    echo "Database '"'"'$db'"'"' already exists"'
    echo '    return 0'
    echo '  fi'
    echo '  echo "Creating database '"'"'$db'"'"'..."'
    echo '  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE \"${db}\";"'
    echo '}'
    echo ''
    # Split comma-separated DB names
    IFS=',' read -ra DB_ARRAY <<< "$POSTGRES_DBS"
    for db in "${DB_ARRAY[@]}"; do
      db="$(echo "$db" | xargs)"  # trim whitespace
      echo "create_db \"$db\""
    done
  } > "$OUTDIR/postgres-init/01-create-databases.sh"
  chmod +x "$OUTDIR/postgres-init/01-create-databases.sh"
fi

# --- Port forwards for postStartCommand ---
PORT_FORWARDS=""
for idx in "${SELECTED_SERVICES[@]}"; do
  case "$idx" in
    0) PORT_FORWARDS="${PORT_FORWARDS}start_forward \"postgres-local\" \"127.0.0.1\" \"5432\" \"postgres\" \"5432\""$'\n' ;;
    1) PORT_FORWARDS="${PORT_FORWARDS}start_forward \"redis-local\" \"127.0.0.1\" \"6379\" \"redis\" \"6379\""$'\n' ;;
    2) PORT_FORWARDS="${PORT_FORWARDS}start_forward \"rabbitmq-local\" \"127.0.0.1\" \"5672\" \"rabbitmq\" \"5672\""$'\n' ;;
    3) PORT_FORWARDS="${PORT_FORWARDS}start_forward \"mysql-local\" \"127.0.0.1\" \"3306\" \"mysql\" \"3306\""$'\n' ;;
    5) PORT_FORWARDS="${PORT_FORWARDS}start_forward \"mongodb-local\" \"127.0.0.1\" \"27017\" \"mongodb\" \"27017\""$'\n' ;;
  esac
done
PORT_FORWARDS="${PORT_FORWARDS:-# No service port forwards configured}"

# --- devcontainer.json ---
render_template "$TPL/devcontainer.json.tpl" "$OUTDIR/devcontainer.json" \
  "PROJECT_NAME=$PROJECT_NAME" \
  "COMPOSE_FILES=$COMPOSE_FILES" \
  "RUN_SERVICES=$RUN_SERVICES" \
  "TIMEZONE=$TIMEZONE" \
  "DOCKER_FEATURE=$DOCKER_FEATURE"

# --- init-worktree.sh ---
render_template "$TPL/init-worktree.sh.tpl" "$OUTDIR/init-worktree.sh" \
  "PROJECT_NAME=$PROJECT_NAME"
chmod +x "$OUTDIR/init-worktree.sh"

# --- postCreateCommand.sh ---
render_template "$TPL/postCreateCommand.sh.tpl" "$OUTDIR/postCreateCommand.sh" \
  "TIMEZONE=$TIMEZONE"
chmod +x "$OUTDIR/postCreateCommand.sh"

# --- postStartCommand.sh ---
cp "$TPL/postStartCommand.sh.tpl" "$OUTDIR/postStartCommand.sh"
# Replace marker with actual port forward lines
{
  sed '/# PORT_FORWARDS_MARKER/,$d' "$OUTDIR/postStartCommand.sh"
  printf '%s' "$PORT_FORWARDS"
} > "$OUTDIR/postStartCommand.sh.tmp"
mv "$OUTDIR/postStartCommand.sh.tmp" "$OUTDIR/postStartCommand.sh"
chmod +x "$OUTDIR/postStartCommand.sh"

# --- Agent scripts ---
render_template "$TPL/scripts/install-agents.sh.tpl" "$OUTDIR/scripts/install-agents.sh"
chmod +x "$OUTDIR/scripts/install-agents.sh"

render_template "$TPL/scripts/update-agents.sh.tpl" "$OUTDIR/scripts/update-agents.sh"
chmod +x "$OUTDIR/scripts/update-agents.sh"

# --- exec-devcontainer.sh (in project root) ---
render_template "$TPL/exec-devcontainer.sh.tpl" "$TARGET_DIR/exec-devcontainer.sh" \
  "PROJECT_NAME=$PROJECT_NAME" \
  "GIT_MODE=$GIT_MODE"
chmod +x "$TARGET_DIR/exec-devcontainer.sh"

# --- .env (initial) ---
cat > "$OUTDIR/.env" <<EOF
COMPOSE_PROJECT_NAME=devcontainer-${PROJECT_NAME}
EOF

# --- devsetup.conf (persist config for re-generation) ---
cat > "$OUTDIR/devsetup.conf" <<EOF
# Generated by devsetup – do not edit manually
PROJECT_NAME=${PROJECT_NAME}
GIT_MODE=${GIT_MODE}
BASE_IMAGE=${BASE_IMAGE}
EXTRA_PACKAGES=${EXTRA_PACKAGES}
TIMEZONE=${TIMEZONE}
SELECTED_SERVICES=${SELECTED_SERVICES[*]:-}
POSTGRES_DBS=${POSTGRES_DBS}
DOCKER_MODE=${DOCKER_MODE}
EOF

echo
echo "============================================"
echo "  devcontainer setup generated successfully!"
echo "============================================"
echo
echo "  Directory: $OUTDIR"
echo
echo "  To start:  cd $TARGET_DIR && ./exec-devcontainer.sh"
echo
