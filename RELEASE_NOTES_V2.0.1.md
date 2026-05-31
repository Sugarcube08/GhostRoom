# GhostRoom V2.0.1 — The Durable Mailbox Update 👻

We are thrilled to announce the release of **GhostRoom V2.0.1**. This update marks the single largest architectural leap in the project's history, transforming GhostRoom from a transient ephemeral relay into a durable, identity-based, end-to-end encrypted messaging network.

## 🚀 Key Features

### 🔐 Cryptographic Identity & Sovereignty
*   **Deterministic Recovery**: Replaced random device IDs with 24-word BIP39 seed phrases. Your identity is now mathematically recoverable on any device.
*   **Identity Packages**: Secure, signed JSON artifacts for peer-to-peer contact exchange without a central registry or username honeypot.
*   **Safety Numbers**: 8-segment cryptographic fingerprints for out-of-band verification to defeat Man-in-the-Middle (MITM) attacks.

### 📩 Durable Encrypted Mailboxes
*   **System of Record (PostgreSQL)**: Messages and media metadata are now stored durably in PostgreSQL. This enables multi-year offline delivery—if you send a message today, the recipient can receive it years from now.
*   **Hybrid Encryption**: Bulk content is encrypted with XChaCha20-Poly1305 (via libsodium), while content keys are wrapped per-recipient using X25519 authenticated encryption.
*   **Retention Modes**: Choose your ephemerality:
    *   `PERSISTENT`: Kept until acknowledged.
    *   `EPHEMERAL`: Auto-delete after 30 days.
    *   `VIEW_ONCE`: Immediate server-side deletion upon read.

### 🖼️ Encrypted Multi-Media Transport
*   **Image & Video Support**: Send high-resolution images and 720p H264 videos.
*   **Encrypted Thumbnails**: All previews are generated and encrypted on the client. The relay remains 100% blind to all visual content.
*   **Integrity Verification**: Mandatory SHA256 hashing of all media before encryption to detect corruption or tamper attempts.

### 🛡️ Trust & Abuse Resistance
*   **Message Requests**: Unknown senders are automatically routed to a separate requests inbox.
*   **Media Restrictions**: To prevent storage abuse, media attachments from unknown senders are dropped automatically.
*   **Identity Rate Limits**: Per-public-ID quotas (50 msg/hr) to protect the relay from mass-identity spam.
*   **Local Blocking**: Silent local rejection of malicious identities.

### 💾 Backup & Migration
*   **Encrypted Archives**: Export your entire state (Identity, Contacts, Block List, Settings) into an encrypted `.ghostroombackup` file protected by Argon2id.

---

## 🛠️ Internal Improvements
*   **Durable Relay Infrastructure**: Full Docker Compose stack with PostgreSQL, Redis (Cache), and MinIO/R2 support.
*   **Observability**: Integrated Prometheus `/metrics` and a detailed `/health` check system.
*   **Audit Trails**: Non-PII `relay_audit` logging for operational monitoring.
*   **V1 Compatibility**: Existing Temporary Spaces remain fully operational and isolated from the new identity layer.

## 📦 Getting Started
1.  Pull the latest `docker-compose.prod.yml`.
2.  Update your `.env` using the provided `.env.example`.
3.  Deploy and start communicating with absolute privacy and durability.

---
*GhostRoom: Encryption is a human right. Durability is a technical requirement.*
