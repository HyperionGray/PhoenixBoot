# Security Policy

## Reporting Security Vulnerabilities

**DO NOT** create public GitHub issues for security vulnerabilities.

The PhoenixBoot project takes security seriously. We appreciate your efforts to responsibly disclose your findings.

### How to Report

Please report security vulnerabilities by emailing the project maintainers directly:

- Create a private security advisory on GitHub
- Or open a confidential issue with details about the vulnerability
- Include as much information as possible to help us understand and resolve the issue

### What to Include

When reporting a vulnerability, please include:

1. **Description** - Clear description of the vulnerability
2. **Impact** - What an attacker could achieve
3. **Affected Components** - Which parts of PhoenixBoot are affected
4. **Steps to Reproduce** - Detailed steps to reproduce the vulnerability
5. **Proposed Fix** (optional) - If you have suggestions for fixing the issue

### Response Timeline

- **Initial Response**: We will acknowledge receipt within 48 hours
- **Status Update**: We will provide a status update within 7 days
- **Fix Timeline**: We aim to release security fixes within 30 days for critical vulnerabilities

## Security Best Practices

### For Users

1. **Keep Updated**: Always use the latest version of PhoenixBoot
2. **Verify Downloads**: Check signatures and checksums when downloading
3. **Secure Keys**: Protect your Secure Boot keys - they are critical to your system security
4. **Hardware Access**: Restrict physical access to systems running PhoenixBoot recovery tools
5. **Review Before Use**: Always review scripts and code before running with elevated privileges

### For Developers

1. **Never Commit Secrets**: Do not commit API keys, passwords, or private keys
2. **Use Environment Variables**: Store sensitive configuration in environment variables
3. **Input Validation**: Always validate and sanitize user input
4. **Subprocess Security**: Avoid \`shell=True\` in subprocess calls; use command lists instead
5. **Code Review**: All security-sensitive code must be reviewed by at least two developers
6. **Dependency Updates**: Keep dependencies updated to patch known vulnerabilities
7. **Security Testing**: Run security scanners (CodeQL, Bandit, etc.) before merging

## Security Features

PhoenixBoot implements multiple security layers:

1. **Secure Boot Enforcement**: UEFI Secure Boot with custom key hierarchy (PK, KEK, db)
2. **Cryptographic Verification**: RSA-4096 signatures on all bootable components
3. **Runtime Attestation**: Continuous verification of firmware integrity
4. **Bootkit Detection**: Real-time scanning for firmware modifications
5. **Hardware Recovery**: SPI flash recovery for compromised systems

## Known Security Considerations

### Development vs. Production

Some files contain development-only security settings:

- \`web/hardware_database_server.py\` - Demo web server with hardcoded secret (development only)
- \`ideas/cloud_integration/api_endpoints.py\` - Example API with insecure default secret (development only)

**These files should NEVER be deployed to production without proper configuration.**

## License

This security policy is part of the PhoenixBoot project and is released under the same Apache 2.0 license.
