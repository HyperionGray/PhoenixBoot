# Security Policy

## Supported Versions

We take security seriously and provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| 3.x     | :white_check_mark: |
| < 3.0   | :x:                |

**Note**: We recommend always using the latest version from the `main` branch for the most up-to-date security features and patches.

## Security Features

PhoenixBoot is designed with security as a primary focus. Key security features include:

### Core Security Components

- **Secure Boot Enforcement**: Full UEFI Secure Boot support with cryptographic verification
- **Hardware-Level Firmware Recovery**: Protection against bootkits and rootkits
- **Cryptographic Verification**: Complete UEFI boot chain validation
- **Key Management**: PK, KEK, and db key generation and enrollment
- **Module Signing**: Kernel module signing for Secure Boot compliance
- **Security Environment Checker**: Comprehensive boot integrity validation

### Security Monitoring

- **EFI Variable Security**: Scans for suspicious modifications
- **Boot Integrity Verification**: Validates bootloader, kernel, and initramfs
- **Kernel Security Checks**: Validates hardening features (lockdown, KASLR, etc.)
- **Bootkit Detection**: Firmware-level malware scanning
- **Module Signature Verification**: Ensures kernel modules are properly signed
- **Attack Vector Analysis**: Detects dangerous boot parameters and rootkit indicators

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

We take all security reports seriously and appreciate your efforts to responsibly disclose your findings.

### How to Report

To report a security vulnerability:

1. **Email**: Send details to the project maintainers (security contact in repository settings)
2. **Include**:
   - Description of the vulnerability
   - Steps to reproduce the issue
   - Potential impact
   - Suggested fix (if you have one)
   - Your contact information for follow-up

### What to Include

A good security report should contain:

- **Type of vulnerability** (e.g., privilege escalation, bootkit bypass, code injection)
- **Full path** to the source file(s) related to the vulnerability
- **Location** of the affected code (tag/branch/commit or direct URL)
- **Step-by-step instructions** to reproduce the issue
- **Proof-of-concept or exploit code** (if available)
- **Impact** of the vulnerability
- **Any special configuration** required to reproduce

### Response Timeline

- **Initial Response**: Within 48 hours of report
- **Confirmation**: Within 1 week (vulnerability confirmed or rejected)
- **Status Updates**: Every 7 days until resolution
- **Fix Timeline**: Varies by severity
  - Critical: Target within 7 days
  - High: Target within 30 days
  - Medium: Target within 60 days
  - Low: Target within 90 days

### Disclosure Policy

- **Coordinated Disclosure**: We practice responsible disclosure
- **Embargo Period**: Allow us time to fix the vulnerability before public disclosure
- **Credit**: We will credit you in the security advisory (unless you prefer to remain anonymous)
- **CVE Assignment**: For critical vulnerabilities, we will request CVE assignment

## Security Best Practices

When using PhoenixBoot, follow these security best practices:

### Key Management

- **Generate unique keys** for each system
- **Store private keys securely** (never commit to version control)
- **Use strong passwords** for key protection
- **Backup keys safely** in encrypted storage
- **Rotate keys periodically** as part of security maintenance

### Build Security

- **Verify integrity** of downloaded components
- **Use official sources** for dependencies
- **Review code changes** before building
- **Run security scans** on custom modifications
- **Keep dependencies updated**

### Deployment Security

- **Test in isolated environment** before production use
- **Enable Secure Boot** on target systems
- **Monitor boot integrity** regularly with `secure-env` command
- **Review EFI variables** for suspicious changes
- **Maintain audit logs** of security events

### Operational Security

- **Regular security audits** using built-in tools
- **Monitor for firmware updates** from hardware vendors
- **Review security advisories** for dependencies
- **Keep PhoenixBoot updated** to latest version
- **Document security configuration** for your deployment

## Known Security Considerations

### Threat Model

PhoenixBoot protects against:

- ✅ **Bootkits** at firmware level
- ✅ **Rootkits** in boot chain
- ✅ **Unauthorized boot modifications**
- ✅ **Supply chain attacks** on firmware
- ✅ **Persistent malware** in boot process

PhoenixBoot does **not** protect against:

- ❌ **Physical attacks** with direct hardware access (e.g., SPI flash reprogramming)
- ❌ **UEFI firmware vulnerabilities** in vendor implementations
- ❌ **Side-channel attacks** on cryptographic operations
- ❌ **Social engineering attacks** targeting key management
- ❌ **Operating system vulnerabilities** after boot

### Security Assumptions

PhoenixBoot assumes:

- **Trusted boot environment** during initial setup
- **Secure key generation** on trusted system
- **Protected key storage** by the user
- **Regular security monitoring** by administrators
- **Timely application of security updates**

## Security Hardening

Additional hardening recommendations:

### System Hardening

```bash
# Run security environment check
./pf.py secure-env

# Review EFI variables for tampering
./pf.py test-qemu-uuefi

# Verify kernel module signatures
./sign-kernel-modules.sh --verify

# Check for suspicious boot parameters
cat /proc/cmdline
```

### Secure Boot Configuration

- **Enable Secure Boot** in UEFI firmware
- **Enroll custom keys** (PK, KEK, db)
- **Disable Setup Mode** after key enrollment
- **Remove untrusted keys** from db
- **Enable UEFI password** protection

### Network Security

For cloud/API components (if used):

- **Use HTTPS only** for all connections
- **Set strong Flask secret keys** via environment variables
- **Implement rate limiting** on API endpoints
- **Use authentication tokens** with expiration
- **Enable audit logging** for all API calls

## Security Updates

Security updates are distributed through:

- **GitHub Security Advisories**: For critical vulnerabilities
- **Release Notes**: Security fixes in CHANGELOG.md
- **Git Tags**: Security-focused releases marked with `security` tag
- **Pull Requests**: Security patches reviewed by maintainers

### Staying Updated

To stay informed about security updates:

1. **Watch** the repository for security advisories
2. **Subscribe** to release notifications
3. **Review** CHANGELOG.md regularly
4. **Check** GitHub security tab
5. **Follow** project announcements

## Security Tools

PhoenixBoot includes several security analysis tools:

### Built-in Security Tools

- **`secure-env`**: Comprehensive security validation
- **`UUEFI`**: EFI variable analysis and security heuristics
- **Module signing**: Kernel module signature management
- **Key generation**: Cryptographic key creation and management

### External Security Tools

Recommended external tools for security assessment:

- **CodeQL**: Static analysis (integrated in CI/CD)
- **chipsec**: Platform security assessment framework
- **UEFI Firmware Parser**: Firmware analysis tool
- **efibootmgr**: Boot configuration management
- **sbctl**: Secure Boot key management

## Compliance

PhoenixBoot aims to support:

- **UEFI Secure Boot Specification**
- **NIST Secure Boot Guidelines**
- **Common Criteria Protection Profiles** (where applicable)
- **Industry security best practices**

## Questions

For security-related questions that are not vulnerabilities:

- Open a GitHub issue with the `security` label
- Review existing [security documentation](docs/)
- Check the [Security Review document](SECURITY_REVIEW_2025-12-07.md)

---

**Security is everyone's responsibility.** Thank you for helping keep PhoenixBoot secure! 🔥🛡️
