# PhoenixBoot Container Setup Guide

This guide walks you through setting up PhoenixBoot with the new container-based architecture.

## Quick Start

### Prerequisites

Choose one of the following:

**Option 1: Docker**
```bash
# Install Docker (Ubuntu/Debian)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
# Log out and back in for group changes
```

**Option 2: Podman** (Recommended for systemd integration)
```bash
# Install Podman (Fedora/RHEL)
sudo dnf install podman podman-compose

# Ubuntu/Debian
sudo apt-get install podman podman-compose
```

### Clone and Setup

```bash
# Clone repository
git clone https://github.com/P4X-ng/PhoenixBoot.git
cd PhoenixBoot

# Build all containers
make build

# Or with docker-compose directly
docker compose build
```

### Launch the TUI

The easiest way to get started is with the interactive TUI:

```bash
# Using Makefile
make run-tui

# Or using docker-compose
docker compose --profile tui up

# Or run directly (requires Python + textual)
./phoenixboot-tui.sh
```

## Usage Patterns

### Pattern 1: Interactive Development (TUI)

Best for: Exploring features, one-off tasks, learning

```bash
# Launch TUI
make run-tui

# Navigate using:
# - Arrow keys to select categories
# - Enter to execute tasks
# - Esc to go back
# - q to quit
```

### Pattern 2: Command-Line Tasks

Best for: Automation, scripts, CI/CD

```bash
# Build artifacts
make run-build

# Run tests
make run-test

# Create bootable media
ISO_PATH=/path/to/ubuntu.iso make run-installer
```

### Pattern 3: Direct Execution

Best for: Quick operations, when containers aren't needed

```bash
# Use pf.py directly
./pf.py build-build
./pf.py test-qemu
./pf.py secure-env
```

### Pattern 4: Interactive Debugging

Best for: Troubleshooting, exploration

```bash
# Open shell in build container
make shell-build

# Inside container:
cd /phoenixboot
./pf.py build-build
ls -la out/
```

## Common Workflows

### Workflow 1: Initial Setup and Build

```bash
# 1. Build containers
make build

# 2. Bootstrap environment
make run-build

# 3. Run tests to verify
make run-test

# 4. Check results
ls -la out/
```

### Workflow 2: Create SecureBoot USB

```bash
# 1. Build containers
make build

# 2. Create bootable media
ISO_PATH=/path/to/ubuntu.iso make run-installer

# 3. Write to USB (outside container)
sudo dd if=out/esp/secureboot-bootable.img of=/dev/sdX bs=4M status=progress
```

### Workflow 3: Security Audit

```bash
# Launch TUI
make run-tui

# Select "🛡️ Security" category
# Run "secure-env" task
# Review comprehensive report
```

### Workflow 4: Module Signing

```bash
# Launch TUI
make run-tui

# Select "🔑 MOK & Signing" category
# Run "secure-mok-new" to create MOK cert
# Run "os-mok-enroll" to enroll
# Run "os-kmod-sign" to sign modules
```

## Container Architecture

### Available Containers

1. **Build** (`phoenixboot-build`)
   - EDK2 compilation
   - Artifact building
   - Package creation

2. **Test** (`phoenixboot-test`)
   - QEMU testing
   - Validation
   - CI/CD integration

3. **Installer** (`phoenixboot-installer`)
   - ESP manipulation
   - Bootable media creation
   - ISO integration

4. **Runtime** (`phoenixboot-runtime`)
   - On-host operations
   - UUEFI operations
   - MOK enrollment

5. **TUI** (`phoenixboot-tui`)
   - Interactive interface
   - Task management
   - Real-time output

### Container Management

```bash
# List running containers
make ps

# View logs
make logs

# Clean up
make clean

# Rebuild from scratch
make rebuild
```

## Systemd Integration (Podman)

For production deployments with systemd:

### Install Quadlets

```bash
# Copy quadlet files
mkdir -p ~/.config/containers/systemd/
cp containers/*/quadlets/*.container ~/.config/containers/systemd/

# Reload systemd
systemctl --user daemon-reload
```

### Manage Services

```bash
# Start build service
systemctl --user start phoenixboot-build.service

# Enable on boot
systemctl --user enable phoenixboot-build.service

# Check status
systemctl --user status phoenixboot-build.service

# View logs
journalctl --user -u phoenixboot-build.service
```

## Environment Configuration

### Set Build Options

```bash
# Force rebuild from source
export PG_FORCE_BUILD=1
make run-build

# Or with docker-compose
PG_FORCE_BUILD=1 docker compose --profile build up
```

### Set Installer Options

```bash
# Create bootable media from ISO
export ISO_PATH=/path/to/ubuntu.iso
export USB_DEVICE=/dev/sdX
make run-installer
```

### Configure QEMU Tests

```bash
# Increase test timeout
export QEMU_TIMEOUT=600
make run-test
```

## Troubleshooting

### Container Build Fails

```bash
# Clean and rebuild
make clean-images
make build

# Or rebuild specific container
docker compose build phoenixboot-build
```

### Permission Issues

```bash
# Fix ownership
sudo chown -R $(id -u):$(id -g) out/

# Check SELinux (Fedora/RHEL)
ls -Z out/
```

### TUI Won't Start

```bash
# Check Python dependencies
pip install textual rich pyyaml

# Or use containerized version
make run-tui
```

### Test Failures

```bash
# Open shell in test container
make shell-test

# Run tests manually
cd /phoenixboot
./pf.py test-qemu

# Check logs
ls -la out/qemu/
cat out/qemu/serial*.log
```

## Advanced Usage

### Custom Container Builds

Edit Dockerfiles in `containers/*/dockerfiles/` to customize:

```bash
# Rebuild after changes
make rebuild
```

### Multi-Container Workflows

Run multiple containers simultaneously:

```bash
# Terminal 1: Build
make run-build

# Terminal 2: Watch tests
make run-test

# Terminal 3: Monitor logs
make logs
```

### CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: PhoenixBoot CI

on: [push, pull_request]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Build containers
        run: make build
      
      - name: Run build
        run: make run-build
      
      - name: Run tests
        run: make run-test
      
      - name: Archive artifacts
        uses: actions/upload-artifact@v2
        with:
          name: phoenixboot-artifacts
          path: out/
```

## Migration from Legacy Setup

If you're upgrading from a non-containerized setup:

### Step 1: Backup

```bash
# Backup your current setup
tar -czf phoenixboot-backup-$(date +%Y%m%d).tar.gz .
```

### Step 2: Update

```bash
# Pull latest changes
git pull origin main

# Or checkout specific branch
git checkout copilot/improve-repo-organization
```

### Step 3: Build Containers

```bash
# Build all containers
make build
```

### Step 4: Verify

```bash
# Test with TUI
make run-tui

# Or run a simple task
make run-build
```

### Step 5: Switch Workflows

**Before**:
```bash
./pf.py build-build
./pf.py test-qemu
```

**After**:
```bash
make run-build
make run-test
```

**Or use TUI**:
```bash
make run-tui
# Select tasks from menu
```

## Best Practices

### 1. Use Containers for Consistency

Containers ensure reproducible builds across different systems.

### 2. Use TUI for Exploration

The TUI is great for learning and one-off tasks.

### 3. Use Makefile for Automation

The Makefile simplifies common operations.

### 4. Use Quadlets for Production

Systemd integration provides robust service management.

### 5. Regular Cleanup

```bash
# Clean up after work
make clean

# Full cleanup
make clean-images
```

## Getting Help

### Documentation

- **Container Architecture**: `docs/CONTAINER_ARCHITECTURE.md`
- **TUI Guide**: `docs/TUI_GUIDE.md`
- **Project README**: `README.md`
- **Quick Start**: `QUICKSTART.md`

### Commands

```bash
# Show Makefile help
make help

# List available tasks
./pf.py list

# TUI has built-in help (press ℹ️ About)
make run-tui
```

### Support

- **GitHub Issues**: https://github.com/P4X-ng/PhoenixBoot/issues
- **Discussions**: https://github.com/P4X-ng/PhoenixBoot/discussions

## Next Steps

1. ✅ **Setup Complete** - You've set up the container infrastructure
2. 🎯 **Explore TUI** - Launch `make run-tui` and explore
3. 🔨 **Build Artifacts** - Run `make run-build`
4. 🧪 **Run Tests** - Verify with `make run-test`
5. 🔐 **Generate Keys** - Create SecureBoot keys via TUI
6. 💿 **Create Media** - Make bootable USB/CD
7. 🛡️ **Security Audit** - Run security checks

## Summary

PhoenixBoot's container architecture provides:

✅ **Isolation** - Clean, reproducible environments
✅ **Simplicity** - Easy to use with Makefile and TUI
✅ **Flexibility** - Use containers or run directly
✅ **Production-Ready** - Systemd integration via quadlets
✅ **Developer-Friendly** - Interactive debugging and exploration

---

**Made with 🔥 for a more secure boot process**
