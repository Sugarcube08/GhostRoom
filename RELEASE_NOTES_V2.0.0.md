# RELEASE NOTES - GhostRoom V2.0.0 (The Stabilization Release)

## What's New

### 🛡️ Stabilization Reset
We have returned to a "known-good" foundation by removing experimental privacy overlays that were causing instability on Linux and other desktop platforms. The result is a lightning-fast, crash-free experience with a significantly reduced memory footprint.

### 🎥 Rebuilt Media Protocol
A complete overhaul of how images, videos, and voice notes are exchanged:
- **Strict State Machine:** Every upload and download now follows a rigorous UPPERCASE state protocol, ensuring no more "stuck" progress bars.
- **Sender-Side Rendering (SSR):** Senders now see their own media instantly from local cache without needing to download it back from the server.
- **Full Trace Logging:** Every step from picking to rendering is now logged with structured `GHOST_LOG` tags for easy auditing.

### ⏱️ Real-Time Message Ticks
Know exactly what's happening with your messages:
- **Single Gray Tick:** Sent to relay.
- **Double Gray Tick:** Delivered to recipient's device.
- **Double Blue Ticks:** Read by the recipient.
- **Seen Duration:** Displays exactly how long ago the message was read (e.g., "2m ago").

### 🚀 Automated Updates
Never miss a security patch or feature update. GhostRoom now automatically checks for new releases on GitHub and provides a one-click "Update Now" prompt that takes you directly to the latest release page.

---

## Achievements Since V1.0.0
Since our initial release as a temporary chatroom app, we have successfully implemented:
- **Permanent Cryptographic Identities** (replacing random nicknames).
- **End-to-End Encryption** for all traffic (No plaintext ever touches the server).
- **Decentralized Relay Support** (Federation between different servers).
- **Multi-Device Sync** (Message fan-out to all your connected devices).
- **Encrypted Media Storage** via Cloudflare R2 / MinIO.
- **Desktop Support** (Stable Linux and Windows builds).

---

## Technical Benchmarks (Linux)
- **Startup RAM:** ~159 MB
- **Idle RAM:** ~162 MB
- **Handshake Latency:** < 200ms

---

**Download the latest version from:** https://github.com/Sugarcube08/GhostRoom/releases
