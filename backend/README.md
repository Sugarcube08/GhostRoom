<p align="center">
  <img src="../assets/brand/ghostroom_lockup_horizontal.svg" alt="GhostRoom Relay" width="440">
</p>

# GhostRoom Relay (NestJS Backend)

The high-performance, zero-knowledge store-and-forward relay server for the **GhostRoom** messaging network. Built with NestJS, TypeScript, Socket.IO, TypeORM, PostgreSQL, and Cloudflare R2 / AWS S3.

---

## 🏛️ Architecture & Privacy Guarantees

The GhostRoom Relay operates as a **transient message postbox**:

1. **Zero Message History**: Messages exist in the PostgreSQL database only while status is `PENDING`. The moment the recipient acknowledges delivery via `message.ack`, the message is **hard deleted** immediately and permanently.
2. **Blind Cryptographic Routing**: Payloads are opaque ciphertexts. The relay cannot decrypt messages, inspect sender/recipient relations beyond ephemeral transit IDs, or view media attachments.
3. **Anti-Replay Handshake**: Clients must prove ownership of their public ID by signing a 32-byte cryptographically random server challenge (`identity.challenge` -> `identity.prove`) using their Ed25519 private key.
4. **Blind Media Broker**: Generates presigned S3 upload/download URLs for client-side encrypted blobs. Tracks reference counts and auto-deletes orphaned media from Cloudflare R2 / S3.
5. **Integrated Web Portal & Distribution Engine**: Serves the public landing page (`/`), release distribution portal (`/download`), universal connect redirects (`/connect/:publicId`), and native mobile link verification (`/.well-known/*`).

---

## 📁 System Components

```
backend/src/
├── app.controller.ts       # Health endpoint (`GET /status` & `GET /health`)
├── app.module.ts           # Root dependency injection module
├── config/                 # Environment configuration & TypeORM options
├── inbox/                  # Store-and-forward messaging engine
│   ├── inbox.gateway.ts    # Socket.IO WebSocket gateway & event routing
│   ├── inbox.service.ts    # Message persistence, delivery, and auto-purge logic
│   ├── firebase.service.ts # FCM background wakeup dispatcher
│   └── crypto-utils.service.ts # Anti-replay challenge generator & signature verifier
├── media/                  # Zero-knowledge blob storage broker
│   ├── media.controller.ts # REST endpoints for presigned URLs & confirmation
│   └── media.service.ts    # Cloudflare R2 / S3 client & refcount lifecycle
└── portal/                 # Public web portal & distribution router
    ├── portal.controller.ts # Web routes (`/`, `/download`, `/connect/:id`, `/.well-known/*`)
    └── portal.controller.spec.ts # Unit tests for web routes & assetlinks
```

---

## 🌐 Public Routes & Universal Routing

| Route | Method | Description |
| :--- | :--- | :--- |
| `/` | `GET` | Public landing page (HTML for browsers, JSON for API status). |
| `/download` | `GET` | Release distribution portal with direct APK/AppImage downloads and SHA-256 checksums. |
| `/connect/:publicId` | `GET` | Smart-redirect web route for peer invites with 1500ms fallback. |
| `/u/:publicId` | `GET` | Short-URL alias for `/connect/:publicId`. |
| `/.well-known/assetlinks.json` | `GET` | Android App Links verification manifest (`com.ghostroom.app`). |
| `/.well-known/apple-app-site-association` | `GET` | iOS Universal Links association manifest. |
| `/health` | `GET` | System health check (PostgreSQL, R2 storage, memory). |
| `/status` | `GET` | Lightweight JSON uptime status. |

---

## ⚙️ Configuration (`backend/.env`)

```env
# Server
PORT=4000
NODE_ENV=production
RELAY_URL=https://ghost-room-chi.vercel.app

# Database
DATABASE_URL=postgresql://ghostroom:ghostroom_secret@postgres:5432/ghostroom

# Object Storage (Cloudflare R2 / S3 / MinIO)
R2_ACCOUNT_ID=your_cloudflare_account_id
R2_ACCESS_KEY_ID=your_r2_access_key_id
R2_SECRET_ACCESS_KEY=your_r2_secret_access_key
R2_BUCKET_NAME=ghostroom-media
R2_PUBLIC_ENDPOINT=https://your-custom-cdn-domain.com # Optional

# Push Notifications (Firebase FCM)
FCM_ENABLED=true
FIREBASE_PROJECT_ID=ghostroom-app
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@ghostroom-app.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

---

## 🚀 Running the Relay

### Docker Compose (Recommended)

```bash
# Launch relay, PostgreSQL database, and MinIO locally
docker compose up -d --build
```

### Manual Development

```bash
# 1. Install dependencies
npm install

# 2. Build TypeScript
npm run build

# 3. Start development server with hot-reload
npm run start:dev

# 4. Start production server
npm run start:prod
```

---

## 🧪 Testing

```bash
# Run all unit tests
npm test

# Run tests in watch mode
npm run test:watch

# Run end-to-end suite
npm run test:e2e
```

---

## 📄 License

GhostRoom is licensed under the MIT License. See [LICENSE](../LICENSE) for details.
