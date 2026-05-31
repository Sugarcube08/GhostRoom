# GHOSTROOM_V2_0_1_IMPLEMENTATION_PLAN

Version: 2.0.1

Status: ✅ COMPLETE

Architecture Strategy:

```text
GhostRoom V1
    ↓
GhostRoom V2
    ↓
GhostRoom V2.0.1
```

Primary Product:

```text
Identity Messaging
```

Secondary Product:

```text
Temporary Spaces
```

Media Support:

```text
Encrypted Images
Encrypted Videos
Encrypted Files
```

---

# CORE PRINCIPLES

Non-Negotiable:

* ✅ No phone numbers
* ✅ No email addresses
* ✅ No usernames
* ✅ No centralized accounts
* ✅ No server-side decryption
* ✅ No plaintext media storage
* ✅ No plaintext message storage

Server Responsibilities:

* ✅ Queue encrypted payloads
* ✅ Route encrypted payloads
* ✅ Store encrypted blobs

Client Responsibilities:

* ✅ Identity
* ✅ Encryption
* ✅ Signing
* ✅ Verification
* ✅ Decryption

---

# V2.0.1 SYSTEM ARCHITECTURE

```text
Flutter Client
        │
        │
        ▼
NestJS Relay
        │
        ├─────────────── PostgreSQL (Source of Truth)
        │
        ├─────────────── Redis (Cache / Quotas / Presence)
        │
        └─────────────── Cloudflare R2 / MinIO (Encrypted Blobs)
```

PostgreSQL:
* ✅ Identity Inboxes
* ✅ Delivery State
* ✅ Message Metadata

Redis:
* ✅ Performance Cache
* ✅ Rate Limits
* ✅ Challenges
* ✅ Presence

Cloudflare R2 / MinIO:
* ✅ Encrypted Images
* ✅ Encrypted Videos
* ✅ Encrypted Files
* ✅ Encrypted Thumbnails

---

# IDENTITY MODEL

Identity Source:

```text
24 Word BIP39 Seed
```

Generated Once.

Identity Derivation:

```text
Seed
    ↓
Master Key
    ↓
Ed25519
    ↓
X25519
    ↓
Public ID
```

Public ID:

```text
Base58(
 Blake2b(
  Ed25519 Public Key
 )
)
```

Example:

```text
GR7Mh4jA8X2QrKxP
```

---

# IDENTITY PACKAGE

Schema:

```json
{
  "v":1,
  "eid":"",
  "xid":"",
  "preferred_relays":[
    ""
  ],
  "s":""
}
```

Transport:

* ✅ QR
* ✅ Deep Link
* ✅ Manual Import
* ✅ Identity File

---

# IDENTITY BACKUP FILE

Extension:

```text
.ghostroombackup
```

Structure:

```json
{
  "version":1,
  "seed":"",
  "contacts":[],
  "blocked":[],
  "settings":{},
  "created_at":""
}
```

Encryption:

```text
Argon2id

↓

XChaCha20-Poly1305
```

User Passphrase Protected.

---

# CONTACT MODEL

Local Only.

Storage:

```text
Hive (Encrypted)
```

Schema:

```json
{
  "public_id":"",
  "alias":"",
  "notes":"",
  "eid":"",
  "xid":"",
  "fingerprint":"",
  "created_at":""
}
```

No server storage.

---

# DIRECT MESSAGE MODEL

Schema:

```json
{
  "id":"uuid_v7",
  "v":2,
  "t":1622510000000,
  "k":"base64",
  "n":"base64",
  "c":"base64",
  "s":"base64"
}
```

Types:

```text
text
image
video
file
system
```

---

# MEDIA MODEL

Image Limits:

```text
Input:
10 MB
```

After Compression:

```text
Max:
5 MB
```

Video Limits:

```text
Input:
30 MB
```

After Compression:

```text
Max:
15 MB
```

Supported Images:

```text
jpg
jpeg
png
webp
heic
```

Supported Videos:

```text
mp4
mov
webm
```

---

# MEDIA ENCRYPTION

Client:

```text
Generate Random Media Key
```

↓

```text
Encrypt Media

XChaCha20-Poly1305
```

↓

```text
Encrypt Media Key

Recipient X25519 (crypto_box_seal)
```

↓

Upload Ciphertext

Server stores:

```text
Encrypted Blob Only
```

---

# REDIS SCHEMA

Inbox Cache:

```text
inbox:{public_id}
```

Type:

```text
ZSET
```

Score:

```text
timestamp
```

Value:

```text
message_id
```

---

# DELIVERY STATE

States:

```text
PENDING
ACKNOWLEDGED
```

---

# ACK EVENT

Client:

```json
{
  "message_id":""
}
```

Server:

```text
ZREM inbox
DELETE message
```

---

# MESSAGE RETENTION

* ✅ VIEW_ONCE: Delete on ACK
* ✅ EPHEMERAL: 30 Days
* ✅ PERSISTENT: Unlimited

---

# R2 OBJECT SCHEMA

Bulk:
```text
media/{media_id}
```

Thumbnails:
```text
thumbs/{media_id}
```

Object Contents:

```text
Encrypted Binary
```

Only.

---

# WEBSOCKET EVENTS

Authentication:
* ✅ identity.challenge
* ✅ identity.prove
* ✅ identity.verified

Messaging:
* ✅ message.send
* ✅ message.receive
* ✅ message.ack

Inbox:
* ✅ inbox.fetch

Media:
* ✅ media.viewed

Space Mode:
* ✅ space.join
* ✅ space.history
* ✅ space.joined
* ✅ space.expired

Retained For Compatibility.

---

# RELAY API

POST

```text
/media/upload-url
```

---

GET

```text
/media/download-url/{media_id}
```

---

# SUCCESS CRITERIA

GhostRoom V2.0.1 is complete when:

✓ Identity based messaging works

✓ Offline delivery works

✓ Seed recovery works

✓ Contact exchange works

✓ Fingerprint verification works

✓ Images work

✓ Videos work

✓ View once works

✓ Relay remains blind

✓ Temporary spaces still function

✓ No accounts exist

✓ No phone numbers exist

✓ No emails exist

✓ Server never sees plaintext

✓ Durable persistence (Postgres) active

✓ Resource protection (Quotas/Rate limits) active

✓ Full backup/restore active
