# GhostRoom UX Redesign (Phase UX-1)

Version: 2.1 (Proposed)

Status: Design Phase

## 1. VISION
Transform GhostRoom from a technical prototype into a premium, user-friendly communication system where **Identity-based Direct Messaging** is the primary experience and **Anonymous Temporary Rooms** are a complementary secondary feature.

---

## 2. INFORMATION ARCHITECTURE overhaul

### Root Navigation (Bottom Bar)
1. **Messages**: Home screen. Shows active 1-to-1 conversations.
2. **Requests**: Isolated inbox for unknown senders.
3. **Anonymous**: V1 temporary rooms (Create/Join).
4. **Settings**: Identity management and app configuration.

### Onboarding Flow (First Launch)
1. **Welcome**: Value proposition (Private, no accounts).
2. **Identity Creation**: Animation/status of key generation.
3. **Recovery Education**: The importance of the 24-word seed.
4. **Seed Reveal**: Displaying the 24 words securely.
5. **Mandatory Verification**: User must confirm random words from their seed.
6. **Mandatory Backup**: User must export their encrypted `.ghostroombackup` file.
7. **Success**: Public ID reveal and entry to app.

---

## 3. VISUAL LANGUAGE

### Private Messages (Premium Dark)
* Background: `#0A0A0A` (Pure black/Deep grey).
* Accents: Subtle gradients, high-quality typography.
* Feeling: Secure, permanent, established.

### Anonymous Rooms (Minimalist)
* Background: `#121212` (Slightly lighter).
* Accents: Monochromatic, utilitarian.
* Feeling: Temporary, disposable, lightweight.

---

## 4. SCREEN INVENTORY

### Onboarding
* `OnboardingWelcomeScreen`
* `OnboardingIdentityGenerationScreen`
* `OnboardingSecurityWarningScreen`
* `OnboardingSeedRevealScreen`
* `OnboardingSeedVerificationScreen`
* `OnboardingInitialBackupScreen`

### Main App
* `RootNavigationContainer` (The BottomNavigationBar shell)
* `MessagesListScreen` (Refactored `ChatsScreen`)
* `RequestsListScreen` (Refactored `RequestsScreen`)
* `AnonymousRoomsScreen` (Refactored `HomeScreen`)
* `IdentityControlCenter` (Refactored `SettingsScreen`)

---

## 5. USER FLOWS

### Adding a Contact
1. User taps `+` on Messages screen.
2. Options: `Scan QR`, `Paste Identity Package`, `Enter Public ID`.
3. If valid, contact is saved and chat opens.

### Accepting a Request
1. User notified of new request in `Requests` tab.
2. User opens request, can read text but not see media.
3. Options: `Accept` (moves to Messages), `Reject` (deleted), `Block` (blacklisted).

---

## 6. IMPLEMENTATION PLAN

### Step 1: Navigation Shell
* Implement `NavigationShell` using `BottomNavigationBar`.
* Move `HomeScreen` (V1) to the "Anonymous" tab.
* Move `ChatsScreen` (V2) to the "Messages" tab.

### Step 2: Onboarding Implementation
* Create the multi-step PageView for onboarding.
* Update `IdentityService` to support a "deferred" creation (user sees the generation happening).
* Implement the word-verification logic.

### Step 3: Identity Control Center
* Refactor `SettingsScreen` to put the Public ID and QR code front-and-center.
* Group actions logically (Identity, Backup, Privacy).

### Step 4: Visual Polish
* Refine message bubbles.
* Add animations for transitions between tabs.
* Implement consistent button and input styles.
