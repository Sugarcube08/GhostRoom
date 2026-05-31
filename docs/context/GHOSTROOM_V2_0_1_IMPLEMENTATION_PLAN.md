# GHOSTROOM_V2_0_1_IMPLEMENTATION_PLAN

Version: 2.0.1

Status: Approved For Development

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

* No phone numbers
* No email addresses
* No usernames
* No centralized accounts
* No server-side decryption
* No plaintext media storage
* No plaintext message storage

Server Responsibilities:

* Queue encrypted payloads
* Route encrypted payloads
* Store encrypted blobs

Client Responsibilities:

* Identity
* Encryption
* Signing
* Verification
* Decryption

---

# V2.0.1 SYSTEM ARCHITECTURE

```text
Flutter Client
        │
        │
        ▼
NestJS Relay
        │
        ├─────────────── Redis
        │
        └─────────────── Cloudflare R2
```

Redis:

```text
Identity Inboxes
Delivery State
ACK State
Message Metadata
```

Cloudflare R2:

```text
Encrypted Images
Encrypted Videos
Encrypted Files
Encrypted Thumbnails
```

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
  "public_id":"",

  "eid":"",

  "xid":"",

  "preferred_relays":[
    ""
  ],

  "fingerprint":"",

  "signature":""
}
```

Transport:

* QR
* Deep Link
* Manual Import
* Identity File

---

# IDENTITY BACKUP FILE

Extension:

```text
.ghostroomid
```

Structure:

```json
{
  "version":1,

  "encrypted_seed":"",

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
Hive / SQLite
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
  "id":"",

  "version":1,

  "type":"text",

  "sender_public_id":"",

  "created_at":"",

  "expires_at":"",

  "ciphertext":"",

  "nonce":"",

  "signature":""
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

# MEDIA ENVELOPE

Schema:

```json
{
  "type":"image",

  "media_id":"",

  "mime_type":"",

  "size":"",

  "width":"",

  "height":"",

  "encrypted_media_key":"",

  "thumbnail_id":""
}
```

Video:

```json
{
  "type":"video",

  "media_id":"",

  "duration":"",

  "thumbnail_id":"",

  "encrypted_media_key":""
}
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

Recipient X25519
```

↓

Upload Ciphertext

Server stores:

```text
Encrypted Blob Only
```

---

# REDIS SCHEMA

Inbox:

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

```json
{
  "message_id":"",

  "payload":""
}
```

---

# DELIVERY STATE

States:

```text
CREATED

QUEUED

DELIVERED

VIEWED

DELETED
```

---

# ACK EVENT

Client:

```json
{
  "message_id":"",

  "status":"viewed"
}
```

Server:

```text
ZREM
```

from inbox.

---

# MESSAGE RETENTION

Server Default:

```text
7 Days
```

Maximum:

```text
14 Days
```

Queue Cap:

```text
100 Messages
```

Per Inbox.

---

# R2 OBJECT SCHEMA

Images:

```text
media/images/{media_id}
```

Videos:

```text
media/videos/{media_id}
```

Files:

```text
media/files/{media_id}
```

Thumbnails:

```text
media/thumbs/{media_id}
```

Object Contents:

```text
Encrypted Binary
```

Only.

---

# WEBSOCKET EVENTS

Identity:

```text
identity.register

identity.update

identity.lookup
```

Messaging:

```text
message.send

message.receive

message.ack
```

Inbox:

```text
inbox.fetch

inbox.sync
```

Media:

```text
media.upload.request

media.upload.complete

media.download.request
```

Space Mode:

```text
space.create

space.join

space.leave

space.expired
```

Retained For Compatibility.

---

# RELAY API

POST

```text
/media/upload-url
```

Returns:

```json
{
  "upload_url":"",

  "media_id":""
}
```

---

GET

```text
/media/download-url/{media_id}
```

Returns:

```json
{
  "download_url":""
}
```

---

# CLIENT FEATURES

Phase 1

Identity

* Create Identity
* Restore Identity
* Export Identity
* Wipe Identity

---

Phase 2

Contacts

* Add Contact
* Scan QR
* Import Identity Package
* Fingerprint Verification

---

Phase 3

Direct Messaging

* Send Message
* Offline Delivery
* View Once
* Self Destruct

---

Phase 4

Media

* Image Upload
* Video Upload
* Thumbnail Generation
* Media Viewer

---

Phase 5

Message Requests

* Unknown Sender Queue
* Accept
* Reject
* Block

---

# MIGRATION STRATEGY

Existing V1:

```text
room:{id}
msgs:{roomId}
```

Remain Untouched.

V2 Adds:

```text
inbox:{public_id}
```

No Breaking Changes.

Both Modes Coexist.

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

```
```
