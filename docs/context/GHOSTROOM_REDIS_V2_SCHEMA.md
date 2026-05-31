# GHOSTROOM REDIS V2 SCHEMA (UPDATED)

## 1. INBOX ZSET
**Key**: `inbox:{public_id}`
**Value**: `message_id` (UUID)
**Score**: `timestamp` (ms)
**TTL**: 14 days (Sliding expiry on ZADD)

## 2. MESSAGE STORE
**Key**: `msg:{message_id}`
**Value**: `JSON Envelope`
**TTL**: 14 days (Strict expiry)

## 3. CHALLENGE STORE
**Key**: `challenge:{socket_id}`
**Value**: `nonce` (32 bytes hex)
**TTL**: 60 seconds

## 4. PERSISTENCE POLICY
*   `message_id` is the source of truth for delivery.
*   ACK must remove both the ZSET entry and the MSG string.
*   Periodic pruning of orphaned `msg:` keys if `ZSET` fetch reveals missing values.
