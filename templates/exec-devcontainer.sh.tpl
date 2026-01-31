#!/bin/bash
set -e

PROJECT_NAME="{{PROJECT_NAME}}"
GIT_MODE="{{GIT_MODE}}"

# 1. Install devcontainer CLI if missing
if ! command -v devcontainer &> /dev/null; then
    echo "Installing @devcontainers/cli..."
    npm install -g @devcontainers/cli
else
    echo "@devcontainers/cli already installed, skipping..."
fi

# 2. Initialize worktree (setup unique compose project name)
echo "Initializing worktree configuration..."
bash .devcontainer/init-worktree.sh

# 3. Setup X11 / Dummy Mounts
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Configuring X11 for Linux..."

    MISSING_HOST_TOOLS=()
    command -v socat &> /dev/null || MISSING_HOST_TOOLS+=("socat")
    command -v xhost &> /dev/null || MISSING_HOST_TOOLS+=("x11-xserver-utils")

    if [ ${#MISSING_HOST_TOOLS[@]} -gt 0 ]; then
        echo "Installing required host tools: ${MISSING_HOST_TOOLS[*]}..."
        sudo apt-get update -qq && sudo apt-get install -y -qq "${MISSING_HOST_TOOLS[@]}"
    fi

    xhost +local:root 2>/dev/null || true
    export X11_SOCKET_DIR="/tmp/.X11-unix"
    export XAUTHORITY_PATH="${XAUTHORITY:-$HOME/.Xauthority}"
    echo "Using XAUTHORITY at: $XAUTHORITY_PATH"
else
    echo "Non-Linux OS detected. Disabling X11 forwarding safely..."
    mkdir -p .devcontainer/.x11-dummy/socket
    touch .devcontainer/.x11-dummy/xauthority
    export X11_SOCKET_DIR="$(pwd)/.devcontainer/.x11-dummy/socket"
    export XAUTHORITY_PATH="$(pwd)/.devcontainer/.x11-dummy/xauthority"
fi

# 4. Build/Up
echo "Ensuring devcontainer is up-to-date and running..."
DEVCONTAINER_RESULT=$(devcontainer up --workspace-folder . 2>&1)
echo "$DEVCONTAINER_RESULT"

# Extract container ID from devcontainer up output
CONTAINER_ID=$(echo "$DEVCONTAINER_RESULT" | grep -o '"containerId":"[^"]*"' | cut -d'"' -f4)

# Wait for devcontainer metadata to be ready
echo "Waiting for devcontainer to be ready for exec..."
MAX_RETRIES=3
RETRY_COUNT=0
RETRY_DELAY=1
USE_DOCKER_EXEC=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    set +e
    devcontainer exec --workspace-folder . true 2>/dev/null
    EXEC_RESULT=$?
    set -e

    if [ $EXEC_RESULT -eq 0 ]; then
        echo "Devcontainer CLI is ready!"
        break
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
        echo "Container not ready yet, waiting ${RETRY_DELAY}s... (attempt $RETRY_COUNT/$MAX_RETRIES)"
        sleep $RETRY_DELAY
    else
        set +e
        HAS_INTELLIJ_LABEL=$(docker inspect "$CONTAINER_ID" 2>/dev/null | grep -c "com.intellij.devcontainer")
        set -e

        if [ "$HAS_INTELLIJ_LABEL" -gt 0 ]; then
            echo "Detected container started by IntelliJ. Using docker exec as fallback."
        else
            echo "WARNING: devcontainer exec not available. Using docker exec as fallback."
        fi
        USE_DOCKER_EXEC=true
    fi
done

# 5. Sync ~/.tmux.conf if present
if [ -f "$HOME/.tmux.conf" ]; then
    echo "Syncing ~/.tmux.conf to container..."
    if [ "$USE_DOCKER_EXEC" = true ]; then
        cat "$HOME/.tmux.conf" | docker exec -i "$CONTAINER_ID" bash -c 'cat > /home/vscode/.tmux.conf'
        docker exec "$CONTAINER_ID" bash -c '
            if command -v tmux &> /dev/null && tmux list-sessions &> /dev/null; then
                echo "Reloading tmux config in running sessions..."
                tmux source-file /home/vscode/.tmux.conf 2>/dev/null || true
            fi
        ' || true
    else
        cat "$HOME/.tmux.conf" | devcontainer exec --workspace-folder . bash -c 'cat > /home/vscode/.tmux.conf'
        devcontainer exec --workspace-folder . bash -c '
            if command -v tmux &> /dev/null && tmux list-sessions &> /dev/null; then
                echo "Reloading tmux config in running sessions..."
                tmux source-file /home/vscode/.tmux.conf 2>/dev/null || true
            fi
        ' || true
    fi
fi

# 6. Execute command
if [ $# -eq 0 ]; then
    set -- bash
fi

if [ "$USE_DOCKER_EXEC" = true ]; then
    DOCKER_ENV_ARGS=()

    # Check if X11 Unix socket is mounted in container
    X11_SOCKET_MOUNTED=$(docker exec "$CONTAINER_ID" test -d /tmp/.X11-unix && echo "yes" || echo "no")

    if [ "$X11_SOCKET_MOUNTED" = "yes" ] && [ -n "$DISPLAY" ]; then
        DOCKER_ENV_ARGS+=(-e "DISPLAY=$DISPLAY")
        [ -n "$XAUTHORITY_PATH" ] && DOCKER_ENV_ARGS+=(-e "XAUTHORITY=/home/vscode/.Xauthority")
    else
        # No Unix socket – use TCP via host IP
        echo "X11 Unix socket not mounted. Setting up TCP forwarding via socat..."

        xhost +local:docker 2>/dev/null || true
        xhost +SI:localuser:root 2>/dev/null || true
        xhost + 2>/dev/null || true

        DISPLAY_NUM="${DISPLAY#:}"
        DISPLAY_NUM="${DISPLAY_NUM%%.*}"
        : "${DISPLAY_NUM:=0}"

        X11_TCP_PORT=$((6010 + DISPLAY_NUM))
        X11_UNIX_SOCKET="/tmp/.X11-unix/X${DISPLAY_NUM}"

        if ! pgrep -f "socat.*TCP-LISTEN:${X11_TCP_PORT}" > /dev/null 2>&1; then
            if [ -S "$X11_UNIX_SOCKET" ]; then
                ACTUAL_X11_SOCKET="$X11_UNIX_SOCKET"
            elif [ -S "/tmp/.X11-unix/X0" ]; then
                ACTUAL_X11_SOCKET="/tmp/.X11-unix/X0"
                echo "Using fallback X11 socket: $ACTUAL_X11_SOCKET"
            else
                echo "Available X11 sockets:"
                ls -la /tmp/.X11-unix/ 2>/dev/null || echo "  (none found)"
                ACTUAL_X11_SOCKET=""
            fi

            if [ -n "$ACTUAL_X11_SOCKET" ]; then
                echo "Starting X11 TCP forward on port ${X11_TCP_PORT} -> ${ACTUAL_X11_SOCKET}..."
                socat TCP-LISTEN:${X11_TCP_PORT},fork,reuseaddr,bind=0.0.0.0 UNIX-CONNECT:${ACTUAL_X11_SOCKET} &
                SOCAT_PID=$!
                sleep 0.5

                if kill -0 $SOCAT_PID 2>/dev/null; then
                    echo "X11 TCP forward started successfully (PID: $SOCAT_PID)"
                else
                    echo "ERROR: socat failed to start."
                    socat TCP-LISTEN:${X11_TCP_PORT},fork,reuseaddr,bind=0.0.0.0 UNIX-CONNECT:${ACTUAL_X11_SOCKET} 2>&1 &
                    sleep 1
                fi
            else
                echo "WARNING: No X11 Unix socket found"
            fi
        else
            echo "X11 TCP forward already running on port ${X11_TCP_PORT}"
        fi

        HOST_IP=$(docker network inspect bridge --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null || echo "172.17.0.1")

        if docker exec "$CONTAINER_ID" getent hosts host.docker.internal > /dev/null 2>&1; then
            X11_HOST="host.docker.internal"
        else
            X11_HOST="$HOST_IP"
            echo "host.docker.internal not available, using IP: $HOST_IP"
        fi

        DOCKER_ENV_ARGS+=(-e "DISPLAY=${X11_HOST}:$((10 + DISPLAY_NUM))")
    fi

    # Ensure X11 tools in container
    echo "Ensuring required tools are installed in container..."
    docker exec -u root "$CONTAINER_ID" bash -c '
        MISSING_PKGS=()
        command -v xclip &> /dev/null || MISSING_PKGS+=("xclip")
        command -v xsel &> /dev/null || MISSING_PKGS+=("xsel")
        command -v xauth &> /dev/null || MISSING_PKGS+=("xauth")
        command -v nc &> /dev/null || MISSING_PKGS+=("netcat-openbsd")

        if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
            echo "Installing in container: ${MISSING_PKGS[*]}..."
            apt-get update -qq && apt-get install -y -qq "${MISSING_PKGS[@]}" 2>/dev/null
            echo "Container tools installed."
        fi
    ' || true

    if [ -t 0 ]; then
        exec docker exec -it "${DOCKER_ENV_ARGS[@]}" -u vscode -w "/workspaces/${PROJECT_NAME}" "$CONTAINER_ID" "$@"
    else
        exec docker exec -i "${DOCKER_ENV_ARGS[@]}" -u vscode -w "/workspaces/${PROJECT_NAME}" "$CONTAINER_ID" "$@"
    fi
else
    exec devcontainer exec --workspace-folder . "$@"
fi
