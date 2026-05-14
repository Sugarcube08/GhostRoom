# Veil — Privacy-First Ephemeral Communication

Veil is a production-grade MVP for an anonymous, ephemeral, encrypted communication platform.

## Core Philosophy
- **No Identity:** No accounts, phone numbers, or emails.
- **End-to-End Encrypted:** The server never sees plaintext payloads.
- **Disposable Infrastructure:** Users can host and switch between temporary relays at runtime.
- **Ephemeral:** Rooms and messages vanish completely after their TTL expires.

## Architecture

### Backend (NestJS + Redis)
- **Stateless Relay:** Acts only as a router for encrypted packets.
- **Aggressive TTL:** Uses Redis TTL for automatic cleanup of rooms, sessions, and messages.
- **Keyspace Notifications:** Triggers WebSocket events for room destruction.
- **Dockerized:** Ready for disposable VPS or LAN deployment.

### Client (Flutter + libsodium)
- **Local Crypto:** Generates X25519/Ed25519 identities on first launch.
- **Symmetric Encryption:** All messages are encrypted locally using the room key.
- **Relay Manager:** Supports multiple saved relay profiles (BYOR).
- **Hardened Privacy:** OS-level screenshot/recording protection and app-switcher blurring.

## Running the Project

### 1. Start the Relay (Backend)
```bash
docker-compose up --build
```
The relay will be available at `http://localhost:3000` (API) and `ws://localhost:3000` (WebSocket).

### 2. Run the Flutter Client
```bash
cd client
flutter pub get
flutter run
```

## Security Implementation
- **Encryption:** `sodium.crypto.secretBox` (XChaCha20-Poly1305).
- **Identity:** Stored in `flutter_secure_storage`.
- **Relay Trust:** The relay is zero-knowledge; it only routes opaque ciphertext blobs.
- **Panic Wipe:** Settings -> Panic Wipe to erase all local traces.
