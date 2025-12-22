# Contributing to PhoenixBoot

Thank you for your interest in contributing to PhoenixBoot! This document provides guidelines for contributing to the project.

## 🌟 Ways to Contribute

There are many ways to contribute to PhoenixBoot:

- 🐛 **Report bugs** - Help us identify and fix issues
- 💡 **Suggest features** - Share ideas for improvements
- 📝 **Improve documentation** - Help others understand PhoenixBoot
- 🔧 **Submit code** - Fix bugs or implement new features
- 🧪 **Write tests** - Improve test coverage
- 🔍 **Review pull requests** - Help maintain code quality

## 🚀 Getting Started

### Prerequisites

Before contributing, ensure you have:

- Linux system with UEFI firmware
- Python 3.8+ with venv
- Build tools: `gcc`, `make`, `git`
- QEMU for testing (optional)
- `efibootmgr`, `mokutil` for boot management
- EDK2 for building UEFI applications from source

### Setting Up Your Development Environment

1. **Fork the repository** on GitHub

2. **Clone your fork**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/PhoenixBoot.git
   cd PhoenixBoot
   ```

3. **Set up Python environment**:
   ```bash
   python3 -m venv ~/.venv
   source ~/.venv/bin/activate
   pip install -r requirements.txt
   ```

4. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/P4X-ng/PhoenixBoot.git
   ```

5. **Verify your setup**:
   ```bash
   ./pf.py list  # List available tasks
   ```

## 📋 Contribution Workflow

### 1. Create a Branch

Create a descriptive branch name:

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
```

### 2. Make Your Changes

- Follow the existing code style and conventions
- Write clear, concise commit messages
- Add tests for new features
- Update documentation as needed
- Keep changes focused and atomic

### 3. Test Your Changes

Before submitting, ensure your changes work:

```bash
# Run tests
docker-compose --profile test up

# Test in QEMU if applicable
./pf.py test-qemu

# Run security checks
./pf.py secure-env
```

### 4. Commit Your Changes

Write clear commit messages:

```bash
git add .
git commit -m "Add feature: brief description

Detailed explanation of what changed and why."
```

### 5. Push to Your Fork

```bash
git push origin feature/your-feature-name
```

### 6. Open a Pull Request

1. Go to the original PhoenixBoot repository on GitHub
2. Click "New Pull Request"
3. Select your fork and branch
4. Fill out the pull request template
5. Submit the pull request

## 📝 Code Style Guidelines

### Python Code

- Follow PEP 8 style guidelines
- Use meaningful variable and function names
- Add docstrings to functions and classes
- Keep functions focused and single-purpose
- Maximum line length: 100 characters

### Shell Scripts

- Use `#!/bin/bash` shebang
- Add comments for complex logic
- Use descriptive variable names (UPPER_CASE for constants)
- Check return codes for critical operations
- Quote variables to handle spaces

### UEFI/EDK2 Code

- Follow EDK2 coding standards
- Use proper error handling
- Add comments for complex firmware operations
- Ensure memory safety

### Documentation

- Use clear, concise language
- Include code examples where helpful
- Keep README.md updated
- Add comments to complex code
- Update relevant guides in `docs/`

## 🧪 Testing Guidelines

### Writing Tests

- Add tests for new features
- Ensure tests are reproducible
- Test both success and failure cases
- Use QEMU for boot chain testing
- Document test requirements

### Running Tests

```bash
# Run all tests in containers
docker-compose --profile test up

# Run specific QEMU tests
./pf.py test-qemu
./pf.py test-qemu-secure-positive
./pf.py test-qemu-secure-strict

# Run security validation
./pf.py secure-env
./pf.py kernel-hardening-check
```

## 🔒 Security Considerations

PhoenixBoot is a security-focused project. Please keep these in mind:

### Security Best Practices

- **Never commit secrets** - No keys, passwords, or tokens
- **Validate all inputs** - Especially in scripts handling user data
- **Use cryptographic verification** - For boot chain integrity
- **Document security implications** - Of new features
- **Follow least privilege** - Request only necessary permissions
- **Test security features** - Verify they work as intended

### Reporting Security Vulnerabilities

**DO NOT** open public issues for security vulnerabilities.

Instead, please email security concerns to the maintainers or use GitHub's private security advisory feature.

See [SECURITY.md](SECURITY.md) for detailed security reporting guidelines.

## 📚 Documentation

### When to Update Documentation

Update documentation when you:

- Add a new feature
- Change existing functionality
- Fix a bug that affects usage
- Add new scripts or tools
- Change command-line interfaces

### Documentation Locations

- **README.md** - Project overview and quick start
- **GETTING_STARTED.md** - Beginner-friendly guide
- **docs/** - Detailed guides and documentation
- **Code comments** - Inline documentation
- **Script headers** - Purpose and usage of scripts

## 🎯 Pull Request Guidelines

### Before Submitting

- [ ] Code follows project style guidelines
- [ ] Tests pass locally
- [ ] Documentation is updated
- [ ] Commit messages are clear
- [ ] Branch is up to date with main
- [ ] No merge conflicts
- [ ] Security implications considered

### Pull Request Template

When opening a PR, include:

1. **Description** - What does this PR do?
2. **Motivation** - Why is this change needed?
3. **Testing** - How was this tested?
4. **Screenshots** - For UI changes (if applicable)
5. **Related Issues** - Link to related issues

### Review Process

1. Automated checks run (CI/CD, tests, linting)
2. Maintainers review the code
3. Feedback is provided if changes needed
4. Once approved, PR is merged

## 💬 Communication

### Getting Help

- **GitHub Discussions** - Ask questions and share ideas
- **GitHub Issues** - Report bugs and request features
- **Pull Requests** - Code review and discussion
- **Documentation** - Check existing guides first

### Community Guidelines

- Be respectful and inclusive
- Provide constructive feedback
- Help others learn and grow
- Follow the Code of Conduct
- Keep discussions on-topic

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for detailed guidelines.

## 🏆 Recognition

Contributors are recognized in several ways:

- Listed in git commit history
- Mentioned in release notes
- Added to `.mailmap` file
- Acknowledged in documentation

## 📄 License

By contributing to PhoenixBoot, you agree that your contributions will be licensed under the Apache License 2.0. See [LICENSE.md](LICENSE.md) for details.

## 🔗 Additional Resources

- [Project Architecture](ARCHITECTURE.md)
- [Getting Started Guide](GETTING_STARTED.md)
- [Security Considerations](docs/SECURITY_CONSIDERATIONS.md)
- [Container Architecture](docs/CONTAINER_ARCHITECTURE.md)
- [Testing Guide](docs/TESTING_GUIDE.md)

## ❓ Questions?

If you have questions about contributing:

1. Check existing documentation
2. Search closed issues for similar questions
3. Open a GitHub Discussion
4. Ask in your pull request

Thank you for contributing to PhoenixBoot! 🎉
