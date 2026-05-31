# GHOSTROOM PHASE 9: ABUSE RESISTANCE & RESOURCE PROTECTION

This document defines the operational limits and abuse resistance mechanisms required to protect the GhostRoom durable relay from resource exhaustion and spam.

---

## 1. IDENTITY-BASED RATE LIMITS

Because GhostRoom operates without accounts, phone numbers, or email addresses, malicious actors can generate thousands of identities. To protect the relay, strict per-identity (Public ID) rate limits are enforced at the WebSocket Gateway using Redis.

**Message Sending Quotas (Per Sender ID)**:
*   **Hourly Limit**: 50 messages per hour.
*   **Daily Limit**: 500 messages per 24 hours.

**Media Upload Quotas (Per Sender ID)**:
*   *Already implemented in Phase 6*: 100MB / 50 uploads per day.

**Enforcement**: 
Redis counters (`rate:msg:hr:{id}`, `rate:msg:day:{id}`) track sender activity. If a limit is exceeded, the server responds with an error and drops the `message.send` request.

---

## 2. PAYLOAD SIZE VALIDATION

To prevent attackers from sending massive JSON payloads that consume PostgreSQL storage and Redis cache memory, the Gateway strictly enforces size limits before processing any message.

*   **V1 Text/Envelope**: 32 KB maximum.
*   **V2 E2EE Envelope**: 64 KB maximum.
*   **Attachment Metadata**: Restricted implicitly by the E2EE envelope size (the metadata is inside the ciphertext).

**Enforcement**:
The NestJS WebSocket Gateway calculates the byte length of the incoming payload. Payloads exceeding these limits are immediately rejected.

---

## 3. INBOX CAPACITY LIMITS

With the introduction of durable `PERSISTENT` retention, abandoned or flooded inboxes represent a permanent storage leak.

*   **Max Pending Messages**: 5000 unacknowledged messages per Recipient Public ID.
*   **Enforcement**: Before a `message.send` operation inserts into PostgreSQL, the server counts the pending messages for the recipient. If the count exceeds 5000, the message is rejected with a `capacity_exceeded` error.

---

## 4. MESSAGE REQUEST QUOTAS (SERVER VS. CLIENT)

Because the relay guarantees **Server Blindness** (it does not know the recipient's contact list), the server cannot mathematically distinguish between a "Known Contact Message" and a "Message Request".

To mitigate request flooding without compromising privacy:

1.  **Sender-Recipient Pair Cap (Server-Side)**:
    *   The backend enforces a maximum of **50 unacknowledged messages** from *any single Sender ID* to a *specific Recipient ID*.
    *   If Alice sends 50 messages to Bob and Bob never ACKs them, Alice cannot send a 51st message to Bob.
    *   This prevents a spammer from filling someone's 5000-message global inbox cap by themselves.

2.  **Request Inbox Cap (Client-Side)**:
    *   The client limits the local "Requests Inbox" UI to display a maximum of 50 pending request threads. Excess requests can be silently ACK'd and dropped by the client to maintain UX clarity.

---

## 5. AUTOMATIC PRUNING

The existing cleanup worker in the backend will be expanded to ensure orphaned records do not accumulate.

*   **Expired Messages**: Handled dynamically during queries and periodically via cleanup scripts.
*   **Dangling Delivery States**: Pruned when the parent message is deleted.

---

## 6. THREAT MITIGATION SUMMARY

| Attack Vector | Defense Mechanism |
| :--- | :--- |
| **Mass Account Creation + Spam** | Per-Identity Hourly/Daily Rate Limits. |
| **Storage Exhaustion via Large Payloads** | 64 KB Envelope Size limit at the Gateway. |
| **Storage Exhaustion via Inbox Flooding** | 5000 Max Pending Messages per Inbox limit. |
| **Targeted Inbox DoS (One sender to one receiver)** | 50 Max Pending Messages per Sender-Receiver pair. |
