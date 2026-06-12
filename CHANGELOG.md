# Changelog

All notable changes to this project will be documented in this file.

## [2.2.1] - 2026-06-12

### Added
- **Dynamic Update Redirection**: Implemented future-proof dynamic URL construction pointing to `https://github.com/Sugarcube08/GhostRoom/releases/tag/{version}` upon update detection, replacing previous hardcoded release endpoints.
- **Light Mode Logo Backbox**: Wrapped the transparent-background logo (`assets/images/banner.png`) inside a dark background container (`Color(0xFF0A0A0A)`) when rendering in Light Mode (both on the Splash Screen and Onboarding Screen) to guarantee high visual contrast.
- **Wasm & Web Build Support**: Stabilized web compilation parameters and verified clean compilation output via `flutter build web`.

### Changed
- **Storage Path Unification (Linux)**: Scoped all application storage directories under the standard XDG-compliant `~/.local/share/ghostroom` directory on Linux, removing runtime dependencies on `~/Documents`. Integrated seamless data migration logic for existing users.
- **Codebase Telemetry & Log Scrubbing**: Stripped and suppressed all telemetry prints, `debugPrint`s, custom `Logger` messages, and diagnostic dumps across 22 client files to safeguard user privacy in production.
- **Desktop Memory Optimization**: Configured automatic painting and image cache purging under system memory pressure events (`System_Memory_Pressure`) to prevent out-of-memory crashes on resource-constrained desktop platforms.

### Fixed
- **Theme & Contrast Synchronization**:
  - Replaced all instances of hardcoded colors (such as `Colors.white`, `Colors.black`, and `Colors.grey`) with dynamic semantic tokens from `Theme.of(context).colorScheme` and `ThemeExtension` colors (`backgroundPrimary`, `textPrimary`, `warning`, `error`, etc.).
  - Resolved low-contrast and unreadable text elements in Light/Dark modes across message bubbles, text fields, alert dialogs, bottom sheets, the sidebar navigation, contact list views, and unread badge overlays.
  - Unified the visual treatment for seen status checkmarks, manual identity entry alerts, and active relay configuration checkboxes.
- **Layout & Navigation Adjustments**: Standardized split-view rails, navigation menus, and empty states on desktop platforms (Linux, macOS, Windows) to resolve layout clipping and rendering jitter.
- **Linter & Analyzer Cleanup**: Fixed all remaining compiler warnings, unused imports, unused local variables, and empty catch-blocks to achieve a 100% clean linter report.
