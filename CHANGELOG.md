# Changelog

All notable changes to PhoenixBoot will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Essential project documentation (LICENSE, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md)
- Comprehensive security policy and vulnerability reporting guidelines
- Contributor guidelines and code of conduct
- Python requirements.txt with fabric dependency for task runner

### Changed
- Repository now includes all standard open-source documentation files

### Security
- Established formal security reporting process via SECURITY.md

### Container-Based Architecture
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

### Kernel Hardening and Security Features
- Kernel Hardening Analyzer with DISA STIG compliance checks
- UEFI Variable Security verification
- Firmware checksum database validation
- Task runner organization with multiple .pf files

### Bug Fixes
- UUEFI.efi no longer crashes (was identical to NuclearBootEdk2.efi)
- Build process now properly generates distinct binaries
- ESP packaging workflow

## Core Features

### Boot Security
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
- Complete CI/CD documentation suite
- Essential project documentation files (CONTRIBUTING.md, LICENSE.md, SECURITY.md, CODE_OF_CONDUCT.md)
- Comprehensive security policies and vulnerability reporting procedures
- Community guidelines and contribution standards

### Changed
- Enhanced project documentation structure
- Improved security documentation coverage

### Security
- Established formal security policy and vulnerability reporting process
- Added security-specific community guidelines

## [3.1.0] - 2024-12-10

### Added
- **UUEFI v3.1 Debug Diagnostics Mode** - Complete system analysis capabilities
  - Everything dump mode for deep analysis
  - Complete variable data dump (hex + ASCII) for ALL variables
  - Protocol database enumeration (find hidden IOCTLs)
  - Configuration tables (ACPI, SMBIOS, etc.)
  - Detailed memory map with all regions
  - Full system dump (all of the above)
- Enhanced debug capabilities for firmware analysis
- Comprehensive system diagnostics for security research

### Changed
- Improved UUEFI diagnostic capabilities
- Enhanced system analysis and debugging features

### Fixed
- UUEFI diagnostic tool stability improvements
- Enhanced error handling in debug mode

## [3.0.0] - 2024-11-15

### Added
- **Container-Based Architecture** - Complete containerization of all components
  - Build container (EDK2, GCC, artifact creation)
  - Test container (QEMU, validation)
  - Installer container (ESP, bootable media)
  - Runtime container (on-host operations)
  - TUI container (interactive interface)
- **Terminal User Interface (TUI)** - Modern interactive interface
  - Organized task categories
  - One-click execution
  - Real-time output display
  - Modern design with keyboard navigation
- **UUEFI v3.0 Enhanced Features**
  - Complete EFI variable enumeration with descriptions
  - Variable editing system for safe modifications
  - Smart categorization (boot, security, vendor)
  - Security heuristics engine for threat detection
  - Interactive menu system
  - Security analysis report with severity levels
  - ESP configuration viewer
  - Nuclear wipe system for malware response
  - 150+ variable patterns documented (ASUS, Intel, WiFi, BT, etc.)
  - Edit indicators (✎) for safe-to-edit variables
  - Nuclear Wipe Menu with 4 options:
    - Vendor variable wipe (remove bloatware)
    - Full NVRAM reset (factory defaults, preserves security keys)
    - Disk wiping guide (nwipe instructions and workflow)
    - Complete nuclear wipe (NVRAM + disk for extreme malware situations)
- **Turnkey SecureBoot Bootable Media Creator**
  - Automatic SecureBoot key generation (PK, KEK, db)
  - Bootable ESP with Microsoft-signed shim
  - Key enrollment tool included on media
  - Clear first-boot instructions for enrollment
  - ISO loopback support
  - USB and CD/DVD compatibility
- **Kernel Hardening and UEFI Variable Checks**
  - Comprehensive kernel configuration analysis
  - UEFI security verification
  - Firmware checksum database validation
  - Kernel config remediation with kexec double-jump technique
  - DISA STIG compliance automated checks
  - Configuration diff and comparison tools

### Changed
- **Project Structure Reorganization**
  - Reduced root directory clutter (removed 9 wrapper scripts)
  - Consolidated Python utilities in `utils/`
  - Organized operational scripts in `scripts/`
  - Clear task organization across 4 `.pf` files
- **Primary Interface Unification**
  - All operations now use `./pf.py <task>` as primary interface
  - Unified task runner with intuitive DSL
  - Clear task organization and discovery
- **Enhanced Documentation**
  - Container architecture guides
  - TUI usage documentation
  - Comprehensive feature documentation
  - Educational output for all key generation commands
  - README files in `keys/` and `out/keys/mok/` explaining hierarchies

### Fixed
- **UUEFI Implementation Resolution**
  - Fixed UUEFI.efi crash issue (was identical to NuclearBootEdk2.efi)
  - Proper diagnostic tool implementation
  - Verified by MD5 checksum and source code review
  - Build from EDK2 toolchain working correctly

### Security
- Enhanced security environment checking
- Improved bootkit detection capabilities
- Strengthened firmware integrity validation
- Advanced UEFI variable security monitoring

## [2.0.0] - 2024-09-01

### Added
- **UUEFI v2.0 Enhanced Features**
  - Display firmware information (vendor, version, UEFI revision)
  - Show memory map (total and available memory)
  - Report security status (Secure Boot, Setup Mode, key enrollment)
  - Boot configuration viewer (BootOrder and boot entries)
  - Enhanced diagnostic capabilities
- **Security Environment Check (`secure_env`)**
  - EFI Variables Security scanning
  - Boot Integrity verification
  - Secure Boot Status validation
  - Kernel Security checks (lockdown, KASLR, etc.)
  - Bootkit Detection against baseline
  - Module Signatures verification
  - Attack Vector Analysis
  - Automated Reporting (text and JSON)
- **Comprehensive QEMU Testing Framework**
  - Multiple test scenarios (basic, secure, strict, negative attestation)
  - JUnit report generation
  - Automated CI/CD integration
  - Cloud-Init integration testing
- **Enhanced Module Signing**
  - MOK (Machine Owner Key) management
  - Kernel module signing automation
  - Certificate inventory management
  - Integration with system module loading

### Changed
- Improved task runner organization with multiple `.pf` files
- Enhanced build system with EDK2 integration
- Better error handling and logging throughout
- Streamlined ESP packaging process

### Fixed
- Build system reliability improvements
- QEMU testing stability enhancements
- Key generation and enrollment process fixes

## [1.0.0] - 2024-06-01

### Added
- **Nuclear Boot (NuclearBootEdk2)** - Battle-tested UEFI bootloader
  - Secure Boot enforcement
  - Runtime attestation with hash verification
  - Network-based boot capabilities
  - Memory-safe EDK2 implementation
- **Key Enrollment (KeyEnrollEdk2)** - Automated Secure Boot key enrollment
  - PK, KEK, and db key enrollment from ESP
  - Authenticated variables support
  - Custom Secure Boot configuration preparation
- **Boot Management Tools**
  - Clean stale UEFI boot entries (`os-boot-clean`)
  - MOK key enrollment (`os-mok-enroll`)
  - MOK certificate listing (`os-mok-list-keys`)
  - UUEFI installation and management
- **ESP Packaging System**
  - Bootable EFI System Partition image creation
  - FAT32 ESP images with all necessary EFI binaries
  - ISO integration support
  - Boot structure validation
- **Basic QEMU Testing**
  - Main QEMU boot test with OVMF firmware
  - Basic Secure Boot testing
  - Serial log capture and analysis

### Security
- Initial Secure Boot key hierarchy implementation
- Basic firmware protection mechanisms
- Kernel module signing foundation
- Cryptographic key generation and management

## [0.9.0] - 2024-04-15 (Beta)

### Added
- Initial project structure and build system
- Basic UEFI application framework
- Preliminary Secure Boot integration
- Development toolchain setup
- Initial documentation structure

### Changed
- Established project conventions and standards
- Set up development environment requirements

## [0.1.0] - 2024-02-01 (Alpha)

### Added
- Initial project conception and planning
- Basic repository structure
- Proof-of-concept implementations
- Research and development foundation

---

## Release Notes

### Version Numbering

PhoenixBoot follows [Semantic Versioning](https://semver.org/):

- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible functionality additions
- **PATCH** version for backwards-compatible bug fixes

### Release Process

1. **Development** - Features developed in feature branches
2. **Testing** - Comprehensive testing including QEMU end-to-end tests
3. **Security Review** - Security-focused code review for all changes
4. **Documentation** - Update documentation and changelog
5. **Release** - Tag release and publish artifacts

### Support Policy

- **Current Major Version** - Full support with security updates and new features
- **Previous Major Version** - Security updates and critical bug fixes for 12 months
- **Older Versions** - End of life, upgrade recommended

### Security Updates

Security updates are released as needed and may be backported to supported versions. See [SECURITY.md](SECURITY.md) for our security policy and vulnerability reporting process.

## Migration Guides

### Upgrading to v3.1.0

- **UUEFI Users**: New debug diagnostics mode available with `./pf.py test-qemu-uuefi`
- **Developers**: Enhanced debugging capabilities for firmware analysis
- **No breaking changes**: All existing functionality preserved

### Upgrading to v3.0.0

- **Task Runner**: Replace direct script calls with `./pf.py <task>`
- **Container Users**: New container architecture available with `docker-compose`
- **TUI Users**: Launch interactive interface with `./phoenixboot-tui.sh`
- **Key Management**: Enhanced educational output and documentation
- **UUEFI**: Completely rewritten with new features and capabilities

### Upgrading to v2.0.0

- **Security Checks**: New `./pf.py secure-env` command for comprehensive security validation
- **Testing**: Enhanced QEMU testing with multiple scenarios
- **Module Signing**: Improved MOK management and kernel module signing

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to PhoenixBoot.

## Security

See [SECURITY.md](SECURITY.md) for our security policy and vulnerability reporting process.

---

**For detailed technical information, see the comprehensive documentation in the `docs/` directory.**

**Made with 🔥 for a more secure boot process**
