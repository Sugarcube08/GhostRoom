# GhostRoom V2.1.0 — The UX Rebirth Update 💎

GhostRoom V2.1.0 is here. This release transforms the platform from a sophisticated technical relay into a premium, user-friendly private communication experience. We have completely overhauled the information architecture, navigation, and onboarding to make world-class privacy accessible to everyone.

## ✨ What's New

### 🛡️ The Identity Vault
The settings have been reimagined as your **Identity Vault**.
*   **Security Health Score**: A real-time indicator of your security posture (Seed verified, Backup created, Drill completed).
*   **System Diagnostics**: Real-time status of your connection to the relay, database, and storage.
*   **Actionable Security**: Grouped management of recovery keys, backups, and privacy settings.

### 🛂 Digital Passports (Contacts Redesign)
Connecting with others is now a premium, intuitive experience.
*   **Passport Cards**: A beautiful, high-contrast QR card containing your Identity Package for easy sharing.
*   **Safety Numbers**: Monospace cryptographic fingerprints are front-and-center for out-of-band verification.
*   **Local Social Graph**: Explicit education that your contacts are stored only on your device, never in the cloud.

### 🏎️ Premium Navigation
A new high-performance **Bottom Navigation Shell** brings order to the feature set:
*   **MESSAGES**: Your primary home for active, secure conversations.
*   **CONTACTS**: Your local identity exchange center.
*   **SPACES**: A dedicated home for anonymous, disposable rooms.
*   **VAULT**: Your personal security and identity command center.

### 🎓 Enhanced Onboarding & Recovery Drills
We've made user sovereignty unavoidable:
*   **Educational Flow**: Clearly explains that *you* own your keys and your data.
*   **Mandatory Verification**: You must confirm words from your seed phrase to enter.
*   **Mandatory Backup**: Users are guided to create their first encrypted backup archive immediately.
*   **Recovery Drill**: A final test that simulates a device loss to ensure you are actually prepared to recover your identity.

### ✉️ Advanced Chat Features
*   **Retention Selector**: Toggle between `Persistent`, `Ephemeral` (30 days), and `View Once` modes directly from the composer.
*   **Smart Attachments**: View encrypted file sizes and media types before downloading.
*   **Privacy-First Headers**: Verify identities with a single tap on the conversation header.
*   **Swipe Management**: Accept, block, or delete message requests with simple swipe actions.

---

## 🏛️ Infrastructure & Reliability
*   **Version Alignment**: Backend and Client are now synchronized at V2.1.0.
*   **MinIO Support**: Enhanced local development stack with automated S3-compatible storage setup.
*   **Circular Dependency Resolution**: Refactored backend modules for production-grade stability.

## 📦 Getting Started
1. Pull the latest code and rebuild: `./build_all.sh`.
2. Deploy the updated `docker-compose.yml`.
3. Experience the rebirth of private messaging.

---
*GhostRoom: Encryption is a right. User Experience is the key.*
