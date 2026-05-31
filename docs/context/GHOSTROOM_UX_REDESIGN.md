# GhostRoom UX Redesign (Phase UX-3)

Version: 2.1 (Premium)

Status: Implementation Phase

## 1. PRODUCT REPOSITIONING
GhostRoom is a **Private Messaging Platform** first, and a **Temporary Space Relay** second. The UX must reflect this hierarchy to inspire trust and clarity.

---

## 2. REVISED NAVIGATION ARCHITECTURE (Bottom Bar)

1.  **Messages**: Primary Home. Active chats and unread counts.
2.  **Contacts**: The social graph. Add contacts, view QR, manage blocks.
3.  **Spaces**: Secondary feature. V1 temporary rooms and future broadcast modes.
4.  **Vault**: Formerly Settings. Identity management, keys, backups, and security.

---

## 3. IDENTITY VAULT (Redesign)
The "Vault" should feel like a secure container for the user's digital soul.

*   **Header**: High-contrast Public ID and sharing QR.
*   **Safety Status**: Permanent indicator for "Backup Created" vs "Backup Missing".
*   **My QR Card**: Premium full-screen card for physical scanning.
*   **Security Groups**:
    *   `Keys & Recovery`: Seed phrase, export identity.
    *   `Backup & Migration`: Encrypted archive management.
    *   `Relay Network`: Server configuration.
    *   `Privacy`: Biometrics (future), wipe data.

---

## 4. PREMIUM ONBOARDING FLOW

1.  **Values**: "No phone. No email. Total privacy."
2.  **Sovereignty**: "Your keys. Your data."
3.  **Generation**: Cryptographic setup with status.
4.  **Security Education**: The danger of losing the seed phrase.
5.  **Seed Display**: Secure reveal of 24 words.
6.  **Verification**: Confirm random words.
7.  **Initial Backup**: Save the `.ghostroombackup` file.
8.  **Recovery Test**: Mandatory simulation of identity restoration.

---

## 5. CHAT & COMPOSER UPGRADES

*   **Conversation Header**: Collapsed Alias/ID. Expands to show Fingerprint and current default retention mode.
*   **Per-Message Retention**: Integrated selector in the composer (Persistent/Ephemeral/View Once).
*   **Media Picker**: Explicit "View Once" photo/video modes.
*   **Requests**: Swipe actions (Accept/Delete/Block) for instant management.

---

## 6. VISUAL DISTINCTON

*   **Persistent Layers (Messages/Vault)**: Deepest black (`#080808`), white text, subtle amber/gold accents (Premium).
*   **Disposable Layers (Spaces)**: Lighter dark (`#121212`), monochromatic grey text, minimalist icons.
