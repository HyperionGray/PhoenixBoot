# Contributing to PhoenixBoot

Thank you for your interest in contributing to PhoenixBoot! This document provides guidelines for contributing to the project.

## 🚀 Quick Start

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/PhoenixBoot.git`
3. Create a branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test your changes thoroughly
6. Commit your changes: `git commit -m "Description of changes"`
7. Push to your fork: `git push origin feature/your-feature-name`
8. Open a Pull Request

## 📋 Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## 🎯 Types of Contributions

We welcome the following types of contributions:

### �� Bug Reports
- Use the GitHub issue tracker
- Include system information (OS, UEFI version, hardware)
- Provide steps to reproduce
- Include relevant logs and error messages

### ✨ Feature Requests
- Check existing issues first
- Clearly describe the feature and its use case
- Explain why it would be valuable to PhoenixBoot users

### 💻 Code Contributions
- Bug fixes
- New features
- Documentation improvements
- Test coverage improvements
- Performance optimizations

### 📚 Documentation
- Fix typos or clarify existing documentation
- Add examples and use cases
- Translate documentation
- Improve README and guides

## 🔧 Development Setup

### Prerequisites
- Python 3.11 or higher
- Git
- Linux environment (or WSL2 on Windows)
- Root/sudo access for UEFI operations

### Setting Up Development Environment

```bash
# Clone the repository
git clone https://github.com/P4X-ng/PhoenixBoot.git
cd PhoenixBoot

# Install dependencies
pip install -r requirements.txt

# Run tests
pytest tests/

# Try the interactive wizard
./phoenixboot-wizard.sh
```

### Using Docker for Development

```bash
# Build all containers
docker-compose --profile build up

# Run tests
docker-compose --profile test up

# Launch TUI
docker-compose --profile tui up
```

## 📝 Coding Standards

### Python Code
- Follow PEP 8 style guidelines
- Use type hints where appropriate
- Write docstrings for functions and classes
- Keep functions focused and small
- Add comments for complex logic

### Shell Scripts
- Use `#!/bin/bash` shebang
- Quote variables: `"$variable"`
- Check command success: `|| exit 1`
- Add help messages: `-h` or `--help`
- Test with `shellcheck`

### Security Requirements
- Never commit secrets or credentials
- Use environment variables for sensitive data
- Avoid `subprocess.run(shell=True)` when possible
- Validate all user inputs
- Document security considerations

### Documentation
- Use clear, concise language
- Include code examples
- Add screenshots for UI changes
- Keep documentation up to date with code changes

## 🧪 Testing

### Running Tests

```bash
# Run all tests
pytest

# Run specific test file
pytest tests/test_specific.py

# Run with coverage
pytest --cov=./ --cov-report=html
```

### Writing Tests
- Write tests for new features
- Update tests when modifying existing code
- Aim for good coverage of critical paths
- Use meaningful test names
- Include both positive and negative test cases

## 📤 Submitting Changes

### Pull Request Process

1. **Before submitting:**
   - Ensure all tests pass
   - Update documentation
   - Add entry to CHANGELOG.md if applicable
   - Verify no security vulnerabilities (run `gh-advisory-database` check)

2. **Pull Request Description:**
   - Clear title describing the change
   - Reference any related issues
   - List what was changed and why
   - Include screenshots for UI changes
   - Note any breaking changes

3. **Review Process:**
   - Maintainers will review your PR
   - Address feedback and questions
   - Keep PR focused on a single change
   - Be patient and respectful

### Commit Messages

Write clear commit messages:

```
Short summary (50 chars or less)

More detailed explanation if needed. Wrap at 72 characters.
Explain what and why, not how.

- Bullet points are okay
- Reference issues: Fixes #123

Co-authored-by: Name <email@example.com>
```

## 🏗️ Project Structure

```
PhoenixBoot/
├── core.pf              # Core functionality
├── secure.pf            # Secure boot components
├── workflows.pf         # Workflow definitions
├── pf.py               # Main Python script
├── scripts/            # Utility scripts
│   ├── recovery/       # Recovery tools
│   ├── secure-boot/    # Secure boot tools
│   └── testing/        # Test scripts
├── utils/              # Utility modules
├── docs/               # Documentation
├── tests/              # Test suite
└── examples_and_samples/ # Example code
```

## 🔒 Security

### Reporting Security Vulnerabilities

**DO NOT** open public issues for security vulnerabilities.

Please see [SECURITY.md](SECURITY.md) for how to report security issues.

### Security Best Practices
- Review [SECURITY.md](SECURITY.md) before contributing
- Run security scans before submitting PRs
- Follow secure coding guidelines
- Be cautious with dependencies

## 📞 Getting Help

### Resources
- **Documentation:** [README.md](README.md)
- **Quick Start:** [GETTING_STARTED.md](GETTING_STARTED.md)
- **Workflow Guide:** [BOOTKIT_DEFENSE_WORKFLOW.md](BOOTKIT_DEFENSE_WORKFLOW.md)
- **Architecture:** [ARCHITECTURE.md](ARCHITECTURE.md)

### Community
- GitHub Issues: Ask questions, report bugs
- Pull Requests: Submit code changes
- Discussions: Share ideas and get feedback

## 📜 License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.

## �� Recognition

Contributors will be recognized in:
- The project README
- Release notes
- CHANGELOG.md

Thank you for making PhoenixBoot better!

---

**Questions?** Open an issue with the "question" label or reach out through GitHub Discussions.
