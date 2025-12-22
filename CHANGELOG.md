# Changelog

All notable changes to PhoenixBoot will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive CI/CD review workflow
- Complete documentation suite (CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, CHANGELOG.md)
- Container-based architecture with Docker Compose profiles
- Interactive Terminal User Interface (TUI) for task management
- SecureBoot bootable media creator script
- Kernel hardening analyzer with DISA STIG compliance checks
- UUEFI v3.1 with enhanced diagnostics and debug mode
- Firmware checksum database and verification
- Hardware firmware recovery tools
- Automated dependency vulnerability scanning
- Progressive recovery mechanisms
- Educational output for key generation and boot artifacts

### Changed
- Migrated to modular container architecture
- Improved documentation organization with comprehensive guides
- Enhanced security checks and validation
- Reorganized script structure by category

### Security
- Fixed hardcoded secret keys in cloud integration examples
- Updated vulnerable dependencies (fastapi, aiohttp, cryptography)
- Added security policy and vulnerability reporting guidelines
- Implemented CodeQL security scanning
- Enhanced secure boot enforcement

## Project History

### Core Features (Implemented)

#### UEFI Applications
- **NuclearBootEdk2.efi** - Battle-tested UEFI bootloader with Secure Boot enforcement and runtime attestation
- **KeyEnrollEdk2.efi** - Automated Secure Boot key enrollment utility
- **UUEFI.efi** - Universal UEFI diagnostic and management tool

#### Security Features
- Secure Boot key generation and management
- Kernel module signing (MOK integration)
- Hardware-level firmware recovery
- UEFI variable security verification
- Firmware integrity validation

#### Testing & Validation
- QEMU-based testing framework
- Secure Boot positive/negative testing
- JUnit report generation
- E2E testing workflows
- Playwright automated testing

#### Boot Management
- UEFI boot entry management
- MOK key enrollment and listing
- ESP (EFI System Partition) packaging
- USB bootable media creation
- ISO loopback support

#### Tools & Utilities
- Task runner (pf.py) with modular planfiles
- Kernel hardening analyzer
- Hardware firmware recovery tools
- Progressive recovery mechanisms
- Network-based cooperative PhoenixGuard system

### Documentation
- Architecture documentation
- Getting started guide
- Container architecture guide
- TUI guide
- Security considerations
- Kernel hardening guide
- Testing guide
- Complete system understanding guide
- Boot sequence and attack surfaces documentation
- SecureBoot bootable media guide
- UUEFI feature guides

### Build & Development
- EDK2-based UEFI application builds
- Container-based build system
- Makefile for convenience commands
- Docker Compose multi-profile setup
- Podman quadlet integration

## Version Information

PhoenixBoot follows semantic versioning but does not yet have formal releases. The project is under active development with continuous improvements and security updates.

### Current State
- **Status**: Production-ready for core features
- **Branch**: main
- **License**: Apache License 2.0

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for information on how to contribute to PhoenixBoot.

## Security

See [SECURITY.md](SECURITY.md) for information on reporting security vulnerabilities.

---

For more details on changes, see the [commit history](https://github.com/P4X-ng/PhoenixBoot/commits/main).
