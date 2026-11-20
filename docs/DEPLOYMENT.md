# GhostRoom Relay Deployment Guide

This guide covers deploying the GhostRoom relay backend using Docker Compose, PostgreSQL, Cloudflare R2 (or self-hosted MinIO), and serverless platforms like Vercel.

---

## 1. Prerequisites

* **Docker & Docker Compose** (Docker 24+) or **Node.js 20+**
* **PostgreSQL Database** (version 15 or 16 with connection pooling for serverless)
* **Cloudflare R2 Bucket** (or AWS S3, or local MinIO)
* **Domain Name & Reverse Proxy** (Nginx, Caddy, Cloudflare, or Vercel) with TLS/HTTPS
* *(Optional)* **Firebase Project** for FCM push notifications

---

## 2. Deployment Strategies

### Strategy A: Docker Compose (Dedicated VPS / Server)

Recommended for production standalone deployments:

```bash
# 1. Clone the repository
git clone https://github.com/Sugarcube08/GhostRoom.git
cd GhostRoom

# 2. Configure environment
cp backend/.env.example backend/.env
# Edit backend/.env with your secrets

# 3. Start services
docker compose up -d
```

### Strategy B: Vercel Serverless Deployment

When deploying the backend on Vercel:

1. **Root Directory**: Set root directory to `backend`.
2. **Build Settings**:
   - Build Command: `npm run build`
   - Output Directory: `dist`
   - Install Command: `npm install`
3. **Database Connection Pooling**:
   - Serverless functions spawn ephemeral instances. Use a connection pooler like **Supabase Pooler (PgBouncer)**, **Neon**, or **AWS Aurora Serverless**.
   - Append `?sslmode=require&pgbouncer=true` to your `DATABASE_URL`.
4. **Environment Variables**: Add all environment variables from Section 4 below into your Vercel Project Settings.

---

## 3. Cloudflare R2 Storage Configuration

GhostRoom uses S3-compatible presigned URLs for client-side encrypted media storage.

### Generating R2 S3 API Credentials:
1. Log in to the **Cloudflare Dashboard** and navigate to **R2**.
2. Click **Create bucket** (e.g., `ghostroom-media`).
3. Under **Account Details** on the right, copy your **Account ID** (`R2_ACCOUNT_ID`).
4. On the R2 Overview page, click **Manage R2 API Tokens** > **Create API Token**:
   - **Permissions**: `Object Read & Write`.
   - **Specify bucket**: Select `ghostroom-media` (or all buckets).
   - **TTL**: Forever (or as required by security policy).
5. Click **Create API Token**.
6. Cloudflare displays:
   - **Access Key ID**: Maps to `R2_ACCESS_KEY_ID`.
   - **Secret Access Key**: Maps to `R2_SECRET_ACCESS_KEY`.
   - **Token Value**: (Format: `cfut_...`) Used for Cloudflare API management; the S3 endpoint uses the Access Key ID and Secret Access Key.
   - **Jurisdiction / S3 Endpoint**: `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`.

---

## 4. Environment Variables Reference (`backend/.env`)

### General
| Variable | Default | Description |
| :--- | :--- | :--- |
| `PORT` | `4000` | Port on which the NestJS relay listens. |
| `NODE_ENV` | `development` | Set to `production` in live environments. |
| `RELAY_URL` | `http://localhost:4000` | Publicly reachable HTTP/WSS base URL of this relay (e.g. `https://ghost-room-chi.vercel.app`). |

### Database
| Variable | Example | Description |
| :--- | :--- | :--- |
| `DATABASE_URL` | `postgresql://user:pass@postgres:5432/ghostroom` | PostgreSQL connection string. In serverless, include pooler query parameters. |

### Object Storage (Cloudflare R2 / S3 / MinIO)
| Variable | Example | Description |
| :--- | :--- | :--- |
| `R2_ACCOUNT_ID` | `a1b2c3d4e5f6...` | Cloudflare account ID. |
| `R2_ACCESS_KEY_ID` | `0123456789abcdef...` | S3 API Access Key ID. |
| `R2_SECRET_ACCESS_KEY` | `9876543210fedcba...` | S3 API Secret Access Key. |
| `R2_BUCKET_NAME` | `ghostroom-media` | Name of the storage bucket. |
| `R2_PUBLIC_ENDPOINT` | `https://media.yourdomain.com` | *(Optional)* Custom public CDN or download endpoint. |

### Push Notifications (FCM)
| Variable | Default | Description |
| :--- | :--- | :--- |
| `FCM_ENABLED` | `false` | Enable Firebase Cloud Messaging wakeup notifications. |
| `FIREBASE_PROJECT_ID` | - | Firebase Project ID. |
| `FIREBASE_CLIENT_EMAIL` | - | Service account client email. |
| `FIREBASE_PRIVATE_KEY` | - | Service account PEM private key (newlines escaped as `\n`). |

*(For complete FCM setup instructions, see [docs/firebase-backend-setup.md](firebase-backend-setup.md)).*

---

## 5. Public Web Portal & App Distribution

The backend automatically hosts the public distribution portal and mobile app verification files:

* **Landing Page**: `GET /`
* **Download Portal**: `GET /download` (reads release assets from `version.json` in the root repository)
* **Universal Link Fallback**: `GET /connect/:publicId` and `GET /u/:publicId`
* **Android App Links**: `GET /.well-known/assetlinks.json`
* **iOS Universal Links**: `GET /.well-known/apple-app-site-association`

Ensure `version.json` is deployed alongside the backend or placed at the application root so the portal dynamically lists download links and SHA-256 binary checksums.

---

## 6. Production Hardening Checklist

1. **Enable TLS**: Always terminate TLS (WSS / HTTPS) via reverse proxy (Caddy, Nginx, Cloudflare) or platform SSL.
2. **PostgreSQL Backups**: Set up automated nightly snapshots of PostgreSQL.
3. **Storage CORS Policy**: Configure Cloudflare R2 bucket CORS to allow `PUT` and `GET` requests from `*` or your authorized domains:
   ```json
   [
     {
       "AllowedOrigins": ["*"],
       "AllowedMethods": ["GET", "PUT", "HEAD"],
       "AllowedHeaders": ["*"],
       "MaxAgeSeconds": 3600
     }
   ]
   ```
4. **Health Verification**:
   Verify system health via `GET /health`. It confirms:
   - Database connectivity
   - Object storage bucket accessibility
   - Relay cryptographic integrity
   - FCM dispatcher availability
