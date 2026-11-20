<p align="center">
  <img src="assets/brand/ghostroom_lockup_horizontal.svg" alt="GhostRoom" width="480">
</p>

<p align="center">
  <strong>Sovereign, End-to-End Encrypted Messenger with Zero-Knowledge Store-and-Forward Architecture.</strong>
</p>

<p align="center">
  No phone numbers. No email addresses. No server-side chat logs. Hardware-grade cryptography.
</p>

<p align="center">
  <a href="https://github.com/Sugarcube08/GhostRoom/releases/latest"><img src="https://img.shields.io/badge/release-v2.5.0-7C5CFF?style=flat-square" alt="Latest Release"></a>
  <a href="https://github.com/Sugarcube08/GhostRoom/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-3DDC97?style=flat-square" alt="License"></a>
  <a href="https://ghost-room-chi.vercel.app/"><img src="https://img.shields.io/badge/portal-live-blue?style=flat-square" alt="Live Portal"></a>
</p>

---

## 🏛️ Architecture & Privacy Model

GhostRoom operates on a **zero-knowledge store-and-forward relay model** (similar to Signal and Session):

* **Identity Without Accounts**: Cryptographic identities are derived deterministically from a 24-word BIP-39 mnemonic seed using Libsodium (Ed25519 for signing, X25519 for key exchange).
* **Dual-Method Identity Vault**: Accounts can be restored via standard 24-word passphrases or portable, hardware-encrypted `.ghostkey` JSON files protected by Argon2id + XChaCha20-Poly1305.
* **Device-First Storage**: Decrypted message history and media exist strictly on the user's local device (Hive/SQLite).
* **Transient Relays**: The server holds **zero permanent message logs**. Messages are stored in PostgreSQL only while in transit (`PENDING`). Once delivered and acknowledged (`message.ack`), they are **immediately and permanently purged** from the server.
* **Blind Media Storage**: Images, voice notes, and videos are encrypted client-side with random symmetric keys before upload to S3/Cloudflare R2 storage. The relay is blind to media contents and thumbnails.
* **Universal Contact Links**: Shareable HTTPS routes (`/connect/<PUBLIC_ID>`), scannable QR codes, and native App Links (`autoVerify="true"`) allow instant, verified peer connections without centralized directories.

---

## 🚀 Key Features

* 🔐 **Dual-Method Identity Vault**: 24-word mnemonic seed derivation alongside portable encrypted `.ghostkey` keyfiles (Argon2id + XChaCha20-Poly1305).
* 💬 **Direct P2P E2EE Messaging**: Authenticated 1-on-1 direct conversations with forward-secret envelopes.
* 📷 **Zero-Knowledge Media**: Presigned Cloudflare R2 / S3 chunked uploads with client-side XChaCha20-Poly1305 encryption.
* 🎙️ **Voice Notes**: Native audio recording and playback with in-flight waveform visualization.
* 🌐 **Universal App Routing**: Deep links (`https://<DOMAIN>/connect/<PUBLIC_ID>` & `ghostroom://connect/<PUBLIC_ID>`) with smart web redirects and in-app fingerprint verification.
* 📦 **Public Portal & Download Center**: Integrated high-contrast web portal (`/`) and multi-platform release distribution center (`/download`) with SHA-256 verification.
* 🔄 **Automated In-App Updates**: Built-in multi-platform auto-updater verifying SHA-256 binary signatures against `version.json`.
* 📬 **Offline Outbox & Queuing**: Resilient queue that automatically retries and flushes pending messages upon reconnecting.
* 🔔 **Instant FCM Wakeups**: Background push notification wakeups when offline messages arrive (zero plaintext exposed to push servers).
* ✓✓ **Real-Time Delivery & Read Receipts**: Single tick (Sent), double tick (Delivered), blue tick (Seen).
* 📱 **Multi-Platform**: Cross-platform Flutter client targeting Android, Linux (AppImage, deb, rpm, tar.gz), macOS, and Windows.

---

## 🛠️ Tech Stack

* **Client**: Flutter (Dart 3.x), Riverpod, Libsodium (`sodium_libs`), Hive, Mobile Scanner
* **Relay**: NestJS (TypeScript), Socket.IO, TypeORM, Prometheus Metrics
* **Database**: PostgreSQL 15/16 (Transient Inboxes & Store-and-Forward Deliveries)
* **Object Storage**: Cloudflare R2 / AWS S3 / MinIO (Encrypted Media)
* **Distribution**: Next.js / NestJS Portal with SHA-256 binary verification

---

## 📖 Documentation

* [System Architecture](docs/ARCHITECTURE.md): Complete architecture diagram, storage schema, and cryptographic invariants.
* [Wire Protocol Specification](docs/PROTOCOL.md): WebSocket handshake, challenge-response, direct messaging, and keyfile specs.
* [Zero-Knowledge Media Architecture](docs/MEDIA.md): End-to-end media encryption, presigned R2/S3 URLs, and refcounted cleanup.
* [Relay Deployment Guide](docs/DEPLOYMENT.md): Self-hosting with Docker Compose, Vercel serverless, and Cloudflare R2 setup.
* [Firebase FCM Setup](docs/firebase-backend-setup.md): Configuring push wakeups without compromising message privacy.

---

## 🚀 Quick Start & Self-Hosting

### 1. Deploy Relay with Docker Compose

```bash
# Clone the repository
git clone https://github.com/Sugarcube08/GhostRoom.git
cd GhostRoom

# Configure environment secrets
cp backend/.env.example backend/.env

# Launch relay, database, and cache
docker compose up -d
```

### 2. Run the Flutter Client

```bash
cd client

# Install dependencies
flutter pub get

# Run on your connected device or desktop
flutter run
```

---

## 📄 License

GhostRoom is licensed under the MIT License. See [LICENSE](LICENSE) for details.
