name: ${COMPOSE_PROJECT_NAME:-devcontainer-{{PROJECT_NAME}}}

services:
  dev:
    build:
      context: .
      dockerfile: Dockerfile
    init: true
{{DOCKER_COMPOSE_EXTRAS}}    volumes:
      - ..:/workspaces/{{PROJECT_NAME}}
{{GIT_VOLUME}}
      - ~/.gitconfig:/home/vscode/.gitconfig:cached
    command: sleep infinity
    env_file:
      - path: ../.env
        required: false
      - path: ../.env.local
        required: false
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - devnet

networks:
  devnet:
    driver: bridge
