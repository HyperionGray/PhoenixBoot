# Changelog

All notable changes to PhoenixBoot will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Essential project documentation (LICENSE, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md)
- Comprehensive security policy and vulnerability reporting guidelines
- Contributor guidelines and code of conduct

### Changed
- Repository now includes all standard open-source documentation files

### Security
- Established formal security reporting process via SECURITY.md

## [0.9.0] - 2024-12-07

### Added
- **Container-Based Architecture**: Modular container system for build, test, installer, runtime, and TUI
  - Build container with EDK2, GCC, and artifact creation
  - Test container with QEMU validation
  - Installer container for ESP and bootable media
  - Runtime container for on-host operations
  - TUI container with interactive interface
- **Terminal User Interface (TUI)**: Modern interactive interface for PhoenixBoot operations
  - Organized task categories
  - One-click execution
  - Real-time output
  - Keyboard navigation
- **Turnkey SecureBoot Bootable Media Creator**: Simple script to create SecureBoot-enabled boot media
  - Automatic SecureBoot key generation (PK, KEK, db)
  - Bootable ESP with Microsoft-signed shim
  - Key enrollment tool included on media
  - ISO loopback support
- **UUEFI v3.0 Enhanced Features**:
  - Complete EFI variable enumeration with descriptions
  - Variable editing system for safe modifications
  - Smart categorization by type
  - Security heuristics engine
  - Nuclear wipe system for complete sanitization
  - Comprehensive variable descriptions (150+ patterns)

### Improved
- Kernel Hardening Analyzer with DISA STIG compliance checks
- UEFI Variable Security verification
- Firmware checksum database validation
- Documentation structure and organization
- Task runner organization with multiple .pf files

### Fixed
- UUEFI.efi no longer crashes (was identical to NuclearBootEdk2.efi)
- Build process now properly generates distinct binaries
- ESP packaging workflow

## [0.8.0] - Previous Release

### Added
- **Nuclear Boot (NuclearBootEdk2)**: Battle-tested UEFI bootloader
  - Secure Boot enforcement
  - Runtime attestation with hash verification
  - Network-based boot capability
  - Memory-safe EDK2 implementation
- **Key Enrollment (KeyEnrollEdk2)**: Automated Secure Boot key enrollment
  - Enrolls PK, KEK, and db keys from ESP
  - Authenticated variables support
- **Boot Management Tools**:
  - `os-boot-clean`: Clean stale UEFI boot entries
  - `os-mok-enroll`: Enroll MOK keys
  - `os-mok-list-keys`: List MOK certificates
  - `uuefi-install`: Install UUEFI.efi to system ESP
  - `uuefi-apply`: Set BootNext for one-time UUEFI boot
  - `uuefi-report`: Display system security status
- **QEMU Testing Framework**:
  - Main QEMU boot test with OVMF firmware
  - Secure Boot enabled tests
  - Strict security verification
  - Negative attestation testing
  - JUnit report generation
- **ESP Packaging**: Bootable EFI System Partition image creation
- **Module Signing**: Kernel module signing for Secure Boot
- **Security Environment Check (`secure_env`)**:
  - EFI variables security scanning
  - Boot integrity verification
  - Secure Boot status validation
  - Kernel security checks (lockdown, KASLR)
  - Bootkit detection
  - Module signature verification
  - Attack vector analysis
  - Automated reporting (text and JSON)

### Improved
- Project structure and organization
- Documentation in `docs/` directory
- Task runner system with `pf.py`

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to contribute to this project.

## Security

For security issues, please see our [Security Policy](SECURITY.md).

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

---

**Made with 🔥 for a more secure boot process**
