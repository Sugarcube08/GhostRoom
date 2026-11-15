<p align="center">
  <img src="assets/brand/ghostroom_lockup_horizontal.svg" alt="GhostRoom" width="480">
</p>

<p align="center">
  <strong>Sovereign, End-to-End Encrypted Messenger with Zero-Knowledge Store-and-Forward Architecture.</strong>
</p>

<p align="center">
  No phone numbers. No email addresses. No server-side chat logs.
</p>

---

## 🏛️ Architecture & Privacy Model

GhostRoom operates on a **zero-knowledge store-and-forward relay model** (similar to Signal and WhatsApp):

* **Identity Without Accounts**: Cryptographic identities are derived deterministically from a 24-word BIP39 mnemonic seed using Libsodium (Ed25519 for signing, X25519 for key exchange).
* **Device-First Storage**: Decrypted message history and media exist strictly on the user's local device (Hive/SQLite).
* **Transient Relays**: The server holds **zero permanent message logs**. Messages are held in PostgreSQL only while in transit (`PENDING`). Once delivered and acknowledged (`message.ack`), they are **immediately and permanently purged** from the server.
* **Blind Media Storage**: Images, voice notes, and videos are encrypted client-side with random symmetric keys before upload to S3/R2 storage. The relay is blind to media contents and thumbnails.

---

## 🚀 Key Features

* 🔐 **Cryptographic Identity Vault**: 24-word seed phrase identity derivation with on-device backup and export (Argon2id + XChaCha20-Poly1305).
* 💬 **Direct P2P E2EE Messaging**: Fast, authenticated 1-on-1 direct conversations.
* 📷 **Zero-Knowledge Media**: High-speed encrypted media sharing with presigned chunked S3/R2 uploads.
* 🎙️ **Voice Notes**: Native audio recording and playback with in-flight waveform visualization.
* 📬 **Offline Outbox & Queuing**: Resilient queue that automatically retries and flushes pending messages upon reconnecting.
* 🔔 **Instant FCM Wakeups**: Background push notification wakeups when offline messages arrive.
* ✓✓ **Real-Time Delivery & Read Receipts**: Single tick (Sent), double tick (Delivered), blue tick (Seen).
* 📱 **Multi-Platform**: Cross-platform Flutter client targeting Android, Linux, macOS, and Windows.

---

## 🛠️ Tech Stack

* **Client**: Flutter (Dart 3.x), Riverpod, Libsodium (`sodium_libs`), Hive
* **Relay**: NestJS (TypeScript), Socket.IO, TypeORM, Prometheus Metrics
* **Database**: PostgreSQL 15/16 (Transient Inboxes & Store-and-Forward Deliveries)
* **Object Storage**: Cloudflare R2 / AWS S3 / MinIO (Encrypted Media)

---

## 📖 Documentation

* [System Architecture](file:///home/sugarcube/Desktop/Documents/Code-Server/@PRODUCTS/GhostRoom/docs/ARCHITECTURE.md)
* [Wire Protocol Specification](file:///home/sugarcube/Desktop/Documents/Code-Server/@PRODUCTS/GhostRoom/docs/PROTOCOL.md)
* [Zero-Knowledge Media Architecture](file:///home/sugarcube/Desktop/Documents/Code-Server/@PRODUCTS/GhostRoom/docs/MEDIA.md)
* [Relay Deployment Guide](file:///home/sugarcube/Desktop/Documents/Code-Server/@PRODUCTS/GhostRoom/docs/DEPLOYMENT.md)
* [Firebase FCM Setup](file:///home/sugarcube/Desktop/Documents/Code-Server/@PRODUCTS/GhostRoom/docs/firebase-backend-setup.md)

---

## 🚀 Self-Hosting

Deploy your own private relay with Docker Compose:

```bash
# 1. Clone the repository
git clone https://github.com/Sugarcube08/GhostRoom.git
cd GhostRoom

# 2. Configure environment
cp backend/.env.example backend/.env

# 3. Start relay, database, and cache
docker compose up -d
```

---

## 📄 License

GhostRoom is licensed under the MIT License. See [LICENSE](file:///home/sugarcube/Desktop/Documents/Code-Server/@PRODUCTS/GhostRoom/LICENSE) for details.
