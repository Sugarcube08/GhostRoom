# GhostRoom Client

The official Flutter client for the GhostRoom ephemeral communication platform.

## Features

- **End-to-End Encryption:** Uses `libsodium` (`sodium.crypto.secretBox`) for XChaCha20-Poly1305 encryption.
- **Identity Privacy:** Generates unique cryptographic identities locally. No phone numbers, emails, or accounts required.
- **Ephemeral Sessions:** Joined spaces are stored in secure storage but automatically cleared on a cold start to ensure no long-term traces of your communication history remain on the device.
- **Secure QR & Link Handling:** Join spaces instantly via live camera scan, gallery image import, or `ghost://room/` invite links.
- **Privacy Overlay:** Protects your app content from being seen in the task switcher.
- **Panic Wipe:** Instantly erase all local relay profiles and identity keys.

## Technical Details

### State Management
The app uses **Riverpod** for robust, reactive state management.
- `activeRelayProvider`: Manages the currently selected relay connection.
- `recentRoomsProvider`: Handles the list of joined spaces for the current session.
- `cryptoServiceProvider`: Manages cryptographic operations and identity.

### Cryptography
- **Symmetric Encryption:** All messages within a room are encrypted using a 256-bit symmetric key.
- **Key Exchange:** Room keys are shared out-of-band via encrypted QR codes or links.
- **Nonce Handling:** Every message uses a unique random nonce to prevent replay attacks and ensure cryptographic integrity.

## Build Requirements

- Flutter SDK 3.19+
- Dart 3.3+
- Android SDK 21+ / iOS 12.0+

## Getting Started

1.  Clone the repository.
2.  Run `flutter pub get`.
3.  Ensure a GhostRoom relay is running.
4.  Launch the app: `flutter run`.

## License

This project is licensed under a **Custom License** (Personal and Educational Use Only) - see the [LICENSE](../LICENSE) file in the root directory for details.
