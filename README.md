# GhostRoom

**Privacy-first, durable, identity-based encrypted messaging platform.**

GhostRoom V2.0.1 is a decentralized communication network designed for absolute privacy and long-term durability. It combines the ephemerality of temporary chat rooms with the reliability of a persistent encrypted mailbox system.

---

## 🏛️ Architecture

*   **Client**: Flutter (Android, iOS, Linux, macOS, Windows)
*   **Relay**: NestJS (TypeScript)
*   **Database**: PostgreSQL (Source of Truth) + Redis (Cache/Rate Limits)
*   **Storage**: Cloudflare R2 / MinIO (Encrypted Blobs)
*   **Crypto**: Libsodium (XChaCha20-Poly1305, X25519, Ed25519, Argon2id)

---

## 🚀 Key Features

*   **Self-Sovereign Identity**: 24-word BIP39 seed phrases with deterministic key derivation. No accounts, no usernames, no metadata in the cloud.
*   **Durable Messaging**: Multi-year offline delivery via PostgreSQL-backed inboxes.
*   **Zero-Knowledge Media**: End-to-end encrypted images and 720p videos. The relay never sees your content or your thumbnails.
*   **Trust Layer**: Built-in protection against spam and storage abuse via Identity-based rate limits and Message Requests.
*   **Full User Migration**: Encrypted backup and restore for contacts, identity, and settings.

---

## 🛠️ Self-Hosting (Docker)

GhostRoom is designed to be federated. You can run your own relay in minutes.

### 1. Requirements
*   Docker & Docker Compose
*   A Cloudflare R2 Bucket (or local MinIO)

### 2. Setup
```bash
# Clone the repository
git clone https://github.com/your-repo/ghostroom.git
cd ghostroom

# Configure environment
cp backend/.env.example backend/.env
# Update .env with your R2 keys and Postgres credentials
```

### 3. Deploy
```bash
# Development (with MinIO)
docker compose up -d

# Production
docker compose -f docker-compose.prod.yml up -d
```

---

## 📱 Mobile App

1.  Build the Flutter client: `cd client && flutter build apk` (or `ios`).
2.  The app comes preconfigured with the GhostRoom Global relay.
3.  Add your custom relay via **Settings > Relay Configuration**.

---

## 🛡️ Security Policy

*   **Server Blindness**: Relays only route signed and encrypted envelopes. They cannot decrypt content or identify senders without out-of-band metadata.
*   **Integrity Verification**: All media is hashed (SHA256) before encryption. Recipients verify this hash upon download.
*   **Forward Secrecy**: While V2.0.1 uses a persistent identity for signing, it utilizes hybrid encryption for message isolation.

---

## 📜 License
GhostRoom is [UNLICENSED](./LICENSE). See the LICENSE file for details.
