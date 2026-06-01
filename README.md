# GhostRoom

**Private messaging without accounts, phone numbers, or email addresses.**

GhostRoom V2.0.0 is a premium, identity-based communication network designed for absolute privacy and long-term durability. It combines a sovereign identity system with a durable encrypted mailbox network.

---

## 🏛️ Architecture

*   **Client**: Flutter (Android, iOS, Linux, macOS, Windows)
*   **Relay**: NestJS (TypeScript)
*   **Database**: PostgreSQL (System of Record) + Redis (Cache/Rate Limits)
*   **Storage**: Cloudflare R2 / MinIO (Encrypted Blobs)
*   **Crypto**: Libsodium (XChaCha20-Poly1305, X25519, Ed25519, Argon2id)

---

## 🚀 Key Features

*   **Identity Vault**: Your digital soul, secured by a 24-word seed and guarded by real-time security scoring.
*   **Durable Messaging**: Multi-year offline delivery via PostgreSQL-backed inboxes.
*   **Digital Passports**: Peer-to-peer identity exchange via signed packages and Safety Numbers.
*   **Flexible Retention**: Toggle between Persistent, Ephemeral, and View-Once modes per message.
*   **Zero-Knowledge Media**: E2EE images and 720p videos. The relay is 100% blind to content and thumbnails.
*   **Disposable Spaces**: Anonymous, symmetric rooms for transient conversations with zero footprint.

---

## 🛠️ Self-Hosting (Docker)

GhostRoom is federated and easy to deploy.

### 1. Requirements
*   Docker & Docker Compose
*   Cloudflare R2 Bucket or local MinIO

### 2. Setup
```bash
# Clone the repository
git clone https://github.com/your-repo/ghostroom.git
cd ghostroom

# Configure environment
cp backend/.env.example backend/.env
```

### 3. Deploy
```bash
# Development (with MinIO)
docker compose up -d

# Production
docker compose -f docker-compose.prod.yml up -d
```

---

## 📱 Getting Started

1.  Build the Flutter client: `cd client && flutter build apk`.
2.  The app opens to the **Onboarding Flow** to generate your sovereign identity.
3.  Perform the **Recovery Drill** and save your **Secure Backup**.
4.  Share your **Passport QR** to start a secure channel.

---

## 🔧 Troubleshooting

### Redis: Memory overcommit warning
If you see the warning `# WARNING Memory overcommit must be enabled!` in your logs, you can fix it on the host machine by running:
```bash
sudo sysctl vm.overcommit_memory=1
```
To make this persistent, add `vm.overcommit_memory = 1` to `/etc/sysctl.conf`.

### MinIO/R2 Connectivity
If the backend cannot reach MinIO or the client cannot download media, ensure `R2_ENDPOINT` and `R2_PUBLIC_ENDPOINT` are correctly configured in your `.env` or `docker-compose.yml`. For local development, `R2_ENDPOINT` should point to the container (`http://minio:9000`) and `R2_PUBLIC_ENDPOINT` should point to the host (`http://localhost:9000`).

---

## 📜 License
GhostRoom is [UNLICENSED](./LICENSE). See the LICENSE file for details.
