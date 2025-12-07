# Contributing to PhoenixBoot

Thank you for your interest in contributing to PhoenixBoot! This document provides guidelines for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)
- [Pull Request Process](#pull-request-process)

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md). Please read it before contributing.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/PhoenixBoot.git
   cd PhoenixBoot
   ```
3. **Set up your development environment**:
   ```bash
   # Set up Python environment
   python3 -m venv ~/.venv
   source ~/.venv/bin/activate
   
   # Install dependencies (if requirements.txt exists)
   pip install -r requirements.txt
   ```
4. **Create a branch** for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## How to Contribute

### Reporting Bugs

- **Check existing issues** to avoid duplicates
- **Use the bug report template** when available
- **Include detailed information**:
  - Steps to reproduce
  - Expected behavior
  - Actual behavior
  - System information (OS, firmware version, etc.)
  - Relevant logs or error messages

### Suggesting Features

- **Check existing feature requests** to avoid duplicates
- **Provide clear use cases** and benefits
- **Be specific** about what you'd like to see
- **Consider security implications** of the feature

### Contributing Code

We welcome contributions of all kinds:

- Bug fixes
- New features
- Performance improvements
- Documentation improvements
- Test coverage improvements

## Development Workflow

### Using the Task Runner

PhoenixBoot uses `pf.py` as its primary interface:

```bash
# List all available tasks
./pf.py list

# Run tests
./pf.py test-qemu

# Build artifacts
./pf.py build-build

# Package ESP
./pf.py build-package-esp
```

### Container-Based Development

PhoenixBoot supports container-based development:

```bash
# Build containers
docker-compose build

# Run tests in container
docker-compose --profile test up

# Launch TUI
docker-compose --profile tui up
```

## Coding Standards

### General Guidelines

- **Write clear, maintainable code** with meaningful variable names
- **Add comments** for complex logic or security-critical sections
- **Follow existing code style** in the files you modify
- **Keep functions focused** on a single responsibility
- **Avoid unnecessary changes** - make minimal, surgical modifications

### Shell Scripts

- Use `bash` for shell scripts
- Include shebang: `#!/usr/bin/env bash`
- Use `set -euo pipefail` for safety
- Quote variables: `"${VAR}"`
- Add error handling and validation

### Python Code

- Follow PEP 8 style guidelines
- Use type hints where appropriate
- Include docstrings for functions and classes
- Handle exceptions appropriately

### C/UEFI Code

- Follow EDK2 coding standards for UEFI applications
- Use safe string handling functions
- Validate all inputs
- Document security-critical sections

## Testing

### Running Tests

```bash
# Run QEMU tests
./pf.py test-qemu
./pf.py test-qemu-secure-positive
./pf.py test-qemu-uuefi

# Run all end-to-end tests
./pf.py test-e2e-all
```

### Writing Tests

- **Add tests** for new features and bug fixes
- **Follow existing test patterns** in the repository
- **Test security-critical code** thoroughly
- **Include both positive and negative test cases**
- **Test on real hardware** when possible (especially for firmware-level changes)

### Test Coverage

- Aim for good test coverage of new code
- QEMU tests validate boot sequences
- Integration tests verify security features
- Unit tests cover utility functions

## Documentation

### Code Documentation

- Add comments explaining **why**, not just **what**
- Document security considerations
- Include usage examples for new features
- Update relevant documentation files

### Documentation Files

When adding features, update:

- **README.md** - For user-facing features
- **docs/** - For technical documentation
- **CHANGELOG.md** - For all notable changes

## Pull Request Process

### Before Submitting

1. **Test your changes** thoroughly
2. **Update documentation** as needed
3. **Ensure your code follows** coding standards
4. **Commit with clear messages**:
   ```bash
   git commit -m "feat: Add X feature for Y purpose"
   git commit -m "fix: Resolve Z issue in component A"
   ```
5. **Rebase on latest main** if needed:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

### Submitting the PR

1. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```
2. **Create a Pull Request** on GitHub
3. **Fill out the PR template** completely
4. **Link related issues** using keywords (e.g., "Fixes #123")
5. **Request review** from maintainers

### PR Requirements

- **All tests must pass** in CI
- **Code must be reviewed** by at least one maintainer
- **Documentation must be updated** if applicable
- **Security implications must be addressed**
- **Commit history should be clean**

### Review Process

- Maintainers will review your PR
- Address feedback and update your PR
- Discussion may occur in PR comments
- Once approved, maintainers will merge your PR

## Security Contributions

### Reporting Security Vulnerabilities

**Do not open public issues for security vulnerabilities.**

Please see our [Security Policy](SECURITY.md) for how to report security issues.

### Security-Focused Contributions

When contributing security features:

- **Document threat models** you're addressing
- **Explain security benefits** clearly
- **Test thoroughly** including negative cases
- **Consider edge cases** and attack vectors
- **Follow secure coding practices**

## Questions?

If you have questions about contributing:

- **Check the documentation** in the `docs/` directory
- **Open a discussion** on GitHub Discussions
- **Ask in issues** for specific feature questions

## Recognition

Contributors will be recognized in:

- Git commit history
- Release notes (CHANGELOG.md)
- Project documentation

Thank you for helping make PhoenixBoot more secure! 🔥
