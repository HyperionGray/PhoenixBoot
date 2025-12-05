# PhoenixBoot TUI Guide

The PhoenixBoot Terminal User Interface (TUI) provides an interactive, user-friendly way to manage all PhoenixBoot operations.

## Overview

The TUI is a modern text-based interface built with the Textual framework that provides:

- 🎯 **Organized Task Categories** - Tasks grouped by functionality
- 🚀 **One-Click Execution** - Run tasks with a button press
- 📊 **Real-Time Output** - See task output as it happens
- 🎨 **Modern Design** - Clean, intuitive interface
- ⌨️ **Keyboard Navigation** - Full keyboard support

## Installation

### Prerequisites

```bash
# Python 3.8+ required
python3 --version

# Install dependencies
pip install textual rich pyyaml
```

### Running the TUI

There are three ways to run the TUI:

#### 1. Direct Python Execution

```bash
cd /path/to/PhoenixBoot
python3 containers/tui/app/phoenixboot_tui.py
```

#### 2. Docker Container

```bash
# Using docker-compose
docker-compose --profile tui up

# Or directly
docker run -it --rm -v $(pwd):/phoenixboot phoenixboot-tui
```

#### 3. Podman Quadlet

```bash
# Install quadlet
cp containers/tui/quadlets/phoenixboot-tui.container ~/.config/containers/systemd/
systemctl --user daemon-reload

# Run via systemd
systemctl --user start phoenixboot-tui.service
```

## Interface Overview

### Main Screen

```
┌─────────────────────────────────────────────────────────────┐
│ 🔥 PhoenixBoot - Secure Boot Defense System                │
│ Interactive Management Interface                            │
├──────────────┬──────────────────────────────────────────────┤
│              │                                              │
│ Task         │  Welcome to PhoenixBoot TUI                 │
│ Categories   │                                              │
│              │  PhoenixBoot is a production-ready          │
│ 🔨 Build     │  firmware defense system...                 │
│ 🧪 Testing   │                                              │
│ 🔐 SecureBoot│  Select a category from the sidebar         │
│ 🔑 MOK       │                                              │
│ 🔧 UUEFI     │                                              │
│ 💿 Installer │                                              │
│ 🛡️ Security  │                                              │
│ ⚙️ Maint.    │                                              │
│ ℹ️ About     │                                              │
│              │                                              │
└──────────────┴──────────────────────────────────────────────┘
```

### Navigation

- **Sidebar**: Click or use arrow keys to select a category
- **Main Area**: View tasks or information
- **Task Buttons**: Click or press Enter to execute
- **Tab**: Navigate between UI elements
- **Esc**: Go back to previous screen
- **q**: Quit application
- **d**: Toggle dark/light mode

## Task Categories

### 🔨 Build & Setup

Bootstrap the development environment and build artifacts:

- **build-setup** - Bootstrap toolchain & environment
- **build-build** - Build production artifacts
- **build-package-esp** - Package bootable ESP image

**Use Case**: Initial setup or rebuilding after source changes.

### 🧪 Testing & Validation

Run QEMU tests to validate functionality:

- **test-qemu** - Main QEMU boot test
- **test-qemu-secure-positive** - SecureBoot positive test
- **test-qemu-uuefi** - UUEFI application test
- **test-qemu-secure-strict** - SecureBoot strict mode
- **test-qemu-secure-negative-attest** - Corruption detection test

**Use Case**: Validate changes, run CI/CD tests locally.

### 🔐 SecureBoot & Keys

Manage SecureBoot keys and create bootable media:

- **secure-keygen** - Generate SecureBoot keys (PK, KEK, db)
- **secure-make-auth** - Create authenticated variable files
- **secureboot-create** - Create SecureBoot bootable media

**Use Case**: Setting up new systems with custom SecureBoot keys.

### 🔑 MOK & Module Signing

Manage Machine Owner Keys for kernel module signing:

- **secure-mok-new** - Generate new MOK certificate
- **os-mok-enroll** - Enroll MOK certificate
- **os-mok-list-keys** - List enrolled MOK keys
- **os-kmod-sign** - Sign kernel module

**Use Case**: Signing custom kernel modules for SecureBoot.

### 🔧 UUEFI Operations

Universal UEFI diagnostic tool operations:

- **uuefi-install** - Install UUEFI.efi to ESP
- **uuefi-apply** - Set BootNext for UUEFI
- **uuefi-report** - Display system security status

**Use Case**: System diagnostics, security analysis, firmware inspection.

### 💿 ESP & Bootable Media

Create and manage EFI System Partition images:

- **build-package-esp** - Package ESP image
- **esp** - Complete ESP build & package
- **validate-all** - Validate all artifacts

**Use Case**: Creating bootable USB drives or CD/DVD media.

### 🛡️ Security Analysis

Comprehensive security checks and analysis:

- **secure-env** - Comprehensive security check
- **kernel-hardening-check** - Kernel hardening analysis
- **kernel-hardening-report** - Generate hardening report
- **firmware-checksum-list** - List firmware checksums

**Use Case**: Security audits, compliance checks, threat detection.

### ⚙️ Maintenance

Cleanup and verification tasks:

- **cleanup** - Clean build artifacts
- **verify** - Verify artifacts

**Use Case**: Cleaning up after builds, verifying integrity.

### ℹ️ About

Information about PhoenixBoot, version details, and container architecture.

## Task Execution

### Running a Task

1. Select a category from the sidebar
2. Click on a task button or navigate with arrow keys and press Enter
3. Task execution begins immediately
4. Output is shown in real-time

### Viewing Output

When a task runs, you'll see:

```
┌─────────────────────────────────────────────────────────────┐
│ Task: build-setup                                           │
│ ✓ Success                                                   │
├─────────────┬───────────────────────────────────────────────┤
│ Output      │ Errors                                        │
├─────────────┴───────────────────────────────────────────────┤
│ Checking for toolchain dependencies...                      │
│ ✓ gcc found                                                 │
│ ✓ make found                                                │
│ ✓ python3 found                                             │
│ Toolchain check complete!                                   │
└─────────────────────────────────────────────────────────────┘
```

### Success vs Failure

- **✓ Success** - Green banner, exit code 0
- **✗ Failed** - Red banner, non-zero exit code

### Error Handling

If a task fails:

1. Check the **Errors** tab for stderr output
2. Review the **Output** tab for diagnostic information
3. Press **Esc** or **q** to return to task list
4. Fix the issue and retry

## Keyboard Shortcuts

### Global Shortcuts

- `q` - Quit application
- `d` - Toggle dark/light mode
- `Ctrl+C` - Force quit
- `Tab` - Navigate between elements
- `Shift+Tab` - Navigate backwards

### Navigation Shortcuts

- `Esc` - Go back to previous screen
- `↑` / `↓` - Navigate buttons
- `Enter` - Activate selected button
- `Space` - Alternative to Enter

### Task Output Screen

- `Esc` - Return to task list
- `q` - Return to task list
- `Tab` - Switch between Output/Errors tabs

## Examples

### Example 1: Bootstrap Environment

1. Launch TUI: `python3 containers/tui/app/phoenixboot_tui.py`
2. Click "🔨 Build & Setup"
3. Click "build-setup"
4. Wait for completion
5. Review output

### Example 2: Run Tests

1. From main screen, click "🧪 Testing"
2. Click "test-qemu"
3. Monitor output in real-time
4. Check test results in Output tab

### Example 3: Generate SecureBoot Keys

1. Click "🔐 SecureBoot"
2. Click "secure-keygen"
3. Wait for key generation
4. Keys saved to `keys/` directory

### Example 4: Security Audit

1. Click "🛡️ Security"
2. Click "secure-env"
3. Review comprehensive security report
4. Address any findings

## Advanced Usage

### Environment Variables

Set environment variables before launching TUI:

```bash
# Force rebuild
export PG_FORCE_BUILD=1
python3 containers/tui/app/phoenixboot_tui.py

# Set ISO path for installer
export ISO_PATH=/path/to/ubuntu.iso
python3 containers/tui/app/phoenixboot_tui.py
```

### Integration with pf.py

The TUI uses `pf.py` internally, so all tasks defined in `.pf` files are available.

### Customization

To add new task categories or tasks, edit:
- `containers/tui/app/phoenixboot_tui.py`

Look for methods like `get_build_tasks()` and add your own.

## Troubleshooting

### TUI Won't Start

**Problem**: `ModuleNotFoundError: No module named 'textual'`

**Solution**:
```bash
pip install textual rich pyyaml
```

### Task Execution Fails

**Problem**: Task fails with "pf.py not found"

**Solution**: Ensure you're running from PhoenixBoot root directory:
```bash
cd /path/to/PhoenixBoot
python3 containers/tui/app/phoenixboot_tui.py
```

### Display Issues

**Problem**: Garbled display or rendering issues

**Solution**:
```bash
# Set proper terminal type
export TERM=xterm-256color
python3 containers/tui/app/phoenixboot_tui.py
```

### Container Issues

**Problem**: TUI container won't start

**Solution**:
```bash
# Rebuild container
docker build -f containers/tui/dockerfiles/Dockerfile -t phoenixboot-tui .

# Check logs
docker logs phoenixboot-tui
```

## Best Practices

### 1. Start with Build

Always run "build-setup" before other tasks on a fresh system.

### 2. Test Before Deploy

Run tests after building to validate artifacts.

### 3. Review Output

Always check task output, even on success, to understand what happened.

### 4. Use Security Checks

Regularly run "secure-env" to monitor system security.

### 5. Container Isolation

Use Docker/Podman containers for reproducible environments.

## Integration with Containers

The TUI works seamlessly with the container architecture:

```bash
# Run TUI in container with access to all tools
docker-compose --profile tui up

# TUI can orchestrate other containers
# (future feature: launch build/test containers from TUI)
```

## Development

### Extending the TUI

To add new features:

1. Edit `containers/tui/app/phoenixboot_tui.py`
2. Add new task categories or screens
3. Test locally
4. Rebuild container: `docker build -f containers/tui/dockerfiles/Dockerfile -t phoenixboot-tui .`

### Theme Customization

The TUI uses Textual's CSS-like styling. Edit the `CSS` section in `PhoenixBootTUI` class.

## Resources

- **Textual Documentation**: https://textual.textualize.io/
- **PhoenixBoot README**: `/README.md`
- **Container Architecture**: `/docs/CONTAINER_ARCHITECTURE.md`
- **Task Reference**: Run `./pf.py list` to see all available tasks

## Support

For issues or questions:

- **GitHub Issues**: https://github.com/P4X-ng/PhoenixBoot/issues
- **Documentation**: `docs/` directory
- **Quick Help**: Press `ℹ️ About` in TUI

---

**Made with 🔥 for a more secure boot process**
