# GHOSTROOM PHASE 6: ENCRYPTED MEDIA ARCHITECTURE

This document defines the architecture for secure, anonymous, and ephemeral media transport in GhostRoom V2.

---

## 1. MEDIA LIFECYCLE

To prevent orphaned blobs in Cloudflare R2 and ensure ephemerality, every media object must follow this state machine:

1.  **UPLOADING**: Client requests an Upload URL. Redis metadata is created.
2.  **UPLOADED**: Client confirms successful PUT to R2.
3.  **REFERENCED**: A message envelope containing the `media_id` is successfully queued in an `inbox:{id}`.
4.  **VIEWED**: Recipient acknowledges receiving and opening the media.
5.  **EXPIRED**: Media exceeds the retention threshold (default 48 hours).
6.  **DELETED**: Cleanup worker removes the object from R2 and metadata from Redis.

---

## 2. REDIS METADATA SCHEMA

**Key Pattern**: `media:{media_id}`
**Data Type**: `HASH`

| Field | Type | Description |
| :--- | :--- | :--- |
| `owner` | String | Public ID of the uploader (for rate limiting/cleanup). |
| `size` | Number | Byte size of the encrypted blob. |
| `mime` | String | Encrypted or generic mime-type. |
| `state` | String | Current lifecycle state. |
| `created_at` | Number | Unix timestamp. |
| `expires_at` | Number | Unix timestamp for auto-deletion. |

---

## 3. R2 OBJECT LAYOUT

Objects are stored in a single bucket with prefix-based organization:

*   `media/{media_id}`: The encrypted bulk payload.
*   `thumbs/{media_id}`: The encrypted client-generated thumbnail.

The bucket must have **Public Access Disabled**. All access is via pre-signed URLs.

---

## 4. ORPHAN CLEANUP STRATEGY

A backend **Cleanup Worker** (Cron Job) runs hourly to:

1.  Identify `media:*` keys where `state == 'UPLOADING'` and `age > 2 hours`.
2.  Identify `media:*` keys where `expires_at < now`.
3.  For each identified ID:
    *   `DELETE` object from R2 bucket.
    *   `DEL` metadata from Redis.

---

## 5. UPLOAD FAILURE RECOVERY

*   If `message.send` fails after a successful R2 upload, the client should retry sending the envelope for 5 minutes.
*   If retries fail, the media is abandoned and will be pruned by the Cleanup Worker within 2 hours.

---

## 6. INTEGRITY VERIFICATION

1.  **Sender**: Calculates `SHA256(plaintext_file)`.
2.  **Envelope**: The SHA256 hash is included *inside* the E2EE message payload.
3.  **Recipient**: 
    *   Download and Decrypt.
    *   Calculate `SHA256(decrypted_bytes)`.
    *   Compare with the hash in the payload.
    *   **Action**: Reject if mismatch (Detection of corruption or MITM).

---

## 7. ENCRYPTED THUMBNAIL STRATEGY

1.  **Client-Side Generation**: Use `video_thumbnail` or `image` package to create a low-res preview.
2.  **Encryption**: Encrypt the thumbnail using the **same Message Key** as the bulk file but with a **different Nonce** (or a derived sub-key).
3.  **Upload**: Upload to `thumbs/{media_id}`.
4.  **Download**: Recipient fetches the thumbnail pre-signed URL first to show a blurred/low-res preview while bulk download proceeds.

---

## 8. MEDIA RETENTION POLICY

*   **Default**: 48 hours.
*   **View-Once**: If the message is flagged "View Once", the recipient client issues a `media.viewed` socket event, triggering immediate server-side deletion.

---

## 9. MEDIA SIZE ENFORCEMENT

*   **Images**: 10MB limit (Client-side compression mandatory).
*   **Videos**: 30MB limit.
*   **Verification**: The backend `POST /media/upload-url` API verifies the requested `size` against user quotas before issuing a signed URL.

---

## 10. FUTURE EXTENSIBILITY

The "Hybrid Encryption + R2 Blob" model is transport-agnostic. Support for `.pdf`, `.zip`, or `.mp3` is achieved simply by adding new `MessageType` values and mime-type headers without modifying the core `MediaService` logic.
