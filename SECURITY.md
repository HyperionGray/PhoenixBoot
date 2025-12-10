# Security Policy

## Overview

PhoenixBoot is a security-focused firmware defense system designed to protect against bootkits, rootkits, and supply chain attacks. We take security seriously and appreciate your efforts to responsibly disclose your findings.

## Supported Versions

We actively maintain and provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| < 1.0   | :x:                |

**Note**: We are currently in active development. All security fixes are applied to the `main` branch.

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

### How to Report

If you discover a security vulnerability in PhoenixBoot, please report it by:

1. **GitHub Security Advisories** (Preferred):
   - Navigate to the [Security Advisories](https://github.com/P4X-ng/PhoenixBoot/security/advisories) page
   - Click "Report a vulnerability"
   - Fill out the advisory form with details

2. **Direct Contact**:
   - Open a private security issue or discussion
   - Contact the maintainers through GitHub with the subject line: "SECURITY: [Brief Description]"

### What to Include

When reporting a vulnerability, please include:

- **Type of vulnerability** (e.g., buffer overflow, privilege escalation, authentication bypass)
- **Full paths of affected source files**
- **Location of the affected source code** (tag/branch/commit or direct URL)
- **Step-by-step instructions to reproduce** the issue
- **Proof-of-concept or exploit code** (if possible)
- **Impact assessment** - how an attacker might exploit this
- **Suggested fix** (if you have one)
- **Your name/handle** for acknowledgment (optional)

### What to Expect

- **Response Time**: We will acknowledge your report within **48 hours**
- **Initial Assessment**: Within **7 days**, we will provide an initial assessment
- **Updates**: We will keep you informed of our progress
- **Disclosure Timeline**: We aim to fix critical vulnerabilities within **30 days**
- **Credit**: We will acknowledge your contribution in our release notes (if you wish)

## Security Best Practices for Contributors

When contributing to PhoenixBoot, please:

1. **Follow Secure Coding Guidelines**:
   - Validate all inputs
   - Use safe string handling functions
   - Avoid buffer overflows
   - Check return values and error conditions
   - Use cryptographic functions correctly

2. **Review Security-Critical Code**:
   - UEFI applications (C code in `staging/src/`)
   - Boot chain verification
   - Cryptographic operations
   - Key management functions
   - Firmware interaction code

3. **Test Security Features**:
   - Run QEMU tests with Secure Boot enabled
   - Test attestation and verification mechanisms
   - Validate key enrollment processes
   - Check for privilege escalation vectors

4. **Document Security Implications**:
   - Add comments explaining security-critical sections
   - Document threat models for new features
   - Update security documentation

## Security Features

PhoenixBoot includes the following security features:

### Core Security
- **Secure Boot Enforcement** - Requires Secure Boot to be enabled
- **Runtime Attestation** - Verifies binary hash against sidecar file
- **Key Enrollment** - Automated Secure Boot key management
- **Module Signing** - Kernel module signing for Secure Boot

### Defense Mechanisms
- **Bootkit Detection** - Scans for firmware-level malware
- **EFI Variable Security** - Monitors for suspicious modifications
- **Boot Integrity Verification** - Validates bootloader, kernel, and initramfs
- **Kernel Hardening Analysis** - Checks kernel config against DISA STIG standards

### Additional Protection
- **UUEFI Diagnostic Tool** - System diagnostics and security analysis
- **Firmware Recovery** - Hardware-level firmware recovery capabilities
- **Memory-Safe UEFI Code** - Built with EDK2 for reliability

## Known Security Considerations

### Firmware Access
- PhoenixBoot requires privileged access to firmware (UEFI variables, SPI flash)
- This is necessary for its security functions but also presents risk if compromised
- Always verify the integrity of PhoenixBoot binaries before deployment

### Secure Boot Keys
- Custom Secure Boot keys are powerful - protect them carefully
- Store keys securely and offline when not in use
- Follow the key management documentation in `keys/README.md`

### UEFI Applications
- UEFI applications run with high privileges
- Review all UEFI code changes carefully
- Test thoroughly in QEMU before deploying to hardware

### Module Signing
- MOK (Machine Owner Key) has significant privileges
- Protect MOK private keys with strong passwords
- Audit signed modules regularly

## Security Update Process

1. **Identification**: Vulnerability is reported or discovered
2. **Assessment**: Security team evaluates severity and impact
3. **Development**: Fix is developed and tested
4. **Testing**: Comprehensive security testing is performed
5. **Review**: Code review by multiple maintainers
6. **Release**: Security update is released
7. **Disclosure**: Public disclosure after users have had time to update

## Severity Ratings

We use the following severity ratings:

- **Critical**: Can compromise system security without user interaction
- **High**: Can compromise system security with minimal user interaction
- **Medium**: Can compromise system security with significant user interaction
- **Low**: Limited impact or requires significant preconditions

## Security Advisories

Security advisories will be published at:
- [GitHub Security Advisories](https://github.com/P4X-ng/PhoenixBoot/security/advisories)
- Release notes in CHANGELOG.md

## Acknowledgments

We would like to thank the security researchers who have responsibly disclosed vulnerabilities:

*(This section will be updated as we receive reports)*

## Security Resources

- [UEFI Security](https://uefi.org/specifications)
- [EDK2 Security](https://github.com/tianocore/tianocore.github.io/wiki/EDK-II-Security)
- [Secure Boot Documentation](docs/SECURE_BOOT.md)
- [Boot Security Analysis](docs/BOOT_SEQUENCE_AND_ATTACK_SURFACES.md)

## Questions?

For security-related questions that are not vulnerabilities, please:
- Open a public discussion on GitHub Discussions
- Check our documentation in the `docs/` directory
- Review existing security documentation

Thank you for helping keep PhoenixBoot and its users secure! 🔥🔒
