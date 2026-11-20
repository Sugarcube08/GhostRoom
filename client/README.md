<p align="center">
  <img src="assets/brand/ghostroom_lockup_horizontal.svg" alt="GhostRoom Client" width="440">
</p>

# GhostRoom Client (Flutter)

The official cross-platform client for the **GhostRoom** zero-knowledge messaging system. Built with Flutter, Libsodium, and Riverpod for Android, Linux, macOS, iOS, and Windows.

---

## 🌟 Key Capabilities

### 1. Cryptographic Identity & Dual-Method Vault
- **Zero Accounts**: No phone numbers, email addresses, or SMS verification.
- **BIP-39 Mnemonic**: 24-word cryptographic seed deriving Ed25519 signing keys and X25519 encryption keys.
- **Portable `.ghostkey` Vault**: Encrypted JSON keyfile protected with **Argon2id** (`crypto_pwhash_argon2id13`) memory-hard key derivation and **XChaCha20-Poly1305-IETF** AEAD encryption.
- **Dual-Unlock Recovery**: Instant authentication via raw 24-word seed phrase or `.ghostkey` file picker with PIN/password decryption.

### 2. Architectural Geometric Design System
- **Dark-First Geometric Aesthetic**: Strict spatial hierarchy using Obsidian Void (`#090A0F`), Elevated Slate (`#12141D` / `#1A1D2B`), 1px structural hairline borders (`#1F2333`), High-Contrast Mist typography (`#F4F6FA`), and Cyber Iris active accents (`#7C5CFF`).
- **Standardized Grid**: 8px spatial grid, 12px card border radius, 8px input/button radius, and strict monospace typography (`JetBrains Mono` / `Roboto Mono`) for public IDs and safety numbers.

### 3. Universal Contact Deep Links & Passports
- **Universal Contact Links**: Shareable HTTPS routes (`https://<DOMAIN>/connect/<PUBLIC_ID>`), scannable QR codes, and native App Links (`autoVerify="true"`).
- **In-App Intent Interception**: Opening an invite link or scanning a QR code instantly opens the **Add Contact & Fingerprint Verification Modal** displaying safety numbers, peer verification badges, and direct channel negotiation.

### 4. Zero-Knowledge Media & Voice Notes
- **Client-Side Media Encryption**: Photos, videos, and files are encrypted with unique symmetric keys before being uploaded to Cloudflare R2 / S3 blob storage via presigned URLs.
- **Voice Messages**: Native audio recording and playback with real-time waveform visualization.
- **Ephemeral Reference Counting**: Media blobs automatically purge from cloud storage once recipient delivery is confirmed.

### 5. In-App Automated Multi-Platform Updates
- **Platform-Aware Updates**: Automatic background checks against `version.json` with semantic version comparison.
- **SHA-256 Integrity Verification**: Validates cryptographic checksums before allowing execution or installation.
- **Native Installers**: Android `PackageInstaller` sideloading and Linux executable permissions management.

---

## 📁 Architecture & Directory Structure

```
client/lib/
├── core/
│   ├── app_initializer.dart        # Background & foreground service bootstrapper
│   ├── crypto/
│   │   ├── identity_service.dart   # Libsodium Ed25519/X25519 master identity vault
│   │   ├── keyfile_service.dart    # Argon2id + XChaCha20-Poly1305 .ghostkey engine
│   │   └── security_config.dart    # Cryptographic invariants & constants
│   ├── network/
│   │   ├── relay_manager.dart      # Active & fallback relay profiles
│   │   ├── update_service.dart     # Auto-update engine & SHA-256 validator
│   │   └── websocket_service.dart  # Socket.IO connection & challenge-response
│   ├── storage/                    # Hive encrypted boxes & directory management
│   └── theme/                      # GhostTheme & dynamic typography
├── design_system/
│   ├── colors.dart                 # Obsidian/Slate/Iris color tokens
│   ├── components/                 # GhostButton, GhostInput, GhostSurface, GhostCard
│   ├── spacing.dart                # 8px spatial grid & corner radii
│   └── typography.dart             # Monospace & display typography
└── features/
    ├── chat/                       # ConversationScreen, voice recorder, message bubbles
    ├── contacts/                   # Passport screen, QR scanner, contact actions
    ├── home/                       # Chat list, onboarding, dual-recovery sheet
    ├── media/                      # Media picker, viewer, and background cache
    └── settings/                   # Identity vault, relay manager, update dialog
```

---

## 🛠️ Build & Development

### Prerequisites
- **Flutter SDK**: `>= 3.19.0` (Dart `>= 3.3.0`)
- **Libsodium**: Bundled automatically via `sodium_libs`
- **Android**: Android SDK 21+ (minSdk 21, targetSdk 34)
- **Linux**: `libsecret-1-dev`, `libjsoncpp-dev` (Debian/Ubuntu: `sudo apt install libsecret-1-dev libjsoncpp-dev`)

### Installation & Execution

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Analyze code (enforce 0 warnings)
flutter analyze

# 3. Run test suites
flutter test

# 4. Launch client
flutter run
```

### Building Release Binaries

```bash
# Android APK
flutter build apk --release

# Linux Desktop Bundle
flutter build linux --release
```

---

## 🧪 Testing

```bash
# Run all unit and integration tests
flutter test

# Test keyfile encryption and KDF security
flutter test test/keyfile_service_test.dart

# Test deep link and universal routing parser
flutter test test/deep_link_test.dart
```

---

## 📄 License

GhostRoom is licensed under the MIT License. See [LICENSE](../LICENSE) for details.
