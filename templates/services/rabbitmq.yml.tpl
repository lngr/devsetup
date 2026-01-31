  rabbitmq:
    image: rabbitmq:3-management-alpine
    restart: unless-stopped
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
    expose:
      - "5672"
      - "15672"
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    networks:
      - devnet