# RELEASE NOTES - GhostRoom V2.0.2 (Storage Isolation & Background Wakeup Update)

## Summary
V2.0.2 introduces dedicated local storage sandboxing, zero-data-loss database migration, and highly reliable background message wakeups to align GhostRoom's notification reliability with major platforms like Telegram and WhatsApp.

---

## 🔒 Storage Isolation & Sandboxing
To ensure strict privacy and clean up user folders on Desktop/Mobile, we have isolated all operational databases and cached assets.
- **Centralized Helper:** Introduced [StorageDirectoryHelper](file:///home/sugarcube/Documents/Documents/Code-Server/@PRODUCTS/GhostRoom/client/lib/core/storage/storage_directory_helper.dart) to map all data (Hive, media cache, flag files) under `ApplicationSupportDirectory/GhostRoom/` (`~/.local/share/com.ghostroom.app/GhostRoom/` on Linux).
- **Auto-Migration:** Implemented a robust data migration script. Upon updating, all existing Hive databases, media attachments, and identity flag files are seamlessly moved from the user's `Documents` folder to the isolated directory.

---

## 📬 FCM Background Wakeup Reliability
- **Manifest Updates:** Declared the `POST_NOTIFICATIONS` permission in Android for Android 13+ support.
- **High-Priority Payloads:** Updated the backend FCM dispatch payload to request high priority (`priority: 'high'`) on Android and silent content-available background delivery on iOS (`apns-priority: '5'`, `apns-push-type: 'background'`).
- **Background Isolate Handlers:** Fixed a bug where local notifications failed to show from terminated background isolates by explicitly initializing the notification service inside `ghostRoomBackgroundHandler`.
- **Desktop Guard:** Guarded Firebase Messaging token retrieval on Linux/Desktop client environments to prevent app startup crashes due to missing Firebase components.

---

## 🔍 Full-Chain Diagnostics
Both the backend relay and the client application are now fully instrumented with structured logs to help you trace the entire lifecycle:
*   `MESSAGE_RECEIVED recipient_identity=...` (Backend)
*   `DEVICE_LOOKUP found_token=...` (Backend)
*   `FCM_SEND_START token=...` (Backend)
*   `FCM_RESPONSE success=...` (Backend)
*   `FCM_TOKEN_GENERATED token=...` (Client)
*   `BACKGROUND_HANDLER_STARTED` (Client)
*   `FCM_BACKGROUND_HANDLER_ENTERED` (Client)

---

## Evolution: V2.0.1 ➔ V2.0.2

| Feature | V2.0.1 | V2.0.2 |
| :--- | :--- | :--- |
| **Local Storage Directory** | `Documents/` (Polluted) | `ApplicationSupportDirectory/GhostRoom/` (Sandboxed) |
| **Data Migration** | None | Automatic & Seamless |
| **FCM Priority** | Default (Normal) | Forced High Priority (Wakeup terminated app) |
| **Android 13+ Support** | Basic | Complete (`POST_NOTIFICATIONS` declared) |
| **Background Notifications** | Uninitialized Isolate (Fails) | Initialized Isolate (Succeeds) |
| **Desktop Compatibility** | Crashes on Token Fetch | Safe Guarded (Skips FCM) |

---

**Download the latest version from:** https://github.com/Sugarcube08/GhostRoom/releases
