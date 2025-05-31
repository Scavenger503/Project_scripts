# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Semantic Versioning](https://semver.org/).

---

## [1.0.1] - 2025-05-31
### Fixed
- ✅ Resolved error 64 on macOS when mounting SMB shares
- Properly encoded SMB share paths (spaces as `%20`)
- Escaped special characters in usernames/passwords for macOS `mount_smbfs`
- macOS users can now mount shares with paths containing spaces or `@` in credentials

---

## [1.0.0] - 2025-05-30
### Added
- Initial stable release of the Universal SMB Diagnostic Tool
- Cross-platform support for:
  - ✅ Windows (`net use`)
  - ✅ macOS (`mount_smbfs`)
  - ✅ Linux (`mount -t cifs`)
- Interactive diagnostics: tests for SMB services, ports, and share availability
- Encrypted credential handling using `cryptography` library
- CLI-driven, user-friendly input for mapping SMB shares

