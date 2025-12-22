# Contributing to PhoenixBoot

Thank you for your interest in contributing to PhoenixBoot! This document provides guidelines for contributing to the project.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Testing](#testing)
- [Documentation](#documentation)

## Code of Conduct

This project adheres to a Code of Conduct that all contributors are expected to follow. Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before contributing.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, include:

- **Clear title and description**
- **Steps to reproduce** the issue
- **Expected vs actual behavior**
- **Environment details** (OS, UEFI version, hardware)
- **Relevant logs or screenshots**

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When suggesting an enhancement:

- **Use a clear and descriptive title**
- **Provide detailed explanation** of the proposed feature
- **Explain why this enhancement would be useful**
- **Include examples** if applicable

### Security Vulnerabilities

**Do not report security vulnerabilities through public GitHub issues.** Please follow the responsible disclosure process outlined in [SECURITY.md](SECURITY.md).

### Code Contributions

1. **Fork the repository** and create your branch from `main`
2. **Make your changes** following our coding standards
3. **Write or update tests** as needed
4. **Update documentation** to reflect your changes
5. **Submit a pull request**

## Development Setup

### Prerequisites

- Linux system with UEFI firmware
- Python 3.8+ with venv
- Docker and Docker Compose (optional, for container-based development)
- GNU Make
- Git

### Quick Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/PhoenixBoot.git
cd PhoenixBoot

# Install dependencies
pip install -r requirements.txt

# Run tests to verify setup
make direct-test
```

### Container-Based Development (Recommended)

```bash
# Build all containers
make build

# Launch interactive TUI
make run-tui

# Run tests in container
make run-test

# Open shell in build container
make shell-build
```

For detailed setup instructions, see [GETTING_STARTED.md](GETTING_STARTED.md).

## Coding Standards

### Python Code

- Follow **PEP 8** style guide
- Use **type hints** where appropriate
- Write **docstrings** for functions and classes
- Maximum line length: **100 characters**
- Use **meaningful variable names**

### Shell Scripts

- Use **bash** for shell scripts
- Include **shebang** (`#!/bin/bash`)
- Add **comments** for complex logic
- Use **shellcheck** for validation

### C/C++ Code (UEFI Applications)

- Follow **EDK2 coding standards**
- Use **consistent indentation** (2 or 4 spaces)
- Include **header comments** with file description
- Document **function parameters** and return values

### Example Python Code

```python
def validate_secure_boot_status(efi_vars_path: str) -> bool:
    """
    Validates Secure Boot configuration status.
    
    Args:
        efi_vars_path: Path to EFI variables directory
        
    Returns:
        True if Secure Boot is properly configured, False otherwise
        
    Raises:
        FileNotFoundError: If EFI variables path does not exist
    """
    # Implementation here
    pass
```

## Commit Guidelines

### Commit Message Format

```
<type>: <subject>

<body>

<footer>
```

### Types

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, no logic change)
- **refactor**: Code refactoring
- **test**: Adding or updating tests
- **chore**: Maintenance tasks

### Examples

```
feat: add UEFI variable enumeration to UUEFI tool

Implements complete EFI variable enumeration with descriptions
and categorization. Includes security heuristics engine to detect
suspicious variables.

Closes #123
```

```
fix: resolve memory leak in ESP package creation

Fixed memory leak when creating bootable ESP images by properly
releasing allocated buffers.
```

## Pull Request Process

1. **Update documentation** for any changed functionality
2. **Add tests** for new features or bug fixes
3. **Ensure all tests pass** locally
4. **Update CHANGELOG.md** with your changes
5. **Create pull request** with clear description
6. **Address review feedback** promptly

### Pull Request Template

Your PR should include:

- **Description** of changes
- **Related issue** numbers (if applicable)
- **Testing performed**
- **Breaking changes** (if any)
- **Checklist** of completed items

### Review Process

- PRs require at least one approval from a maintainer
- All CI checks must pass
- Security scans must complete without critical issues
- Documentation must be updated

## Testing

### Running Tests

```bash
# Run all tests directly
make direct-test

# Run tests in container
make run-test

# Run specific test workflow
./pf.py test-qemu-uuefi
```

### Writing Tests

- Place tests in the `tests/` directory
- Follow existing test patterns
- Include both positive and negative test cases
- Mock external dependencies when appropriate

### Test Coverage

- Aim for high test coverage on new code
- Critical security functions require comprehensive tests
- Include integration tests for complex workflows

## Documentation

### Where to Document

- **Code comments**: Explain complex logic
- **Docstrings**: All public functions and classes
- **README.md**: Project overview and quick start
- **docs/**: Detailed guides and tutorials
- **CHANGELOG.md**: All notable changes

### Documentation Standards

- Use **Markdown** for documentation files
- Include **code examples** where helpful
- Add **diagrams** for complex concepts
- Keep documentation **up-to-date** with code changes

### Documentation Structure

```
docs/
├── GETTING_STARTED.md      # Getting started guide
├── ARCHITECTURE.md          # Architecture overview
├── CONTAINER_ARCHITECTURE.md # Container details
├── SECURE_ENV_COMMAND.md    # Feature documentation
└── ...
```

## Questions?

If you have questions about contributing:

1. Check existing [documentation](docs/)
2. Search [existing issues](https://github.com/P4X-ng/PhoenixBoot/issues)
3. Ask in a new issue with the `question` label

## License

By contributing to PhoenixBoot, you agree that your contributions will be licensed under the Apache License 2.0. See [LICENSE.md](LICENSE.md) for details.

---

Thank you for contributing to PhoenixBoot! 🔥
