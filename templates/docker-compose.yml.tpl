name: ${COMPOSE_PROJECT_NAME:-devcontainer-{{PROJECT_NAME}}}

services:
  dev:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        HOST_USER: ${HOST_USER:-vscode}
        HOST_UID: ${HOST_UID:-1000}
        HOST_GID: ${HOST_GID:-1000}
        HOST_HOME: ${HOST_HOME:-/home/vscode}
    init: true
{{DOCKER_COMPOSE_EXTRAS}}    volumes:
{{WORKSPACE_VOLUME}}
{{GIT_VOLUME}}
      - ~/.gitconfig:${HOST_HOME:-/home/vscode}/.gitconfig:cached
    command: sleep infinity
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - devnet

networks:
  devnet:
    driver: bridge
