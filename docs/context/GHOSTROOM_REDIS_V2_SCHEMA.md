# GHOSTROOM REDIS V2 SCHEMA

This document defines the Redis data structures and operational policies for GhostRoom V2 Direct Messaging and Offline Queues.

---

## 1. INBOX STRUCTURE

**Key Pattern**: `inbox:{public_id}`
**Data Type**: `ZSET` (Sorted Set)
**Score**: `timestamp` (Unix Milliseconds)
**Value**: `JSON Envelope`

### Envelope Schema (JSON String)
```json
{
  "id": "uuid_v4",
  "t": 1622510000000,
  "n": "base64_nonce",
  "c": "base64_ciphertext",
  "v": 1
}
```

---

## 2. DELIVERY & ACK STATE

GhostRoom V2 moves away from absolute queue purging.

### FLOW:
1.  **SEND**: `ZADD inbox:{recipient_id} {timestamp} {envelope}`
2.  **FETCH (Client)**: `ZRANGEBYSCORE inbox:{my_id} {last_sync_t + 1} +inf`
3.  **ACK (Client)**: `ZREM inbox:{my_id} {envelope}`
4.  **DELETE**: Handled via explicit `ACK` from client or TTL expiration.

---

## 3. RETENTION POLICY

*   **Default Expiry**: 14 days.
*   **Mechanism**: The server will periodically run `ZREMRANGEBYSCORE inbox:{id} -inf {now - 14 days}`.
*   **Volatile Inboxes**: Each `ZADD` should be followed by an `EXPIRE inbox:{id} 1209600` (14 days) to ensure unused inboxes eventually disappear.

---

## 4. QUEUE CAPS (ANTI-SPAM)

*   **Max Depth**: 100 messages per inbox.
*   **Enforcement**: Every `ZADD` is followed by `ZREMRANGEBYRANK inbox:{id} 0 -101`.
*   **Rationale**: Prevents Redis memory exhaustion from malicious spam or abandoned identities.

---

## 5. MEDIA METADATA STORAGE

Encrypted media (images/videos) are stored in Cloudflare R2. Redis stores only the short-lived mapping for recent transfers if needed, but primary metadata remains inside the encrypted E2EE message envelope.

**Key Pattern**: `media:{media_id}`
**Data Type**: `HASH`
**TTL**: 24 hours (Ephemeral transfer window)

---

## 6. CLEANUP JOBS

The NestJS backend will implement a `CleanupService` running:
*   **Hourly**: Scan all active inboxes and prune messages older than 14 days.
*   **On-Demand**: Prune depth during every message delivery.

---

## 7. BACKWARD COMPATIBILITY

*   **V1 Rooms**: Continue using `room:{id}` (STRING) and `msgs:{roomId}` (LIST).
*   **Collision Prevention**: `inbox:` prefix is reserved for V2 ZSETs. `msgs:` prefix remains reserved for V1 LISTs.
