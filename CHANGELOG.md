# Changelog

All notable changes to the GhostRoom project are documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.5.0] - 2026-11-20

### Added
- **Dual-Method Cryptographic Identity & Keyfile Login**:
  - Encrypted `.ghostkey` JSON vault generator utilizing **Argon2id** (`crypto_pwhash_argon2id13`) memory-hard key derivation and **XChaCha20-Poly1305-IETF** AEAD authenticated encryption via Libsodium.
  - Interactive onboarding flow prompting users to export and securely save their encrypted `.ghostkey` file alongside their standard 24-word BIP-39 mnemonic passphrase.
  - Dual-unlock login and recovery interface allowing users to authenticate via either raw 24-word passphrase entry or `.ghostkey` file picker with PIN/password decryption.
  - Direct `.ghostkey` vault re-export and native sharing action in Identity Vault settings.
- **Architectural Geometric Design System (Dark-First)**:
  - Strict geometric token palette: Deep Obsidian Void (`#090A0F`), Elevated Slate (`#12141D` / `#1A1D2B`), 1px structural hairline borders (`#1F2333`), High-Contrast Mist (`#F4F6FA`), and Cyber Iris (`#7C5CFF`) active accents.
  - Uniform spatial grid: 8px spatial grid, 12px card border radius, 8px input/button radius, and strict monospace typography (`JetBrains Mono` / `Roboto Mono`) for public IDs, fingerprints, and passphrases.
  - Restructured screen flows for onboarding, chat list, encrypted thread view, digital passport, and settings.
- **Public Landing & Binary Download Portal (NestJS Backend)**:
  - `GET /`: High-contrast public landing page highlighting zero-knowledge architecture, cryptographic key exchange model, and privacy guarantees with content-negotiation (browser HTML vs. JSON health status).
  - `GET /download`: Release distribution portal featuring direct download triggers for Android APK (`ghostroom-android.apk`), Linux Universal AppImage, Debian `.deb`, RPM `.rpm`, and standalone `.tar.gz`.
  - Cryptographic verification table displaying exact SHA-256 checksums with one-click copy buttons and platform installation/sideloading guides.
- **Universal Contact Deep Links & App Routing (Full-Stack)**:
  - Universal shareable HTTPS contact URLs: `https://<DOMAIN>/connect/<PUBLIC_ID>` and `https://<DOMAIN>/u/<PUBLIC_ID>`.
  - Android App Links (`autoVerify="true"`) for `ghost-room-chi.vercel.app` and `ghostroom.app`, plus custom URI scheme `ghostroom://connect/<PUBLIC_ID>`.
  - iOS Associated Domains (`applinks`) and `CFBundleURLTypes` custom scheme handler.
  - Automated well-known endpoint distribution: `/.well-known/assetlinks.json` and `/.well-known/apple-app-site-association`.
  - Smart-redirect web fallback (`GET /connect/:publicId`) with a 1500ms visibility/timeout fallback prompting native app execution or routing to `/download`.
  - In-app **Add Contact & Fingerprint Verification Modal** parsing incoming deep links and scannable QR codes, displaying safety numbers, peer verification badges, and instant chat initiation.

### Changed
- Refactored `AppController` root health endpoint to `GET /status` to route public web traffic cleanly through `PortalController`.
- Upgraded Digital Passport screen and card widgets to render universal HTTPS QR codes compatible with any mobile camera app.

---

## [2.4.0] - 2026-11-18

### Added
- **Automated In-App Multi-Platform Update Engine**:
  - Automated version manifest fetching (`version.json`) with semantic version comparison and build number checking.
  - Cryptographic binary integrity verification using SHA-256 checksum validation prior to execution or installation.
  - Platform-aware download handling supporting Android APK, Linux AppImage, Debian `.deb`, Fedora/RPM `.rpm`, and tarball packages.
  - Progressive download progress indicator with cancel/retry support.
  - Native installation triggers: Android `PackageInstaller` / `FileProvider` intents and Linux AppImage executable permission setting.
- **Update Dialog & Notification System**:
  - Automatic background update checks on application launch.
  - In-app update prompt displaying changelogs, release assets, binary sizes, and one-click update actions.

---

## [2.3.0] - 2026-11-15

### Added
- **Zero-Knowledge Cloudflare R2 / S3 Encrypted Media Storage**:
  - Client-side XChaCha20-Poly1305 symmetric media encryption: images, videos, audio notes, and file attachments are fully encrypted before leaving the device.
  - S3-compatible presigned upload and download URLs via Cloudflare R2 / AWS S3 / MinIO.
  - Two-stage upload confirmation (`POST /media/upload-url` and `POST /media/confirm-upload`) with `HeadObject` integrity verification.
  - Ephemeral media lifecycle: atomic reference counting deletes media blobs from cloud storage automatically once all recipients acknowledge delivery.
- **Encrypted Voice Notes**:
  - Native audio recording and playback with real-time waveform visualization.
  - AAC/Opus audio compression with client-side end-to-end encryption.
- **Resilient Offline Outbox & Queue**:
  - Local Hive-backed queue for outbound messages created during network disconnection.
  - Automatic exponential backoff retry and flush upon socket reconnection.
- **Firebase Cloud Messaging (FCM) Background Wakeups**:
  - Asymmetric push notification dispatch waking recipient devices when messages arrive while offline.
  - Zero-plaintext push model: notifications contain only message IDs and trigger background inbox fetch without exposing content to Google FCM servers.

---

## [2.2.3] - 2026-06-15

### Added
- **Multi-Device Cryptographic Identity Routing**:
  - Independent per-device ephemeral IDs linked to the root master public ID (`inbox:{public_id}:{device_id}`).
  - Cross-device delivery synchronization and state management.

### Changed
- Improved WebSocket reconnection reliability and heartbeat timeouts on transient cellular networks.
- Enforced strict in-memory rate limiting per public ID to mitigate spam abuse.

---

## [2.2.2] - 2026-06-12

### Changed
- **Robust Link & Package Extraction**: Enhanced parser logic to extract raw base64 identity package tokens and space invite links from deep links (`ghostroom://`, `ghost://`), web links, or fully formatted chat messages. Also normalized missing base64Url padding to prevent decoding failures.

### Fixed
- **Contact Dialog Auto-Exit Flow**: Renamed bottom sheet builder contexts to prevent context shadowing, ensuring that the manual public ID dialog properly pops (auto-exits) and registers success snackbars on completion.
- **Gallery Scanner Resource Disposal**: Configured appropriate try-catch-finally wrapping and lifecycle disposal on the mobile scanner controller to prevent memory leaks and scan failures.
