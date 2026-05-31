# GHOSTROOM V2 MIGRATION READINESS AUDIT

## SUMMARY

GhostRoom is transitioning from anonymous, ephemeral rooms to persistent, identity-based direct messaging while maintaining backward compatibility with V1.

---

## MIGRATION STRATEGY: DUAL MODE

The system will route based on the format of the target identifier:
*   **UUID v4**: Routes to V1 Space logic (Redis LIST, Symmetric).
*   **Base58 Hash**: Routes to V2 Inbox logic (Redis ZSET, Asymmetric).

---

## REUSABLE COMPONENTS
*   WebSocket infrastructure.
*   Relay profile management.
*   Libsodium initialization.

## COMPONENTS REQUIRING REDESIGN
*   Redis structure (LIST -> ZSET).
*   Delivery model (Atomic DEL -> Explicit ACK).
*   Message flow (Symmetric -> Asymmetric Authenticated).
