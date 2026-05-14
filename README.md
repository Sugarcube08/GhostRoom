# GhostRoom — Privacy-First Ephemeral Communication

GhostRoom is a production-grade communication platform designed for absolute anonymity and ephemerality. It allows users to create and join temporary, end-to-end encrypted rooms hosted on disposable relays.

## Core Philosophy
- **Zero Identity:** No accounts, phone numbers, or metadata collection.
- **End-to-End Encrypted (E2EE):** Plaintext never leaves the device.
- **Disposable Infrastructure:** Users can host and switch between temporary relays at runtime.
- **Ephemeral State:** All data (rooms, messages, local traces) vanishes completely after its TTL expires or the app session ends.

## System Architecture

### 1. Backend: Stateless Relay (NestJS + Redis)
The backend acts as a high-speed, zero-knowledge router for encrypted packets.
- **Aggressive TTL:** Leverages Redis `EXPIRE` for automatic, server-side cleanup of rooms and messages.
- **Keyspace Notifications:** Real-time WebSocket alerts (`space.expired`) triggered by Redis when a room's TTL ends.
- **Statelessness:** No persistent database; if the relay is wiped, all communication is lost—by design.

### 2. Client: Hardened Interface (Flutter + libsodium)
The Flutter application handles all cryptographic operations and UI-level privacy.
- **Local Crypto:** Uses `libsodium` (`sodium.crypto.secretBox`) for XChaCha20-Poly1305 encryption.
- **Secure Storage:** Identities and relay profiles are stored in encrypted system partitions via `flutter_secure_storage`.
- **Session Privacy:**
    - **Ephemeral Recent Spaces:** Joined rooms are persisted only for the duration of the app's lifecycle. They are wiped on a cold start to prevent discovery of past activity.
    - **Privacy Overlay:** Automatic blurring/masking of app content in the system task switcher.
    - **Multi-Relay Management:** Users can "Bring Your Own Relay" (BYOR) to avoid centralized monitoring.

## Technical Workflows

### Joining a Space
Users can join spaces via:
- **QR Code Scanning:** Real-time scanning of invite codes.
- **Gallery Import:** Scanning QR codes from saved images.
- **Manual Link:** Pasting `ghost://room/` URIs.

*Recent Reliability Fixes:* Asynchronous handling ensures that data persistence to secure storage is completed and verified before the UI refreshes, preventing race conditions in the "Recent Spaces" list.

### Communication Flow
1. **Encryption:** Message is encrypted locally with a symmetric room key.
2. **Relay:** The encrypted blob (ciphertext + nonce) is sent to the relay.
3. **Distribution:** The relay broadcasts the blob to all connected clients in that room.
4. **Decryption:** Peer clients decrypt the message using the same room key.

## Development & Deployment

### 1. Prerequisites
- Docker & Docker Compose
- Flutter SDK (3.x+)
- `libstdc++-14-dev` (for Ubuntu 24.04+ toolchain compatibility)

### 2. Start the Relay
```bash
docker-compose up --build
```
*Relay API:* `http://localhost:4000` | *WebSocket:* `ws://localhost:4000`

### 3. Run the Client
```bash
cd client
flutter pub get
flutter run
```

## License

This project is provided under a **Custom License** strictly for **personal and educational purposes**. Commercial use, including redistribution or incorporation into revenue-generating platforms, is strictly prohibited.

See the [LICENSE](LICENSE) file for the full terms and conditions.

