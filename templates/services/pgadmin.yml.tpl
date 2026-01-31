  pgadmin:
    image: dpage/pgadmin4:8
    restart: unless-stopped
    depends_on:
      - postgres
    environment:
      PGADMIN_DEFAULT_EMAIL: ${PGADMIN_DEFAULT_EMAIL:-devcontainer@local.dev}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_DEFAULT_PASSWORD:-dev}
      PGADMIN_LISTEN_PORT: 5050
    expose:
      - "5050"
    volumes:
      - pgadmin_data:/var/lib/pgadmin
    networks:
      - devnet