name: ${COMPOSE_PROJECT_NAME:-devcontainer-{{PROJECT_NAME}}}

services:
  dev:
    build:
      context: .
      dockerfile: Dockerfile
    init: true
    volumes:
      - ..:/workspaces/{{PROJECT_NAME}}
{{GIT_VOLUME}}
      - ~/.gitconfig:/home/vscode/.gitconfig:cached
      - type: bind
        source: ${X11_SOCKET_DIR:-/tmp}
        target: /tmp/.X11-unix
        read_only: false
      - type: bind
        source: ${XAUTHORITY_PATH:-/dev/null}
        target: /home/vscode/.Xauthority
        read_only: true
    command: sleep infinity
    env_file:
      - path: ../.env
        required: false
      - path: ../.env.local
        required: false
    environment:
      - DISPLAY=${DISPLAY}
      - XAUTHORITY=/home/vscode/.Xauthority
      - QT_X11_NO_MITSHM=1
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - devnet

networks:
  devnet:
    driver: bridge
