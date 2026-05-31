# GHOSTROOM PHASE 3: BACKEND IDENTITY INBOXES DESIGN (UPDATED)

This document outlines the corrected implementation plan for V2 identity-based inboxes.

---

## 1. SOCKET EVENTS (GATEWAY)

### `identity.challenge` (Server -> Client)
*   **Trigger**: Sent by server upon client connection or `inbox.fetch` attempt from unauthenticated socket.
*   **Payload**: `{"nonce": "32_byte_hex_string"}`
*   **Behavior**: Server stores nonce in Redis `challenge:{socket_id}` with 60s TTL.

### `identity.prove` (Client -> Server)
*   **Payload**: 
    ```json
    {
      "public_id": "Base58_ID",
      "public_key": "Base64_Ed25519_PK",
      "signature": "Base64_Signature"
    }
    ```
*   **Behavior**:
    1. Retrieve nonce from `challenge:{socket_id}`.
    2. Verify `derivePublicId(public_key) == public_id`.
    3. Verify `signature` of `nonce` using `public_key`.
    4. Bind `socket.id -> public_id` in Gateway session state.
    5. Emit `identity.verified` to client.

### `inbox.fetch`
*   **Requirement**: Authenticated Socket (Session must have bound `public_id`).
*   **Payload**: `{"since": timestamp_ms}`
*   **Behavior**:
    1. Retrieve `message_ids` from `inbox:{public_id}` ZSET where score > `since`.
    2. Batch fetch actual envelopes from `msg:{message_id}` keys.
    3. Return array of envelopes.
    4. Socket joins room `inbox:{public_id}` for live relay.

### `message.send` (Dual-Mode)
*   **Payload**: `{"target_id": "ID", "v": 1 | 2, ...}`
*   **Routing**:
    *   `v == 1`: Route to V1 Space (`msgs:{id}` LIST).
    *   `v == 2`: Route to V2 Inbox (`inbox:{id}` ZSET + `msg:{id}` STRING).

### `message.ack`
*   **Payload**: `{"message_id": "uuid"}`
*   **Behavior**: 
    1. `ZREM inbox:{authenticated_id} {message_id}`.
    2. `DEL msg:{message_id}`.

---

## 2. REDIS OPERATIONS (V2)

| Action | Command | Pattern |
| :--- | :--- | :--- |
| **Queue Reference** | `ZADD` | `inbox:{public_id} {timestamp} {message_id}` |
| **Store Data** | `SETEX` | `msg:{message_id} 1209600 {envelope_json}` |
| **Acknowledge** | `ZREM` | `inbox:{public_id} {message_id}` |
| **Cleanup Data** | `DEL` | `msg:{message_id}` |

---

## 3. MESSAGE ENVELOPE SCHEMA (V2)

```json
{
  "id": "uuid_v4",
  "t": 1622510000000,
  "n": "base64_nonce",
  "c": "base64_ciphertext",
  "v": 2
}
```

---

## 4. COEXISTENCE STRATEGY

*   **V1**: Anonymous UUID-based LISTs. Destructive `LRANGE+DEL` on join.
*   **V2**: Authenticated PublicID-based ZSETs. Cursor-based fetch + Explicit ID-based ACK.
*   The `RelayGateway` will switch logic entirely based on the `v` (version) field in incoming payloads.

