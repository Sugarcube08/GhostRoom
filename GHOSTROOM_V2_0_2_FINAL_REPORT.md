# GhostRoom V2.0.2 Final Release Report

## Objective
Address critical flaws in background message delivery (FCM wake-ups for terminated/closed applications) and clean up user directory structure by implementing strict storage isolation and database migration.

---

## Technical Audit of Fixes

### 1. Backend: High-Priority FCM Wake-Up Dispatch
*   **Problem:** FCM messages were sent without platform-specific priority and background headers, causing Android and iOS to throttle or discard push notifications when the app was in a terminated state.
*   **Fix:** Refactored the payload in `sendFcmWakeup` within `inbox.service.ts` to explicitly configure high priority on Android (`priority: 'high'`) and silent background delivery headers on iOS (`apns-priority: '5'`, `apns-push-type: 'background'`).
*   **Diagnostics:** Added detailed console logs on incoming messages, device lookup status, FCM send triggers, and direct Google FCM API response status codes.

### 2. Client: Background Isolate Notification Initialization
*   **Problem:** Incoming messages fetched during background sync did not show notifications because the `NotificationService` instance inside the background isolate was never initialized.
*   **Fix:** Explicitly called `await notifService.init();` inside `ghostRoomBackgroundHandler` in `main.dart` prior to initializing the chat repository and sync flow.

### 3. Client: Android manifest Configurations
*   **Problem:** Android 13+ requires explicit permissions to post notifications, which was missing in the manifest, and background MESSAGING_EVENT intent receivers were not registered.
*   **Fix:** Added `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` in the main manifest. Verified that the `firebase_messaging` plugin's main service is merged cleanly without conflicts.

### 4. Client & Desktop: Storage Isolation & Clean Migration
*   **Problem:** Operational databases (`.hive`), cached media, and flags were created directly in the user-visible `Documents` folder, polluting the home directory on Desktop.
*   **Fix:**
    *   Created `StorageDirectoryHelper` to redirect all app paths to the dedicated sandboxed `ApplicationSupportDirectory/GhostRoom/`.
    *   Added `migrateIfNeeded()` to automatically copy and delete legacy databases/folders from the user's `Documents` directory upon application startup, preserving user data without loss.
    *   Guarded FCM token calls on Desktop environments to avoid uninitialized Firebase app crashes.

---

## Versioning & Metadata
- **Pubspec Version:** `2.0.2+1`
- **Manifest Version:** `2.0.2`
- **Backend Package Version:** `2.0.2`
- **Core Stability:** Production-ready background delivery and clean sandboxing.

**GhostRoom V2.0.2 delivers Telegram/WhatsApp-grade push reliability while maintaining absolute user-privacy standards.**
