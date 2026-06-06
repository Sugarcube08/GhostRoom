# GhostRoom V2.0.1 Final Release Report

## Objective
Address critical flaws in message delivery and notification reliability when the application is in a background or offline state.

---

## Technical Audit of Fixes

### 1. Backend: Unified Inbox Query
**Problem:** The `fetchMessages` query in `inbox.service.ts` used a strict equality check for `recipient_device_id`. If a message was queued for a user's global inbox (null device ID) but the user's client registered with a specific `deviceId`, the message would be excluded from the sync results.
**Fix:** Refactored the TypeORM query to use an `OR` condition that explicitly includes messages where `recipient_device_id` is either the requesting device's ID OR `NULL`.
**Status:** ✅ Verified. All offline messages are now included in the sync batch.

### 2. Client: Lifecycle Observer Sync
**Problem:** The client relied on the WebSocket's `onIdentityVerified` event to trigger an inbox sync. If the socket connection persisted while the app was in the background but events were missed (due to OS throttling), the user would see no new messages upon opening the app until a *new* socket event occurred.
**Fix:** Implemented `WidgetsBindingObserver` in `ChatRepository`. The app now detects the `AppLifecycleState.resumed` state (Foreground Resume) and manually invokes `fetchInbox` using the `lastSyncTimestamp`.
**Status:** ✅ Verified. Returning to the app now forces a proactive check for missed messages.

---

## Versioning & Metadata
- **Pubspec Version:** `2.0.1+1`
- **Manifest Version:** `2.0.1`
- **Core Stability:** Hardened for real-world background usage.

**GhostRoom V2.0.1 restores full trust in message delivery durability.**
