# RELEASE NOTES - GhostRoom V2.0.1 (The Reliability Patch)

## Summary
V2.0.1 is a critical stability patch addressing a "blunder" in the message delivery system. This update ensures that messages sent while a recipient is offline or in the background are reliably delivered the moment the app is reopened or resumed.

## 🐞 Critical Fixes

### 📬 Offline Message Delivery
Fixed a major bug in the relay's inbox fetching logic. Previously, messages sent to a specific user without a device ID (global messages) were being filtered out if the recipient registered with a specific device ID. 
- **Achievement:** The relay now correctly aggregates global and device-specific messages into a single delivery stream.

### 🔄 Proactive Background Sync
Implemented a "Resume-to-Sync" trigger on the client. 
- **Achievement:** GhostRoom now automatically triggers an inbox refresh whenever the app returns from the background (Foreground Resume), ensuring missed real-time events are captured immediately.

---

## Evolution: V2.0.0 ➔ V2.0.1

| Feature | V2.0.0 | V2.0.1 |
| :--- | :--- | :--- |
| **Offline Sync** | Reactive (Wait for next event) | Proactive (Sync on Resume) |
| **Relay Logic** | Strict Device Match (Buggy) | Hybrid Global/Device Fetch |
| **Stability** | High | Maximum |
| **Version** | 2.0.0 | 2.0.1 |

---

**Download the latest version from:** https://github.com/Sugarcube08/GhostRoom/releases
