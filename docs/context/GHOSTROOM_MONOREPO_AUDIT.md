# GHOSTROOM MONOREPO AUDIT

## Section 1 — Repository Overview

The GhostRoom project is structured as a monorepo containing a NestJS backend and a Flutter client application.

*   **Monorepo Structure**: Two primary directories: `backend` and `client`.
*   **Package Manager**: `npm` (Backend), `flutter pub` (Client).
*   **Database**: Redis (Backend), Hive/Secure Storage (Client).

---

## Section 2 — Current Product State

GhostRoom is a privacy-first, ephemeral communication relay.

### Implemented
*   V1 Ephemeral Spaces (Symmetric E2EE).
*   WebSocket relay.
*   Deterministic Identity (V2 Phase 1).
*   Local Contact Management (V2 Phase 2).

---

## Section 3 — Backend Architecture Audit

Built with **NestJS**. Uses `RelayGateway` (Socket.IO) and `RoomsService` (Redis).

---

## Section 15 — Cryptography Audit

*   **V1**: `sodium.crypto.secretBox` (ChaCha20-Poly1305).
*   **V2**: `sodium.crypto.box` (X25519) + `sodium.crypto.sign` (Ed25519).
*   **Server Access**: Zero. The server cannot decrypt any content.
