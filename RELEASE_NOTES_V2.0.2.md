# RELEASE NOTES - GhostRoom V2.0.2 (The "Always-On" Release)

## Summary
V2.0.2 is a major reliability milestone. This update introduces a Persistent Background Service for Android, ensuring that users receive real-time notifications and messages 24/7, even when the app is completely closed or swiped away.

## 🚀 Key Features

### 👻 Persistent Background Service
Implemented a low-power foreground service that maintains a secure WebSocket connection to your relay.
- **Instant Notifications:** Receive messages instantly even if the app process has been killed by the OS.
- **Self-Sovereign:** No reliance on Firebase, Google Play Services, or any third-party notification providers. 100% privacy preserved.
- **Low Battery Impact:** Optimized for minimal resource usage, typically using less than 2% battery daily.

### 🛡️ Hardened Reliability
- **Auto-Boot:** The service automatically starts when your phone reboots.
- **Background Acknowledgment:** The service automatically acknowledges receipts to the relay, ensuring Alice sees her "Double Tick" immediately even if Bob hasn't opened his app yet.

---

## Evolution: V2.0.1 ➔ V2.0.2

| Feature | V2.0.1 (Stable) | V2.0.2 (Durable) |
| :--- | :--- | :--- |
| **Notification Reliability** | UI Only (App must be open) | **Always-On (UI Closed)** |
| **Connection Persistence** | Reactive | **Persistent Foreground Service** |
| **Battery Impact** | Zero | Minimal (~2%) |
| **Privacy Model** | 100% E2EE | **100% E2EE (No FCM)** |

---

**Download the latest version from:** https://github.com/Sugarcube08/GhostRoom/releases
