# GHOSTROOM PHASE 8: MEDIA UI SPECIFICATION

This document defines the UX and technical flows for handling encrypted images and videos in GhostRoom V2.

---

## 1. IMAGE FLOW (SENDER)

1.  **Pick**: User selects an image using `image_picker`.
2.  **Compress**: Client-side JPEG compression via `flutter_image_compress` (Target: < 1MB, 70% quality).
3.  **Encrypt**: 
    *   Generate random 32-byte Message Key.
    *   Encrypt bulk image with XChaCha20-Poly1305.
    *   Compute SHA256 of plaintext.
4.  **Thumbnail**: 
    *   Generate a low-res (100px width) thumbnail.
    *   Encrypt thumbnail using the *same Message Key* but a *different Nonce*.
5.  **Upload**:
    *   Request Upload URLs for both bulk and thumbnail.
    *   PUT encrypted bytes to R2.
    *   Confirm Upload to Relay.
6.  **Envelope**: Create `AttachmentEnvelope` (kind: image, id, key, hash, meta).
7.  **Send**: Embed envelope in hybrid E2EE message and emit to relay.

---

## 2. DOWNLOAD FLOW (RECIPIENT)

1.  **Placeholder**: Message bubble shows an "Encrypted Image" block with a "Download (Size)" button.
2.  **Thumbnail (Optional/Future)**: If a thumbnail exists, download and decrypt it to show a blurred preview.
3.  **Tap**: User taps "Download".
4.  **Download**: Fetch pre-signed URL and download bulk encrypted blob from R2.
5.  **Integrity**: Compute SHA256 of decrypted bytes and compare with the hash in the envelope.
6.  **Display**: If hash matches, render the image using `Image.memory`. If mismatch, show "Corruption Detected".

---

## 3. FAILURE STATES & RECOVERY

*   **Upload Failed**: UI shows red "Retry" icon on the message.
*   **Quota Exceeded**: Backend returns 400. Client shows "Daily Limit Reached".
*   **Hash Mismatch**: Client deletes the downloaded blob and shows "Integrity Error".
*   **Media Expired**: R2 returns 404 or Relay returns 400. UI shows "Media Expired".

---

## 4. UX & SECURITY RULES

*   **Unknown Senders**: Media attachments are discarded immediately (Phase 7 rule).
*   **Known Contacts**: Manual download only. No automatic fetch.
*   **Blocked Users**: Envelope is discarded immediately upon receipt.
*   **Encrypted Thumbnails**: Thumbnails MUST be encrypted. No plaintext previews stored on the relay or R2.

---

## 5. CACHE & MEMORY POLICY

*   **Temporary Cache**: Decrypted images are stored in-memory during the session.
*   **Persistence**: Decrypted media is NOT saved to the device's public gallery unless explicitly exported by the user ("Save to Gallery").
*   **OOM Prevention**: For 10MB+ images, use `Image.memory` with `cacheWidth/cacheHeight` to avoid heap exhaustion.

---

## 6. THUMBNAIL POLICY

*   **Encrypted**: Mandatory.
*   **Format**: Base64 encoded inside the metadata OR a separate R2 object (`thumbs/` prefix).
*   **Decision**: For V2.0.1, we use separate R2 objects for thumbnails to keep the E2EE envelope small for WebSocket transport.

---

## 7. ATTACHMENT ENVELOPE (IMAGE)

```json
{
  "kind": "image",
  "media_id": "uuid",
  "key": "base64_wrapped_key",
  "hash": "sha256_hex",
  "meta": {
    "w": 1920,
    "h": 1080,
    "size": 850000,
    "nonce": "base64",
    "thumb_nonce": "base64"
  }
}
```
