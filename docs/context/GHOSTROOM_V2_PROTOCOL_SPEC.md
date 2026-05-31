# GHOSTROOM V2 PROTOCOL & PRODUCT SPECIFICATION

This document serves as the definitive source of truth for all GhostRoom V2 architectural, cryptographic, and product design decisions.

---

## SECTION 1 — IDENTITY MODEL

GhostRoom V2 shifts from ephemeral, symmetric-only keys to a persistent, deterministic asymmetric identity model. 

### Identity Lifecycle

*   **Creation**: Upon first launch, the client generates 24 bytes of high-entropy randomness, encoded as a standard 24-word BIP39 mnemonic seed phrase. From this seed, two deterministic keypairs are derived:
    *   **Ed25519 Keypair**: Used for signing and deriving the Public ID.
    *   **X25519 Keypair**: Used for `crypto_box` authenticated encryption.
    *   **Public ID**: The Base58 encoding of the Blake2b hash of the Ed25519 Public Key.
*   **Restore**: The user enters their 24-word seed phrase. The application deterministically re-derives the exact Ed25519 and X25519 keypairs and Public ID.
*   **Export**: The user can view their 24-word seed phrase in the Settings screen (protected by biometric authentication).
*   **Import**: Same flow as Restore.
*   **Deletion**: The user triggers "Wipe Identity". The application deletes all keys from Flutter Secure Storage, wipes the local SQLite/Hive database of contacts and messages, and issues an optional `ZREMRANGEBYRANK` clear command to their inbox on the active relay.
*   **Rotation**: Identity rotation is not natively supported in V2. If a key is compromised, the user must generate a new identity and distribute a new Identity Package.

### Lifecycle Scenarios

**App Installed (First Time)**
```text
Launch -> Generate 24-word Seed -> Derive Keys -> Hash Public ID -> Save to Secure Storage -> Ready
```

**App Reinstalled / Data Cleared**
```text
Launch -> Check Secure Storage (Empty) -> Prompt: "Create New" or "Restore" -> User Restores Seed -> Re-derive Keys -> Connect to Relay -> Fetch Queued Messages -> Ready
```

---

## SECTION 2 — IDENTITY PACKAGE SPECIFICATION

The Identity Package is the shareable artifact that allows two users to establish a secure Direct Messaging channel. 

### Schema

```json
{
  "v": 1,
  "eid": "base64(ed25519_pub)",
  "xid": "base64(x25519_pub)",
  "r": ["wss://relay.example.com"],
  "s": "base64(signature)"
}
```

*   **Mandatory Fields**: 
    *   `v` (Version): Protocol version integer (currently `1`).
    *   `eid` (Ed25519): Base64 encoded Ed25519 public key (32 bytes).
    *   `xid` (X25519): Base64 encoded X25519 public key (32 bytes).
*   **Optional Fields**:
    *   `r` (Relays): A list of the user's preferred WebSocket relays for receiving messages. If omitted or empty, assumes the sender's current relay.
*   **Future Fields (Extensibility)**:
    *   `p` (Profile): Encrypted metadata (nickname, avatar hash) that can only be decrypted once the connection is established.
    *   `e` (Expiry): Unix timestamp indicating when the package becomes invalid.

**Signature (`s`)**:
The entire JSON object (excluding the `s` key) is stringified (minified, sorted keys) and signed by the `eid` private key. This prevents tampering with the preferred relays or swapping the `xid` in transit.

---

## SECTION 3 — CONTACT MODEL

GhostRoom operates **without a central user registry**. All contacts are stored strictly locally on the user's device (e.g., using Hive or encrypted SQLite).

*   **Can users delete contacts?** Yes. Deleting a contact removes their Public ID and keys locally, effectively ignoring future messages from them.
*   **Can contacts be renamed locally?** Yes. Because there are no global profiles, the user sets a local alias (e.g., "Alice") when importing the Identity Package.
*   **Can contacts have notes?** Yes, local notes can be attached to the contact record.
*   **Can contacts exist without registry presence?** Yes, the relay acts purely as a dumb post office box (`inbox:{public_id}`). It has no concept of "users" or "contacts".

---

## SECTION 4 — DISCOVERY MODEL

Since there is no global registry to query for usernames, users must exchange Identity Packages out-of-band (OOB).

*   **Primary Method**: **QR Code.** Scanning an Identity Package QR code in person is the most secure method, mathematically defeating remote Man-In-The-Middle (MITM) attacks.
*   **Secondary Method**: **Deep Links.** (`ghostroom://add?pkg=base64url(...)`). Easy to send over Signal, SMS, or Discord.
*   **Fallback Method**: **Manual Import.** Copy-pasting the raw Base64 string into the app.

---

## SECTION 5 — MULTI DEVICE STRATEGY

**Recommendation**: **Single-Device Identity.**

*   **Why Single-Device?** True multi-device E2EE (e.g., Signal's Sesame algorithm) requires maintaining pairwise sessions between *every* device of *every* participant, complex message fan-out logic, and synchronized read receipts. GhostRoom's value proposition is simplicity and absolute ephemerality. 
*   **Impact**: A 24-word seed should only be active on one device at a time. If a user restores their seed on a Tablet, messages fetched by the Tablet will be `ACK`'d and deleted from the Redis queue, meaning the Phone will never see them. 
*   **Future Scope**: Multi-device can be explored in V3 if required, but V2 will enforce a 1:1 Identity-to-Device mapping.

---

## SECTION 6 — MESSAGE STATE MACHINE

```text
CREATED (User taps send)
   ↓
ENCRYPTED (Libsodium box applied)
   ↓
QUEUED (Sent to Relay, stored in Redis ZSET)
   ↓
DELIVERED (Recipient fetches ZSET)
   ↓
ACKNOWLEDGED (Recipient sends ZREM to Relay -> Message deleted from Server)
   ↓
DECRYPTED (Local storage, visible in UI)
   ↓
VIEWED (User opens thread / taps message)
   ↓
DELETED (Self-destruct timer expires -> Wiped from local disk)
```

**Failure Paths**:
*   **Network Offline**: Stays in `CREATED`, auto-retries when Socket.IO reconnects.
*   **Decryption Failure**: Invalid signature or corrupt payload. Client silently drops it and sends an `ACK` to remove the poison pill from the server queue.

---

## SECTION 7 — MESSAGE RETENTION POLICY

*   **Default Retention**: 7 days.
*   **Maximum Server Retention**: 14 days. The backend will run a cron/interval to `ZREMRANGEBYSCORE` messages older than 14 days.
*   **Queue Overflow**: Maximum 100 messages per `inbox:{public_id}`. Enforced via `ZREMRANGEBYRANK` dropping the *oldest* messages (FIFO) when the queue exceeds 100.
*   **View Once Behavior**: If a message is flagged as "View Once", the UI removes the payload from local memory and local database immediately upon the user navigating away from the chat view.
*   **Unacknowledged Messages**: Dropped silently by the server after the 14-day maximum retention.

---

## SECTION 8 — RELAY FEDERATION

GhostRoom V2 relies on **Client-Side Federation (Multi-Homing)** rather than Server-to-Server federation.

*   **Can identities move between relays?** Yes. An identity is tied to cryptography, not a server. A user can update their preferred relay and generate a new Identity Package QR code.
*   **Can relays federate?** No. Servers do not talk to servers. 
*   **Design**: If Alice uses Relay A, and Bob uses Relay B, Alice's client maintains a primary WebSocket to Relay A for her own inbox, and dynamically opens a socket or issues an HTTP POST to Relay B specifically to drop messages into Bob's inbox.

---

## SECTION 9 — ANTI SPAM MODEL

Without phone numbers or emails, spam prevention shifts to a trust-based and rate-limited model.

*   **Strict "Message Requests" Inbox**: If the relay delivers a message, the client decrypts the envelope and reads the Sender's Public ID. If the Sender is NOT in the local Contact Database, the message is placed in a hidden "Message Requests" queue.
*   **Server Rate Limits**: The NestJS gateway enforces strict IP-based rate limiting for the `message.send` event.
*   **Queue Caps**: The 100-message cap per Public ID prevents an attacker from exhausting Redis memory by spamming a single inbox.
*   **Final Strategy**: Client-side filtering. The server accepts validly formatted envelopes, but the recipient's device silently drops or quarantines messages from unknown public keys.

---

## SECTION 10 — PRIVACY ANALYSIS

GhostRoom is designed to leak absolute minimal metadata to the central relay.

| Metadata | Current Visibility | V2 Mitigation Strategy |
| :--- | :--- | :--- |
| **Recipient ID** | Visible (Routing requirement) | Cannot be eliminated. Required to find the `ZSET`. |
| **Sender ID** | Visible in V1 | **Eliminated.** In V2, the Sender's Public ID is placed *inside* the encrypted `libsodium` envelope. The relay only knows "Someone sent a payload to Alice". It does not know it was Bob. |
| **Message Size** | Visible | **Reduced.** Clients should pad all payloads to fixed increments (e.g., 1KB, 5KB) before encryption to obfuscate message content size. |
| **Timestamp** | Visible | Required for queue ordering (`ZSET` score). |
| **IP Address** | Visible | The relay needs the IP for the TCP connection. Users requiring high anonymity should connect to the relay via Tor or a VPN. GhostRoom servers should be configured to disable access logs. |

---

## SECTION 11 — THREAT MODEL V2

| Threat | Impact | Mitigation |
| :--- | :--- | :--- |
| **Identity Theft (Local Malware)** | Attacker steals seed phrase | Store keys exclusively in OS-backed Secure Enclaves (Keystore/Keychain). Require Biometric Auth to view the seed phrase in the app. |
| **Device Theft** | Physical access to decrypted messages | Rely on OS-level device encryption. Implement an optional in-app PIN code. |
| **Fake Identity Package (MITM)** | Attacker substitutes keys in transit | **Safety Numbers.** Clients can view a hash of the combined Ed25519 keys to compare out-of-band over a trusted channel. |
| **Relay Compromise** | Server logs metadata or drops messages | Sender anonymity (Sender ID hidden in envelope). E2EE ensures zero content visibility. Client multi-homing allows switching relays if one goes rogue. |
| **Replay Attacks** | Attacker replays an intercepted payload | Libsodium `crypto_box` utilizes unique nonces. Clients maintain a rolling cache of recent message IDs; duplicates are dropped. |

---

## SECTION 12 — CRYPTOGRAPHIC PROTOCOL SPEC

**Primitives**:
*   `crypto_box` (X25519, XSalsa20, Poly1305) for authenticated asymmetric encryption.
*   `crypto_sign` (Ed25519) for identity authentication.

**Envelope Construction Sequence (Sender)**:
1.  **Construct Plaintext**: `{"id": "msg_uuid", "text": "Hello", "sender_eid": "base64(ed25519)", "sender_xid": "base64(x25519)"}`
2.  **Sign Plaintext**: Sender signs the plaintext using their Ed25519 Secret Key.
3.  **Combine**: `Payload = Signature Bytes + Plaintext Bytes`.
4.  **Encrypt**: Generate a random 24-byte nonce. Encrypt the `Payload` using `crypto_box_easy(message: Payload, nonce: nonce, publicKey: Recipient_X25519, secretKey: Sender_X25519)`.
5.  **Transmit to Relay**: `{"target_id": "Recipient_Public_ID", "nonce": "base64", "ciphertext": "base64"}`

**Envelope Processing Sequence (Recipient)**:
1.  **Fetch**: Receive payload from Relay.
2.  **Decrypt**: `crypto_box_open_easy(ciphertext, nonce, Sender_X25519, Recipient_X25519)`. *(Note: Recipient must attempt decryption against known contact X25519 keys until one succeeds, or use a slightly modified anonymous box construction).*
3.  **Verify**: Extract the Signature and Plaintext. Verify the Signature against the `sender_eid` provided inside the payload.
4.  **Accept**: Display message in UI.

---

## SECTION 13 — FAILURE SCENARIOS

*   **Relay Offline**: UI displays a subtle amber "Connecting..." indicator. Messages queued in local SQLite `outbox` table until connection restores.
*   **Invalid Signature / Decryption Failure**: Message is entirely discarded. A generic `ACK` is sent to the relay to clear the bad data from the queue and prevent infinite fetch loops.
*   **Lost Seed**: If the user loses their device and their 24-word seed, the identity is mathematically dead. The UI provides no recovery option. 
*   **Expired Message**: The server silently drops it. The recipient never knows it existed.

---

## SECTION 14 — VERSIONING STRATEGY

Protocol flexibility is handled via explicit integer versioning at two layers:
1.  **Identity Package Version (`v: 1`)**: Allows future changes to key algorithms (e.g., migrating to Post-Quantum algorithms).
2.  **Message Payload Version (`version: 1`)**: Included inside the plaintext JSON payload before encryption. Allows the internal structure of messages (adding attachments, reply threads) to evolve without breaking older clients.

Unknown versions should prompt the user: "You received a message from a newer version of GhostRoom. Please update your app."

---

## SECTION 15 — FINAL ARCHITECTURE DECISION RECORD

1.  **Should GhostRoom use a registry?**
    **NO.** A central registry creates a honeypot, invites username squatting, and breaks decentralization. Peer-to-peer package exchange is mandatory.
2.  **Should GhostRoom use Redis only?**
    **YES.** Relays should remain completely stateless across restarts if necessary. Redis ZSETs provide perfect, low-latency ephemeral queues without the overhead of PostgreSQL.
3.  **Should GhostRoom support multi-device identities?**
    **NO.** V2 will enforce single-device E2EE to maintain protocol simplicity and ensure absolute offline delivery reliability. 
4.  **Should GhostRoom support relay federation in V2?**
    **NO.** Server-to-server federation introduces immense complexity (spam routing, trust lists). V2 utilizes Client-Side Multi-Homing, where the app connects to the recipient's preferred relay directly.
5.  **Should GhostRoom require fingerprint verification?**
    **YES.** To prevent MITM attacks on deep links, users must have a UI to compare Safety Numbers (Ed25519 hashes).
6.  **Should GhostRoom use seed phrases?**
    **YES.** 24-word BIP39 seeds provide a standard, robust, paper-backup method for identity restoration, replacing the current random key generation.
7.  **Should GhostRoom keep room mode?**
    **YES.** "Dual Mode" is essential. V1 Ephemeral Spaces (symmetric, URL-based) serve a different use case than V2 Direct Messaging (asymmetric, Identity-based). They share the relay infrastructure but use different UI and cryptographic paths.
8.  **Should direct messaging become primary?**
    **YES.** Direct messaging represents the core retention loop. Ephemeral spaces will become a secondary feature ("Create a Temporary Space").
