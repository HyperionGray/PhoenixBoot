# Changelog

All notable changes to PhoenixBoot will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Complete CI/CD documentation suite
- CONTRIBUTING.md with contribution guidelines
- CODE_OF_CONDUCT.md with community standards
- SECURITY.md with security policy and vulnerability reporting
- CHANGELOG.md for tracking project history

## [3.1.0] - 2024-12

### Added
- UUEFI v3.1 with Debug Diagnostics Mode
  - Complete variable data dump (hex + ASCII) for all variables
  - Protocol database enumeration
  - Configuration tables (ACPI, SMBIOS)
  - Detailed memory map with all regions
  - Full system dump capability
- Enhanced debug output for deep firmware analysis
- Comprehensive variable descriptions (150+ patterns)

### Changed
- Improved UUEFI menu system with debug options
- Enhanced error handling in diagnostic tools

### Security
- Updated dependency versions in cloud integration components
- Fixed hardcoded secret keys in API endpoints
- Resolved multiple CVEs in third-party dependencies

## [3.0.0] - 2024-11

### Added
- Container-based architecture
  - Docker Compose support for all components
  - Separate containers: build, test, installer, runtime, TUI
  - Podman quadlet integration for systemd
- Terminal User Interface (TUI)
  - Interactive task management
  - Real-time output display
  - Organized task categories
  - Keyboard navigation support
- UUEFI v3.0 enhancements
  - Complete EFI variable enumeration with descriptions
  - Variable editing system for safe modifications
  - Smart categorization (boot, security, vendor)
  - Security heuristics engine
  - Nuclear wipe system for malware response
  - ESP configuration viewer
  - Edit indicators for safe variables
- SecureBoot Bootable Media Creator
  - One-command ISO-to-bootable-media conversion
  - Automatic SecureBoot key generation
  - Microsoft-signed shim integration
  - Key enrollment tool included on media
- Enhanced documentation
  - Container Architecture Guide
  - TUI Guide
  - SecureBoot Bootable Media Guide
  - UUEFI feature documentation

### Changed
- Migrated to modular container architecture
- Improved build reproducibility
- Enhanced user experience with TUI
- Better organization of build artifacts

### Fixed
- Memory leaks in ESP package creation
- Race conditions in parallel builds
- Inconsistent build environments across systems

## [2.0.0] - 2024-09

### Added
- UUEFI v2.0 with interactive menu system
- Security environment checker (`secure-env` command)
  - EFI variables security scanning
  - Boot integrity verification
  - Secure Boot status validation
  - Kernel security checks
  - Bootkit detection
  - Module signature verification
  - Attack vector analysis
- Comprehensive security reporting (text and JSON)
- Hardware firmware recovery tools
- Kernel hardening analyzer

### Changed
- Improved UEFI application build process
- Enhanced key generation workflow
- Better error messages and user feedback

### Security
- Added comprehensive boot chain verification
- Implemented firmware-level malware detection
- Enhanced Secure Boot enforcement

## [1.5.0] - 2024-06

### Added
- ESP (EFI System Partition) packaging
- ISO integration support
- Bootable image creation tools
- Module signing functionality
  - MOK certificate management
  - Batch module signing
  - Integration with system module loading

### Changed
- Improved build scripts
- Enhanced documentation
- Better error handling

### Fixed
- ESP creation on various filesystems
- Key enrollment issues on certain hardware

## [1.0.0] - 2024-03

### Added
- Initial release of PhoenixBoot
- Core firmware defense system
- Basic UEFI Secure Boot support
- Key generation (PK, KEK, db)
- Bootloader signing
- Kernel and initramfs signing
- Basic UEFI diagnostic tools
- Documentation and examples

### Security
- Cryptographic boot chain verification
- Secure key generation
- Protection against basic bootkits

## Version History Summary

- **3.1.x**: Debug diagnostics and enhanced analysis
- **3.0.x**: Container architecture and TUI
- **2.x**: Security features and environment checker
- **1.x**: Initial release with core functionality

## Migration Guides

### Migrating to 3.0

If you're upgrading from 2.x to 3.0:

1. **Container Support**: Review the new container architecture
   ```bash
   # Old way
   ./pf.py build-build
   
   # New way (containerized)
   make run-build
   ```

2. **TUI Interface**: Try the new interactive interface
   ```bash
   ./phoenixboot-tui.sh
   ```

3. **SecureBoot Media**: Use the new one-command creator
   ```bash
   ./create-secureboot-bootable-media.sh --iso your.iso
   ```

### Migrating to 2.0

If you're upgrading from 1.x to 2.0:

1. **Security Checks**: Run the new security environment checker
   ```bash
   ./pf.py secure-env
   ```

2. **UUEFI Updates**: Rebuild UUEFI with new features
   ```bash
   ./pf.py build-package-esp
   ./pf.py workflow-test-uuefi
   ```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to contribute to this changelog and the project.

## Links

- [Repository](https://github.com/P4X-ng/PhoenixBoot)
- [Issues](https://github.com/P4X-ng/PhoenixBoot/issues)
- [Releases](https://github.com/P4X-ng/PhoenixBoot/releases)
- [Documentation](docs/)

---

**Note**: This changelog is maintained manually. For a complete list of commits, see the [commit history](https://github.com/P4X-ng/PhoenixBoot/commits).
