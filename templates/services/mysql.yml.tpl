  mysql:
    image: mysql:8
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: {{PROJECT_NAME}}
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - devnet