# GHOSTROOM PHASE 7: TRUST LAYER DESIGN

This document specifies the Trust Layer, which governs how messages and media from anonymous identities are handled to prevent spam, storage exhaustion, and abuse.

---

## 1. MESSAGE REQUESTS

GhostRoom operates without a central registry, meaning anyone with a Public ID can send an envelope to that inbox. To protect the user:
*   Inbound messages from unknown Public IDs are placed in a **Requests Inbox**.
*   The user is not notified via push or disruptive badges for requests.
*   The UI separates "Chats" (Known Contacts) from "Requests" (Unknown).

---

## 2. BLOCK LISTS

A local, client-side block list is maintained (`blocked_identities` Hive box).
*   **Format**: List of Base58 Public IDs.
*   **Scope**: Blocking is strictly local. The relay is never informed that an ID is blocked, preserving the recipient's privacy and preventing attackers from enumerating block lists.

---

## 3. AUTO ACCEPT RULES

An incoming message bypasses the Requests Inbox and goes directly to the main Chats list **IF AND ONLY IF**:
*   The `sender_public_id` exists in the local **Contact Database**.

---

## 4. AUTO REJECT RULES

An incoming message is silently dropped **IF**:
*   The `sender_public_id` exists in the **Block List**.

**Behavior**:
1.  Verify Signature (to prevent spoofed blocks).
2.  Check Block List.
3.  Send `message.ack` to the relay to clear the queue.
4.  Silently discard the payload (Do NOT store in the local database).

---

## 5. ATTACHMENT DOWNLOAD POLICY

To prevent an attacker or even a trusted contact from filling the device's storage with massive files:
*   **Default Policy**: `MANUAL`.
*   **Behavior**: When a message containing an `AttachmentEnvelope` is received, the client stores the envelope metadata but **DOES NOT** fetch the R2 blob.
*   **UX**: The UI renders a "Download Attachment (Size)" button. Only upon user interaction does the client download the blob, decrypt it, verify the SHA256 hash, and render it.

---

## 6. UNKNOWN SENDER HANDLING & MEDIA RESTRICTIONS

To severely limit the financial and storage impact of spam:
*   **Allowed from Unknown Senders**: Text messages only.
*   **Blocked from Unknown Senders**: Image, Video, File, Voice.
*   **Enforcement**: If a message payload from an unknown sender contains an `AttachmentEnvelope`, the client sends an `ACK` to the relay and **drops the message entirely**. 
*   **Rationale**: Attackers cannot force the recipient to download or acknowledge a 30MB video payload to get into their request inbox.

---

## 7. SPAM PREVENTION SUMMARY

| Vector | Defense |
| :--- | :--- |
| **Relay Storage Abuse** | 100MB daily quota + 100 message depth limit. |
| **Device Storage Abuse** | Manual attachment download policy. |
| **Media Spam** | Drop attachments from unknown senders entirely. |
| **Harassment** | Silent Auto-Reject via Block List. |

---

## 8. CONTACT PROMOTION FLOW

The lifecycle of an unknown interaction:

```text
Message Received (Text)
       ↓
Identify: Unknown Sender
       ↓
Route to Requests Inbox
       ↓
User Reviews Request
       ↓
[ ACCEPT ] -> Adds to Contacts -> Moves to Chats Inbox -> Media now allowed.
[ REJECT ] -> Deletes thread. Future messages go back to Requests.
[ BLOCK ]  -> Adds to Block List. Future messages Auto-Rejected.
```

---

## 9. UX FLOWS

### Requests View
*   A banner or row at the top of the `ChatsScreen` indicating "Message Requests (X)".
*   Tapping opens a list of conversations from unknown Public IDs.

### Request Thread View
*   Displays the text messages sent by the unknown user.
*   A persistent bottom bar replaces the text input field:
    *   **[ BLOCK ]** (Red)
    *   **[ DELETE ]** (Grey)
    *   **[ ACCEPT ]** (Green)
*   The user cannot reply until they `ACCEPT`.

---

## 10. PROTOCOL ADDITIONS

No changes to the backend or E2EE envelope are required for this phase. All Trust Layer enforcement happens strictly on the client side during the `decrypt -> verify -> store` pipeline in the `ChatRepository`.
