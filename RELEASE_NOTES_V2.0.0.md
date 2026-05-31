# GhostRoom V2.0.0 — Official Stable Release 🏆

GhostRoom V2.0.0 is the first stable release of our durable, identity-based messaging network. This release represents a complete overhaul of the platform, prioritizing user sovereignty, long-term durability, and a premium user experience.

## 🌟 The Core Breakthroughs

### 🔐 Sovereign Identity (Self-Owned)
*   **BIP39 24-Word Seeds**: No accounts, no emails, no phone numbers. Your identity is mathematically derived from a seed phrase that only you own.
*   **Deterministic Recovery**: Restore your entire identity on any device instantly.
*   **Safety Drills**: Mandatory recovery simulations ensure you are actually prepared to restore your keys if your device is lost.

### 📩 Durable Mailbox Architecture
*   **PostgreSQL Persistence**: Messages and media are now stored in a durable system of record. Users can receive messages months or even years later.
*   **Zero-Knowledge Media**: End-to-end encrypted images and videos. The relay is 100% blind to all visual content and thumbnails.
*   **Hybrid Encryption**: X25519 authenticated key wrapping combined with XChaCha20-Poly1305 bulk encryption for maximum performance and security.

### 🛡️ Hardened Trust & Privacy
*   **Identity Vault**: A secure command center for your keys, fingerprints, and encrypted backups.
*   **Message Requests**: Unknown senders are automatically isolated. No unsolicited media is ever downloaded from non-contacts.
*   **Rate Limiting & Quotas**: Sophisticated resource protection (50 msg/hr, 100MB media/day) ensures network stability without compromising anonymity.

### 💎 Premium Experience
*   **Digital Passports**: High-fidelity QR cards for physical identity exchange.
*   **Retention Control**: Toggle between Persistent, Ephemeral (30-day), and View-Once modes for every message you send.
*   **High-Fidelity Navigation**: A professional navigation shell separating permanent messaging from transient anonymous spaces.

---

## 🏛️ Infrastructure
*   **Unified Stack**: Docker-ready with PostgreSQL 15, Redis 7, and MinIO/R2 support.
*   **Observability**: Full Prometheus `/metrics` and `/health` monitoring for relay operators.
*   **Stability**: 100% test coverage for core cryptographic and storage flows.

## 🚀 Getting Started
1. Rebuild your environment: `./build_all.sh`.
2. Follow the onboarding flow to generate your sovereign identity.
3. Save your Secure Backup and start communicating with absolute freedom.

---
*GhostRoom V2.0.0: Privacy is no longer a feature. It is the foundation.*
