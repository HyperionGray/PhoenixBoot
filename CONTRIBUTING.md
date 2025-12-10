# Contributing to PhoenixBoot

Thank you for your interest in contributing to PhoenixBoot! This document provides guidelines for contributing to our secure boot defense system.

## 🔥 Welcome Contributors!

PhoenixBoot is a production-ready firmware defense system, and we welcome contributions that help improve security, usability, and functionality. Whether you're fixing bugs, adding features, improving documentation, or enhancing tests, your contributions are valuable.

## 📋 Table of Contents

- [Getting Started](#getting-started)
- [Development Environment](#development-environment)
- [Contribution Guidelines](#contribution-guidelines)
- [Code Standards](#code-standards)
- [Testing Requirements](#testing-requirements)
- [Security Considerations](#security-considerations)
- [Pull Request Process](#pull-request-process)
- [Issue Reporting](#issue-reporting)
- [Community Guidelines](#community-guidelines)

## 🚀 Getting Started

### Prerequisites

Before contributing, ensure you have:

- Linux system with UEFI firmware
- Python 3.8+ with venv
- Build tools: `gcc`, `make`, `git`
- QEMU for testing (recommended)
- `efibootmgr`, `mokutil` for boot management
- EDK2 for building UEFI applications from source
- Docker/Podman for container-based development

### Initial Setup

1. **Fork the repository** on GitHub
2. **Clone your fork**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/PhoenixBoot.git
   cd PhoenixBoot
   ```
3. **Set up development environment**:
   ```bash
   # Set up Python environment
   python3 -m venv ~/.venv
   source ~/.venv/bin/activate
   
   # Install dependencies (if requirements.txt exists)
   pip install -r requirements.txt
   
   # Test the setup
   ./pf.py list
   ```
4. **Run initial tests**:
   ```bash
   ./pf.py test-qemu
   ```

## 🛠️ Development Environment

### Container-Based Development (Recommended)

PhoenixBoot uses a container-based architecture for reproducible development:

```bash
# Build development containers
docker-compose --profile build up

# Run tests in containers
docker-compose --profile test up

# Launch interactive TUI
docker-compose --profile tui up
```

### Task Runner (pf.py)

All development tasks use the `pf.py` task runner:

```bash
# List all available tasks
./pf.py list

# Build and package
./pf.py setup

# Run tests
./pf.py test-e2e-all

# Lint and format code
./pf.py lint
./pf.py format
```

## 📝 Contribution Guidelines

### Types of Contributions

We welcome:

- **🐛 Bug fixes** - Fix issues in existing functionality
- **✨ New features** - Add new security features or tools
- **📚 Documentation** - Improve guides, comments, and examples
- **🧪 Tests** - Add or improve test coverage
- **🔧 Infrastructure** - Improve build, CI/CD, or development tools
- **🔐 Security** - Enhance security features or fix vulnerabilities

### Before You Start

1. **Check existing issues** - Look for related issues or discussions
2. **Create an issue** - For significant changes, create an issue first to discuss
3. **Review documentation** - Read relevant docs in the `docs/` directory
4. **Understand the architecture** - Review `docs/CONTAINER_ARCHITECTURE.md`

## 📏 Code Standards

### General Guidelines

- **Follow existing patterns** - Maintain consistency with existing code
- **Write clear comments** - Especially for security-critical code
- **Use descriptive names** - Variables, functions, and files should be self-documenting
- **Keep functions focused** - Single responsibility principle
- **Handle errors gracefully** - Proper error handling and logging

### Python Code Standards

- **PEP 8 compliance** - Use standard Python formatting
- **Type hints** - Add type hints for function parameters and returns
- **Docstrings** - Document all public functions and classes
- **Error handling** - Use appropriate exception handling

Example:
```python
def sign_kernel_module(module_path: str, cert_path: str) -> bool:
    """Sign a kernel module with the specified certificate.
    
    Args:
        module_path: Path to the kernel module (.ko file)
        cert_path: Path to the signing certificate
        
    Returns:
        True if signing successful, False otherwise
        
    Raises:
        FileNotFoundError: If module or certificate not found
        SecurityError: If signing fails due to security constraints
    """
    # Implementation here
```

### Shell Script Standards

- **Use bash explicitly** - `#!/bin/bash` shebang
- **Set strict mode** - `set -euo pipefail`
- **Quote variables** - Always quote variable expansions
- **Check dependencies** - Verify required tools are available
- **Provide usage help** - Include help text and examples

### UEFI/C Code Standards

- **EDK2 conventions** - Follow EDK2 coding standards
- **Memory safety** - Careful memory management
- **Error checking** - Check all return values
- **Security first** - Validate all inputs and assumptions

## 🧪 Testing Requirements

### Test Categories

All contributions should include appropriate tests:

1. **Unit tests** - Test individual functions and components
2. **Integration tests** - Test component interactions
3. **End-to-end tests** - Test complete workflows
4. **Security tests** - Test security features and edge cases

### Running Tests

```bash
# Run all tests
./pf.py test-e2e-all

# Run specific test categories
./pf.py test-qemu                    # Basic QEMU tests
./pf.py test-qemu-secure-positive    # Secure Boot tests
./pf.py test-qemu-uuefi             # UUEFI diagnostic tests

# Run in containers
docker-compose --profile test up
```

### Test Requirements

- **All tests must pass** - No failing tests in pull requests
- **Add tests for new features** - New functionality requires tests
- **Test edge cases** - Include error conditions and boundary cases
- **Security test coverage** - Security features need comprehensive testing

## 🔐 Security Considerations

### Security-First Development

PhoenixBoot is a security tool, so security considerations are paramount:

- **Validate all inputs** - Never trust user input or external data
- **Principle of least privilege** - Minimize required permissions
- **Secure defaults** - Default configurations should be secure
- **Cryptographic best practices** - Use established crypto libraries and patterns
- **Audit trails** - Log security-relevant operations

### Security Review Process

- **Security-sensitive changes** require additional review
- **Cryptographic changes** must be reviewed by security-knowledgeable maintainers
- **Key management changes** require special attention
- **Boot process modifications** need thorough testing

### Vulnerability Reporting

If you discover a security vulnerability:

1. **Do NOT create a public issue**
2. **Follow our security policy** - See [SECURITY.md](SECURITY.md)
3. **Contact maintainers privately** - Use secure communication channels
4. **Provide detailed information** - Steps to reproduce, impact assessment

## 🔄 Pull Request Process

### Before Submitting

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. **Make your changes** following the guidelines above
3. **Test thoroughly**:
   ```bash
   ./pf.py test-e2e-all
   ./pf.py lint
   ```
4. **Update documentation** if needed
5. **Commit with clear messages**:
   ```bash
   git commit -m "feat: add kernel module signature verification
   
   - Add signature validation for kernel modules
   - Include tests for valid and invalid signatures
   - Update documentation with usage examples"
   ```

### Pull Request Guidelines

- **Clear title and description** - Explain what and why
- **Reference related issues** - Use "Fixes #123" or "Relates to #456"
- **Include test results** - Show that tests pass
- **Update CHANGELOG.md** - Add entry for significant changes
- **Request appropriate reviewers** - Tag relevant maintainers

### Review Process

1. **Automated checks** - CI/CD pipeline runs automatically
2. **Code review** - Maintainers review code quality and security
3. **Testing verification** - Ensure all tests pass
4. **Documentation review** - Check that docs are updated
5. **Security review** - Additional review for security-sensitive changes

## 🐛 Issue Reporting

### Bug Reports

When reporting bugs, include:

- **Clear description** - What happened vs. what was expected
- **Steps to reproduce** - Detailed reproduction steps
- **Environment details** - OS, Python version, hardware details
- **Logs and output** - Relevant log files and error messages
- **Security impact** - If the bug has security implications

### Feature Requests

For feature requests, include:

- **Use case description** - Why is this feature needed?
- **Proposed solution** - How should it work?
- **Alternatives considered** - Other approaches you've thought about
- **Security considerations** - How does this affect security?

### Issue Templates

Use the provided issue templates when available, or follow the structure above.

## 🤝 Community Guidelines

### Code of Conduct

This project follows our [Code of Conduct](CODE_OF_CONDUCT.md). Please read and follow it in all interactions.

### Communication Channels

- **GitHub Issues** - Bug reports, feature requests, discussions
- **Pull Requests** - Code contributions and reviews
- **Documentation** - In-repo documentation for technical details

### Getting Help

- **Check documentation** - Start with `docs/` directory
- **Search existing issues** - Your question might already be answered
- **Create an issue** - For questions not covered elsewhere
- **Be specific** - Provide context and details

## 📚 Additional Resources

### Documentation

- [README.md](README.md) - Project overview and quick start
- [docs/](docs/) - Comprehensive technical documentation
- [GETTING_STARTED.md](GETTING_STARTED.md) - Beginner's guide
- [docs/CONTAINER_ARCHITECTURE.md](docs/CONTAINER_ARCHITECTURE.md) - Development architecture

### Development Tools

- [pf-runner](https://github.com/P4X-ng/pf-runner) - Task runner documentation
- [EDK2](https://github.com/tianocore/edk2) - UEFI development framework
- [QEMU](https://www.qemu.org/) - Testing and virtualization

## 🎯 Recognition

Contributors are recognized in:

- **Git history** - Your commits are permanently recorded
- **Release notes** - Significant contributions mentioned in releases
- **Documentation** - Contributors acknowledged in relevant docs

## 📞 Contact

For questions about contributing:

- **Create an issue** - For general questions and discussions
- **Security concerns** - Follow [SECURITY.md](SECURITY.md) guidelines
- **Maintainer contact** - Through GitHub issues and pull requests

---

Thank you for contributing to PhoenixBoot! Your efforts help make boot security more accessible and robust for everyone. 🔥

**Made with 🔥 for a more secure boot process**