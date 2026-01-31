name: ${COMPOSE_PROJECT_NAME:-devcontainer-{{PROJECT_NAME}}}

{{SERVICES_BLOCK}}

networks:
  devnet:
    driver: bridge

{{VOLUMES_BLOCK}}
