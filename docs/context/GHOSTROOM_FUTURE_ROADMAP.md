# GHOSTROOM V2.0.1 POLICIES & FUTURE ROADMAP

This document clarifies the operational constraints of the current release and outlines the migration path for V3.

---

## 1. MULTI-DEVICE POLICY (V2.0.1)

GhostRoom V2.0.1 enforces a **Single-Device Identity** policy.

*   **Constraint**: While an identity can be restored on multiple devices using the 24-word seed phrase, they share the same inbox queue.
*   **Behavior**: When Device A fetches and acknowledges a message, the relay deletes it from the durable store. Device B will never receive that message.
*   **Recommendation**: Users should only maintain their active identity on one primary device. Secondary devices should use separate identities.
*   **Future (V3)**: Multi-device synchronization will be introduced using the Sesame algorithm or a fan-out delivery model.

---

## 2. RELAY FEDERATION PATH

The current architecture supports **Client-Side Multi-Homing** (federation via the client).

*   **Current State**: Users specify `preferred_relays`. Senders connect to the recipient's relay to deliver messages.
*   **Migration Path to V3 (Server-to-Server)**:
    *   **Registry**: A DHT (Distributed Hash Table) or federated registry will be added to allow relays to look up a Public ID's home server.
    *   **Relay Peering**: Relays will implement authenticated peering to forward envelopes when a client is offline, reducing the need for clients to maintain multiple socket connections.

---

## 3. V3 EVOLUTION PRIORITIES

The natural evolution of GhostRoom follows this priority order:

1.  **Voice Notes**: Utilizing the existing media transport pipeline.
2.  **Desktop Client**: Cross-platform Flutter desktop support.
3.  **Relay Federation**: Server-to-server forwarding.
4.  **Multi-Device Sync**: Robust session management across N devices.
5.  **Group Messaging**: Multi-identity encrypted rooms.

---

## 4. DESIGN PHILOSOPHY: IDENTITY FIRST

GhostRoom will continue to prioritize **Identity over Groups**. By ensuring the one-to-one messaging layer is bulletproof and durable, the foundation for decentralized communities remains secure and mathematically verifiable.
