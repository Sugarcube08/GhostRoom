# Changelog

All notable changes to this project will be documented in this file.

## [2.2.2] - 2026-06-12

### Changed
- **Robust Link & Package Extraction**: Enhanced parser logic to extract raw base64 identity package tokens and space invite links from deep links (`ghostroom://`, `ghost://`), web links, or fully formatted chat messages. Also normalized missing base64Url padding to prevent decoding failures.

### Fixed
- **Contact Dialog Auto-Exit Flow**: Renamed bottom sheet builder contexts to prevent context shadowing, ensuring that the manual public ID dialog properly pops (auto-exits) and registers success snackbars on completion.
- **Gallery Scanner Resource Disposal**: Configured appropriate try-catch-finally wrapping and lifecycle disposal on the mobile scanner controller to prevent memory leaks and scan failures.
