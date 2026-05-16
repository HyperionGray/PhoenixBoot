# Contributing to PhoenixBoot

Thank you for your interest in contributing to PhoenixBoot! This document provides guidelines for contributing to the project.

## 🚀 Getting Started

### Prerequisites

- Python 3.8 or higher
- Podman (for container-based workflows)
- Git
- QEMU (for testing UEFI components)
- EDK2 toolchain (for UEFI firmware development)

### Setting Up Your Development Environment

1. Fork and clone the repository:
   ```bash
   git clone https://github.com/YOUR_USERNAME/PhoenixBoot.git
   cd PhoenixBoot
   ```

2. If you are contributing from a fork, add the main repository as `upstream`:
   ```bash
   git remote add upstream https://github.com/P4X-ng/PhoenixBoot.git
   ```

3. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Verify your setup:
   ```bash
   ./pf.py --help
   ```

## 📋 How to Contribute

### Reporting Bugs

Before creating a bug report, please check existing issues to avoid duplicates.
Use the bug report template when it fits the issue.

When reporting a bug, include:
- A clear and descriptive title
- Steps to reproduce the issue
- Expected vs. actual behavior
- Your environment (OS, Python version, UEFI firmware version)
- Output from `./pf.py secure-env` for security-related issues
- Relevant logs or error messages

### Suggesting Enhancements

Enhancement suggestions are welcome! Please include:
- A clear description of the proposed feature
- Use cases and benefits
- Any potential drawbacks or implementation challenges
- Mock-ups or examples if applicable

Use the feature request template when it fits the proposal.

### Pull Requests

For significant changes, open or reference an issue first so the direction is clear before you start.

1. **Create a branch** for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**:
   - Follow the existing code style
   - Add tests for new functionality
   - Update documentation as needed
   - Keep commits focused and atomic

3. **Test your changes**:
   ```bash
   # Run linting
   black . && flake8
   
   # Run tests
   pytest tests/
   
   # Test UEFI components (if applicable)
   ./pf.py workflow-test-uuefi
   ```

4. **Commit your changes**:
   - Use clear, descriptive commit messages
   - Follow conventional commits format: `type(scope): description`
   - Examples: `feat(uuefi): add variable editing`, `fix(secure-boot): handle missing keys`

5. **Push and create a pull request**:
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Before opening the pull request, verify the checklist**:
   - Tests added or updated when behavior changed
   - Documentation updated where needed
   - Security-sensitive changes clearly called out
   - No merge conflicts with the current `main` branch

## 🎨 Code Style

### Python Code

- Follow PEP 8 style guidelines
- Use Black for code formatting: `black .`
- Use type hints where appropriate
- Maximum line length: 100 characters
- Write docstrings for all public functions and classes

### Shell Scripts

- Use `#!/bin/bash` shebang
- Include error handling with `set -e` or explicit error checks
- Add comments for complex logic
- Test scripts with `shellcheck`

### C/UEFI Code

- Follow EDK2 coding standards
- Use proper memory management
- Include error checking for all EFI function calls
- Document non-obvious behavior

## 🧪 Testing

### Running Tests

```bash
# Unit tests
pytest tests/

# Integration tests
pytest tests/ -m integration

# UEFI component tests
./pf.py workflow-test-uuefi

# Container-based tests
podman compose --profile test up
```

### Writing Tests

- Write tests for all new functionality
- Follow existing test patterns in `tests/` directory
- Use descriptive test names: `test_function_name_scenario_expected_result`
- Include both positive and negative test cases

## 🔒 Security

### Security-Sensitive Code

When working with security-critical components:
- Avoid `subprocess.run(shell=True)` - use command lists instead
- Validate all user inputs
- Use cryptography library functions correctly
- Document security implications in code comments
- Add security warnings for sensitive operations

### Reporting Security Vulnerabilities

**Do not report security vulnerabilities through public GitHub issues.**

Instead, please report them by:
1. Using GitHub's Security Advisory feature
2. Or emailing the maintainers privately (see SECURITY.md)

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fixes (if any)

## 📚 Documentation

### Documentation Standards

- Write clear, concise documentation
- Include code examples where helpful
- Keep documentation up-to-date with code changes
- Use proper Markdown formatting

### Documentation Files

When updating documentation:
- **README.md**: High-level project overview and quick start
- **docs/**: Detailed guides and tutorials
- **docs/bak/**: Archived or superseded documents that should not present as current guidance
- **Code comments**: Explain "why", not just "what"
- **Docstrings**: Document function parameters, return values, and exceptions

## 🏗️ Project Structure

```
PhoenixBoot/
├── pf.py                   # Main task runner
├── pf_parser.py            # Task parser
├── scripts/                # Utility scripts
├── staging/                # UEFI component staging
│   └── src/                # UEFI source code (C)
├── utils/                  # Python utility modules
├── tests/                  # Test suite
├── docs/                   # Documentation
├── examples_and_samples/   # Example code and demos
└── containers/             # Container definitions
```

## 📝 Commit Message Guidelines

Use conventional commits format:

```
type(scope): subject

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Test additions or changes
- `chore`: Build process or auxiliary tool changes
- `security`: Security fixes or improvements

**Examples:**
```
feat(uuefi): add EFI variable editing functionality

Implements safe variable editing with validation and
rollback support for UUEFI diagnostic tool.

Closes #123
```

```
fix(secure-boot): handle missing key enrollment

Adds proper error handling when PK key is missing
during enrollment process.
```

## 🤝 Community Guidelines

### Code of Conduct

We are committed to providing a welcoming and inclusive environment. Please:
- Be respectful and considerate
- Focus on constructive feedback
- Help others learn and grow
- Report unacceptable behavior

See CODE_OF_CONDUCT.md for full details.

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and discussions
- **Pull Requests**: Code contributions and reviews

## 🏆 Recognition

Contributors are recognized in:
- Git commit history
- Release notes and changelogs
- Project documentation

Significant contributions may be highlighted in:
- Project README
- Special acknowledgments sections

## 📜 License

By contributing to PhoenixBoot, you agree that your contributions will be licensed under the Apache License 2.0 (see LICENSE.md).

## 🎯 Priority Areas

Current priority areas for contributions:

1. **Testing**: Expand test coverage for UEFI components
2. **Documentation**: Improve guides and tutorials
3. **Hardware Support**: Test and document support for additional hardware
4. **Security**: Security audits and vulnerability fixes
5. **User Experience**: Improve interactive tools and wizards

## 📞 Questions?

If you have questions about contributing:
- Check existing documentation
- Search through GitHub issues
- Open a new discussion on GitHub
- Review similar pull requests

Thank you for contributing to PhoenixBoot! Together, we can build a more secure boot process for everyone.

---

**🔥 PhoenixBoot: Stop bootkits, period.**
