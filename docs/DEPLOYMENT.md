# GhostRoom Relay Deployment Guide

This guide covers deploying the GhostRoom relay backend using Docker Compose, PostgreSQL, Redis, and Cloudflare R2 (or self-hosted MinIO).

---

## 1. Prerequisites

* **Docker & Docker Compose** (Docker 24+)
* **Domain Name & Reverse Proxy** (Nginx, Caddy, or Cloudflare Tunnel) with TLS/HTTPS
* **Cloudflare R2 Bucket** (or AWS S3, or local MinIO)
* *(Optional)* **Firebase Project** for FCM push notifications

---

## 2. Quickstart with Docker Compose

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

---

## 3. Environment Variables Reference (`backend/.env`)

### General
| Variable | Default | Description |
| :--- | :--- | :--- |
| `PORT` | `4000` | Port on which the NestJS relay listens. |
| `NODE_ENV` | `development` | Set to `production` in live environments. |
| `RELAY_URL` | `http://localhost:4000` | Publicly reachable HTTP/WS base URL of this relay. |

### Database & Cache
| Variable | Example | Description |
| :--- | :--- | :--- |
| `DATABASE_URL` | `postgresql://user:pass@postgres:5432/ghostroom` | PostgreSQL connection string. |
| `REDIS_URL` | `redis://localhost:6379` | Redis connection URL for rate-limiting, nonces, and fast caching. |

### Object Storage (Cloudflare R2 / S3 / MinIO)
| Variable | Description |
| :--- | :--- |
| `R2_ACCOUNT_ID` | Cloudflare account ID. |
| `R2_ACCESS_KEY_ID` | S3 API Access Key ID with edit permissions. |
| `R2_SECRET_ACCESS_KEY` | S3 API Secret Access Key. |
| `R2_BUCKET_NAME` | Name of the bucket (e.g. `ghostroom-media`). |
| `R2_PUBLIC_ENDPOINT` | *(Optional)* Custom public download endpoint or CDN URL. |

### Push Notifications (FCM)
| Variable | Default | Description |
| :--- | :--- | :--- |
| `FCM_ENABLED` | `false` | Enable Firebase Cloud Messaging wakeup notifications. |
| `FIREBASE_PROJECT_ID` | - | Firebase Project ID. |
| `FIREBASE_CLIENT_EMAIL` | - | Service account client email. |
| `FIREBASE_PRIVATE_KEY` | - | Service account PEM private key (newlines escaped as `\n`). |

*(For full FCM setup instructions, see [docs/firebase-backend-setup.md](file:///home/sugarcube/Desktop/Documents/Code-Server/@PRODUCTS/GhostRoom/docs/firebase-backend-setup.md)).*

---

## 4. Production Hardening Checklist

1. **Enable TLS**: Always terminate TLS (WSS / HTTPS) via reverse proxy (Nginx, Caddy, or Cloudflare).
2. **PostgreSQL Automated Backups**: Set up nightly pg_dump snapshots.
3. **Set Production Node Flags**:
   ```bash
   NODE_ENV=production
   ```
4. **Health Check**:
   Verify system health via `GET /health`. It validates database connectivity, Redis ping, storage bucket access, and FCM status.
