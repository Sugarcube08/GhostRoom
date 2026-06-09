# GhostRoom V2.1.1 Release Notes

Welcome to GhostRoom V2.1.1! This release introduces critical storage directory isolation, automated data migration, and major enhancements to Firebase Cloud Messaging (FCM) background wakeup reliability.

---

## Key Features & Updates

### 1. Storage Isolation & Dedicated Directory (Centralization)
To comply with privacy standards and avoid polluting user-visible directories on desktop systems:
*   **Centralized Support Path**: Changed all local storage targets (Hive databases, encryption keys, logs, cached media, and identity flags) to reside under a sandboxed system folder:
    *   **Desktop/Linux**: `~/.local/share/com.ghostroom.app/GhostRoom/`
    *   **Android/iOS**: App-specific support sandboxes.
*   **One-Time Automated Migration**: Integrated a robust migration pipeline (`StorageDirectoryHelper.migrateIfNeeded()`) running on startup. It automatically transfers existing `.hive`/`.lock` boxes, the `identity_exists.flag`, and the `media/` directory from the old `Documents` folder to the new centralized folder without any data loss.
*   **Clean Workspace**: Completely stopped writing database files directly inside the user's `Documents` or project execution roots.

### 2. FCM Wakeup & Background Message Delivery Reliability
Addressed offline/background message delivery failures (e.g., when the app is swiped away or terminated):
*   **High-Priority Push Payload**: Configured the backend's FCM wake-up request with high-priority headers for Android (`priority: 'high'`) and silent background headers for iOS APNs (`content-available: 1`, `apns-priority: 5`, `apns-push-type: 'background'`) to bypass OEM process killing (e.g., on Realme, Oppo, Xiaomi devices).
*   **Android Manifest Registrations**: Added `android.permission.POST_NOTIFICATIONS` permission for Android 13+ and registered `FlutterFirebaseMessagingService` in `AndroidManifest.xml` to handle system messaging event broadcasts in a terminated state.
*   **Background Isolate Support**: Added explicit `NotificationService` initialization inside the background isolate handler (`ghostRoomBackgroundHandler`) so local notifications successfully render when background sync triggers.
*   **Desktop Guard**: Prevented Firebase Messaging token retrieval from running on Linux/Windows/macOS, resolving uninitialized Firebase app crashes on desktop.

### 3. End-to-End Trace Instrumentation
Added logs to track the message wakeup chain step-by-step:
*   **Backend Logs**: Logs `MESSAGE_RECEIVED`, `DEVICE_LOOKUP`, `FCM_SEND_START` (with payload contents), and `FCM_RESPONSE` (showing HTTP statuses, messages, or errors from Firebase).
*   **Client Logs**: Prints `FCM_TOKEN_GENERATED`, `FCM_FOREGROUND_RECEIVED`, `FCM_OPENED_APP`, and `BACKGROUND_HANDLER_STARTED` to ADB console.

---

## Upgrade Actions

### Backend
1.  Verify the environment variables (`FIREBASE_PROJECT_ID` and `FCM_SERVER_KEY`) are set correctly.
2.  Deploy the backend codebase.

### Client
1.  Deploy manifest and dart code changes.
2.  Ensure build triggers clean compilation:
    ```bash
    flutter build apk --debug
    ```
