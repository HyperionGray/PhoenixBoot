# Security Policy

## 🔒 Security at PhoenixBoot

PhoenixBoot is a security-focused firmware defense system designed to protect against bootkits, rootkits, and supply chain attacks. We take security seriously and appreciate the security community's efforts to responsibly disclose vulnerabilities.

## 🛡️ Supported Versions

As PhoenixBoot is under active development and does not yet have formal releases, security updates are continuously applied to the main branch.

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| older branches | :x: |

**Recommendation**: Always use the latest code from the main branch for the most up-to-date security fixes.

## 🐛 Reporting a Vulnerability

### **IMPORTANT: Do NOT open public issues for security vulnerabilities**

If you discover a security vulnerability in PhoenixBoot, please report it responsibly using one of these methods:

### Preferred Methods

1. **GitHub Private Security Advisory** (Recommended)
   - Go to the [Security tab](https://github.com/P4X-ng/PhoenixBoot/security)
   - Click "Report a vulnerability"
   - Provide detailed information about the vulnerability
   - We will respond within 48 hours

2. **Direct Contact**
   - Contact the project maintainers directly through GitHub
   - Use the subject line: "SECURITY: [Brief Description]"
   - Include detailed information about the vulnerability

### What to Include in Your Report

Please provide as much information as possible:

- **Description** - Clear description of the vulnerability
- **Impact** - What could an attacker do with this vulnerability?
- **Affected Components** - Which files, scripts, or modules are affected?
- **Reproduction Steps** - Detailed steps to reproduce the issue
- **Proof of Concept** - Code, commands, or screenshots demonstrating the vulnerability
- **Proposed Fix** - If you have suggestions for fixing the issue
- **Environment** - OS, kernel version, firmware version, etc.

### Example Report Format

```
## Vulnerability Description
[Clear description of what the vulnerability is]

## Impact
[What an attacker could do if they exploited this]

## Affected Components
- File: path/to/file.py
- Function: vulnerable_function()
- Lines: 123-145

## Steps to Reproduce
1. Set up environment with...
2. Run command...
3. Observe that...

## Proof of Concept
[Code snippet or commands demonstrating the vulnerability]

## Suggested Fix
[Your recommendations for fixing the issue]

## Environment
- OS: Ubuntu 22.04
- Kernel: 5.15.0
- PhoenixBoot: main branch, commit abc123
```

## ⏱️ Response Timeline

We are committed to responding to security reports promptly:

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Depends on severity
  - Critical: Within 7 days
  - High: Within 14 days
  - Medium: Within 30 days
  - Low: Within 60 days

## 🔐 Security Update Process

1. **Acknowledgment** - We confirm receipt of your report
2. **Assessment** - We evaluate the severity and impact
3. **Development** - We develop and test a fix
4. **Coordination** - We coordinate disclosure timing with you
5. **Release** - We release the fix and publish a security advisory
6. **Credit** - We credit you (if desired) in the advisory

## 🎯 Scope

### In Scope

Security issues in:

- ✅ UEFI applications (NuclearBootEdk2.efi, KeyEnrollEdk2.efi, UUEFI.efi)
- ✅ Core scripts and tools (pf.py, task scripts)
- ✅ Key generation and signing mechanisms
- ✅ Secure Boot enforcement
- ✅ Boot chain verification
- ✅ Authentication and authorization
- ✅ Cryptographic implementations
- ✅ Input validation and sanitization
- ✅ Container security
- ✅ Supply chain security (dependencies)

### Out of Scope

- ❌ Issues in example or demonstration code (ideas/, examples_and_samples/demo/)
- ❌ Social engineering attacks
- ❌ Physical attacks requiring physical access (unless bypassing hardware protections)
- ❌ Issues in third-party dependencies (report to upstream, but we want to know too)
- ❌ Issues requiring compromised/malicious system administrator
- ❌ Theoretical attacks without proof of concept

**Note**: Even if something is marked "out of scope," we still want to know about it. We may address it or provide guidance.

## 🏆 Recognition

We appreciate security researchers and offer recognition:

- **Credit in Security Advisory** - Public acknowledgment (if desired)
- **Listed in security review documentation** - Documentation of findings
- **Listed in .mailmap** - Git history recognition
- **Mentioned in Changelog** - Release notes acknowledgment

**Note**: We currently do not offer a bug bounty program, but we deeply appreciate responsible disclosure and will acknowledge your contribution.

## 🔍 Known Security Considerations

### Current Security Features

PhoenixBoot implements multiple security layers:

- **Secure Boot Enforcement** - Cryptographic verification of boot chain
- **Runtime Attestation** - Binary hash verification
- **Key Management** - PK, KEK, db key generation and enrollment
- **MOK Integration** - Kernel module signing
- **Firmware Recovery** - Hardware-level recovery mechanisms
- **UEFI Variable Protection** - Security analysis and validation
- **Container Isolation** - Sandboxed build and runtime environments

### Security Hardening

- **Input Validation** - All user inputs are validated
- **Least Privilege** - Scripts request only necessary permissions
- **Defense in Depth** - Multiple security layers
- **Cryptographic Verification** - Hash-based integrity checks
- **Memory Safety** - EDK2-based UEFI applications
- **Dependency Scanning** - Automated vulnerability detection

## 🛠️ Security Best Practices for Contributors

When contributing to PhoenixBoot, please follow these security practices:

### Code Security

- ✅ **Never commit secrets** - No keys, passwords, tokens, or credentials
- ✅ **Validate all inputs** - Check user input, file contents, environment variables
- ✅ **Use parameterized queries** - Avoid command injection
- ✅ **Check dependencies** - Use `gh-advisory-database` before adding dependencies
- ✅ **Sanitize outputs** - Prevent information disclosure
- ✅ **Handle errors securely** - Don't expose sensitive information in errors
- ✅ **Use secure APIs** - Prefer secure alternatives (e.g., `subprocess.run` over `os.system`)

### Cryptographic Security

- ✅ **Use strong algorithms** - RSA-4096, SHA-256 minimum
- ✅ **Generate secure random values** - Use `/dev/urandom` or cryptographic libraries
- ✅ **Protect private keys** - Proper permissions, secure storage
- ✅ **Verify signatures** - Always verify cryptographic signatures
- ✅ **Use constant-time comparisons** - For security-sensitive operations

### Script Security

- ✅ **Quote variables** - Prevent word splitting and globbing
- ✅ **Check return codes** - Handle errors properly
- ✅ **Use absolute paths** - Prevent PATH manipulation
- ✅ **Validate file operations** - Check existence, permissions, ownership
- ✅ **Avoid `eval`** - Don't use `eval` or similar dynamic evaluation

## 📚 Security Resources

### Project Documentation

- [Security Considerations](docs/SECURITY_CONSIDERATIONS.md)
- [Boot Sequence and Attack Surfaces](docs/BOOT_SEQUENCE_AND_ATTACK_SURFACES.md)
- [Kernel Hardening Guide](docs/KERNEL_HARDENING_GUIDE.md)
- [Architecture Documentation](ARCHITECTURE.md)

### External Resources

- [UEFI Security](https://uefi.org/security)
- [Secure Boot](https://uefi.org/specs/UEFI/2.10/32_Secure_Boot_and_Driver_Signing.html)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [OWASP Security Guidelines](https://owasp.org/)

## 🔄 Security Updates

Subscribe to security updates:

1. **Watch the repository** - Enable notifications for security advisories
2. **GitHub Security Advisories** - Check the [Security tab](https://github.com/P4X-ng/PhoenixBoot/security/advisories)
3. **Release Notes** - Review [CHANGELOG.md](CHANGELOG.md) for security fixes

## 📧 Security Contact

For sensitive security issues that cannot be reported through GitHub:

- Open a private security advisory on GitHub (preferred)
- Contact project maintainers directly

**Please do not discuss security issues in public channels until they are resolved.**

## ⚖️ Disclosure Policy

### Coordinated Disclosure

We follow a coordinated disclosure process:

1. **Report** - You report the vulnerability privately
2. **Acknowledge** - We confirm receipt within 48 hours
3. **Fix** - We develop, test, and release a fix
4. **Coordinate** - We agree on a disclosure date with you
5. **Disclose** - We publish a security advisory together

### Public Disclosure Timeline

- **Minimum**: 7 days after fix is released
- **Preferred**: 30 days after fix is released
- **Maximum**: 90 days after initial report (unless special circumstances)

We request that you do not publicly disclose the vulnerability until:
- A fix has been released
- We have published a security advisory
- The agreed-upon disclosure date has arrived

## 📜 Security Reviews

For transparency, we document security reviews. Past security reviews are available in the repository and referenced in the project documentation.

## ❓ Questions?

If you have questions about this security policy:

1. Review this document thoroughly
2. Check existing security documentation
3. Open a GitHub Discussion (for non-sensitive questions)
4. Contact maintainers directly (for sensitive questions)

Thank you for helping keep PhoenixBoot secure! 🔒
