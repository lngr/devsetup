  minio:
    image: minio/minio:latest
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    expose:
      - "9000"
      - "9001"
    volumes:
      - minio_data:/data
    networks:
      - devnet