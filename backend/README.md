# GhostRoom Relay (Backend)

The high-performance, stateless relay server for the GhostRoom communication platform.

## Architecture

The relay is built with **NestJS** and **Redis** to act as a zero-knowledge router for encrypted communication.

- **Stateless Design:** The relay does not store message history or user identities in a persistent database.
- **Aggressive TTL:** Every room and message has a Time-To-Live (TTL). Redis automatically handles the destruction of data when it expires.
- **Keyspace Notifications:** The relay listens for Redis expiration events to broadcast `space.expired` events to connected clients.
- **Zero-Knowledge:** The relay only sees opaque ciphertext blobs. It has no access to the decryption keys or the plaintext contents of messages.

## Features

- **WebSockets:** Real-time message routing via `socket.io`.
- **REST API:** Minimal endpoints for temporary room creation.
- **Docker Ready:** Optimized for quick deployment on disposable VPS or local infrastructure.

## Configuration

The relay can be configured via environment variables:

- `REDIS_HOST`: The hostname of your Redis instance.
- `REDIS_PORT`: The port of your Redis instance (default: 6379).

## Running with Docker

The easiest way to run the relay is using the root-level `docker-compose.yml`:

```bash
docker-compose up --build
```

## Manual Installation

1.  `cd backend`
2.  `npm install`
3.  Ensure Redis is running locally.
4.  `npm run start:dev`

## License

This project is licensed under a **Custom License** (Personal and Educational Use Only) - see the [LICENSE](../LICENSE) file in the root directory for details.
