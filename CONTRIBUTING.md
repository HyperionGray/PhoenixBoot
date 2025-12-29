# Contributing to PhoenixBoot

Thank you for your interest in contributing to PhoenixBoot! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Pull Request Process](#pull-request-process)
- [Reporting Issues](#reporting-issues)

## Code of Conduct

This project adheres to a Code of Conduct that all contributors are expected to follow. Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before contributing.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/PhoenixBoot.git
   cd PhoenixBoot
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/P4X-ng/PhoenixBoot.git
   ```
4. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## How to Contribute

### Types of Contributions

- **Bug fixes**: Fix issues reported in the issue tracker
- **New features**: Add new functionality to PhoenixBoot
- **Documentation**: Improve or add documentation
- **Tests**: Add or improve test coverage
- **Code quality**: Refactor code or improve performance

### Before Starting Work

1. **Check existing issues**: Look for existing issues or discussions about your idea
2. **Create an issue**: If one doesn't exist, create an issue to discuss your proposed changes
3. **Get feedback**: Wait for maintainer feedback before starting significant work
4. **Claim the issue**: Comment on the issue to let others know you're working on it

## Development Setup

### Prerequisites

- Linux system with UEFI firmware
- Python 3.8+ with venv
- Build tools: `gcc`, `make`, `git`
- QEMU for testing (optional but recommended)
- `efibootmgr`, `mokutil` for boot management
- EDK2 for building UEFI applications from source

### Setup Instructions

```bash
# Set up Python environment
python3 -m venv ~/.venv
source ~/.venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Verify setup
./pf.py --help
```

For detailed setup instructions, see [GETTING_STARTED.md](GETTING_STARTED.md).

## Coding Standards

### General Guidelines

- **Code quality**: Write clean, readable, and maintainable code
- **Comments**: Add comments for complex logic, but prefer self-documenting code
- **Error handling**: Handle errors appropriately with clear error messages
- **Security**: Follow security best practices, especially for boot-level code

### Python Code

- Follow PEP 8 style guidelines
- Use type hints where appropriate
- Maximum line length: 100 characters
- Use meaningful variable and function names

### Shell Scripts

- Use `#!/bin/bash` shebang
- Add error handling with `set -euo pipefail`
- Quote variables to prevent word splitting
- Add usage/help messages for user-facing scripts

### UEFI/EDK2 Code

- Follow EDK2 coding standards
- Use EDK2 libraries and protocols appropriately
- Ensure Secure Boot compatibility
- Test with OVMF/QEMU before submitting

## Testing Requirements

### Before Submitting

- **Run existing tests**: Ensure all existing tests pass
  ```bash
  ./pf.py test-qemu
  ```
- **Add new tests**: Add tests for new features or bug fixes
- **Test in QEMU**: Test UEFI changes in QEMU with OVMF
- **Test on hardware**: Test critical changes on real hardware (if possible)

### Test Coverage

- Add unit tests for utility functions
- Add integration tests for new features
- Ensure negative test cases are covered
- Document test scenarios in code comments

## Pull Request Process

### Creating a Pull Request

1. **Sync with upstream**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Commit your changes**:
   ```bash
   git add .
   git commit -m "Brief description of changes"
   ```
   
   Follow commit message guidelines:
   - Use present tense ("Add feature" not "Added feature")
   - Keep first line under 72 characters
   - Reference issues with `#issue_number`

3. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

4. **Open a Pull Request** on GitHub using the PR template

### PR Requirements

- [ ] Clear description of changes
- [ ] Tests added/updated
- [ ] Documentation updated (if applicable)
- [ ] All tests passing
- [ ] No merge conflicts
- [ ] Follows coding standards
- [ ] Security implications addressed

### Review Process

1. Maintainers will review your PR
2. Address any requested changes
3. Once approved, maintainers will merge your PR
4. Your changes will be included in the next release

## Reporting Issues

### Bug Reports

Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.yml) and include:

- Clear description of the issue
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, hardware, versions)
- Relevant logs or error messages

### Feature Requests

Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.yml) and include:

- Clear description of the feature
- Use case and benefits
- Proposed implementation (if any)
- Alternatives considered

### Security Issues

**Do not report security vulnerabilities in public issues!**

Please see [SECURITY.md](SECURITY.md) for instructions on reporting security issues.

## Questions?

- Check the [documentation](docs/)
- Read the [README](README.md)
- Search [existing issues](https://github.com/P4X-ng/PhoenixBoot/issues)
- Join our community discussions

## License

By contributing to PhoenixBoot, you agree that your contributions will be licensed under the Apache License 2.0. See [LICENSE.md](LICENSE.md) for details.

---

Thank you for contributing to PhoenixBoot! Your contributions help make firmware security more accessible to everyone.
