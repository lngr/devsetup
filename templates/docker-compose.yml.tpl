name: ${COMPOSE_PROJECT_NAME:-devcontainer-{{PROJECT_NAME}}}

services:
  dev:
    build:
      context: .
      dockerfile: Dockerfile
    init: true
{{DOCKER_COMPOSE_EXTRAS}}    volumes:
{{WORKSPACE_VOLUME}}
{{GIT_VOLUME}}
      - ~/.gitconfig:/home/vscode/.gitconfig:cached
    command: sleep infinity
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - devnet

networks:
  devnet:
    driver: bridge
