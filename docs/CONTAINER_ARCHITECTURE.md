# PhoenixBoot Container Architecture

This document describes the container-based architecture for PhoenixBoot, designed to provide isolated, reproducible, and maintainable execution environments for each major component.

## Overview

PhoenixBoot uses a modular container architecture with five primary containers:

1. **Build Container** - EDK2 compilation and artifact building
2. **Test Container** - QEMU tests and validation
3. **Installer Container** - ESP manipulation and bootable media creation
4. **Runtime Container** - On-host operations (UUEFI, MOK, etc.)
5. **TUI Container** - Interactive text user interface

Each container is isolated and has a specific purpose, following the principle of separation of concerns.

## Container Details

### Build Container

**Purpose**: Compile UEFI applications, build artifacts, and package releases.

**Dockerfile**: `containers/build/dockerfiles/Dockerfile`

**Capabilities**:
- EDK2 toolchain for UEFI compilation
- Python environment for build scripts
- All build dependencies (gcc, make, nasm, etc.)
- Artifact packaging tools

**Usage**:
```bash
# Build the image
docker build -f containers/build/dockerfiles/Dockerfile -t phoenixboot-build .

# Run a build
docker run --rm -v $(pwd):/phoenixboot phoenixboot-build

# Using docker-compose
docker-compose --profile build up
```

**Volumes**:
- `/phoenixboot` - Project root (read-write)
- `/phoenixboot/out` - Build output directory

### Test Container

**Purpose**: Run QEMU-based tests and validation suites.

**Dockerfile**: `containers/test/dockerfiles/Dockerfile`

**Capabilities**:
- QEMU system emulation
- OVMF firmware for UEFI testing
- Python test frameworks
- Test result generation (JUnit XML)

**Usage**:
```bash
# Build the image
docker build -f containers/test/dockerfiles/Dockerfile -t phoenixboot-test .

# Run tests
docker run --rm -v $(pwd):/phoenixboot phoenixboot-test

# Using docker-compose
docker-compose --profile test up
```

**Volumes**:
- `/phoenixboot` - Project root
- `/phoenixboot/out` - Test output directory
- `/phoenixboot/ovmf_stuff` - OVMF firmware files

**Optional**: Enable KVM acceleration by mounting `/dev/kvm` device.

### Installer Container

**Purpose**: Create bootable ESP images, integrate ISOs, and manage bootable media.

**Dockerfile**: `containers/installer/dockerfiles/Dockerfile`

**Capabilities**:
- ESP (EFI System Partition) manipulation
- ISO creation and integration
- Bootable media preparation
- SecureBoot key integration

**Usage**:
```bash
# Build the image
docker build -f containers/installer/dockerfiles/Dockerfile -t phoenixboot-installer .

# Package ESP
docker run --rm -v $(pwd):/phoenixboot phoenixboot-installer

# Create SecureBoot bootable media
docker run --rm -v $(pwd):/phoenixboot \
  -e ISO_PATH=/phoenixboot/ubuntu.iso \
  phoenixboot-installer bash create-secureboot-bootable-media.sh --iso $ISO_PATH

# Using docker-compose
docker-compose --profile installer up
```

**Volumes**:
- `/phoenixboot` - Project root
- `/phoenixboot/out` - Output directory
- `/phoenixboot/keys` - SecureBoot keys

**Note**: USB device access requires privileged mode or explicit device mounting.

### Runtime Container

**Purpose**: Execute on-host operations like UUEFI, MOK enrollment, and module signing.

**Dockerfile**: `containers/runtime/dockerfiles/Dockerfile`

**Capabilities**:
- EFI variable access
- MOK management
- Kernel module signing
- Boot entry manipulation

**Usage**:
```bash
# Build the image
docker build -f containers/runtime/dockerfiles/Dockerfile -t phoenixboot-runtime .

# UUEFI report
docker run --rm -v $(pwd):/phoenixboot \
  -v /sys/firmware/efi:/sys/firmware/efi:ro \
  phoenixboot-runtime bash scripts/uuefi-report.sh

# Using docker-compose
docker-compose --profile runtime up
```

**Volumes**:
- `/phoenixboot` - Project root
- `/sys/firmware/efi` - EFI firmware interface (read-only)
- `/boot/efi` - EFI system partition
- `/lib/modules` - Kernel modules (read-only)

**Note**: Requires privileged mode for EFI variable manipulation.

### TUI Container

**Purpose**: Provide an interactive text user interface for managing PhoenixBoot.

**Dockerfile**: `containers/tui/dockerfiles/Dockerfile`

**Capabilities**:
- Interactive terminal UI with Textual framework
- Task browsing and execution
- Real-time output display
- Integrated help and documentation

**Usage**:
```bash
# Build the image
docker build -f containers/tui/dockerfiles/Dockerfile -t phoenixboot-tui .

# Run TUI
docker run --rm -it -v $(pwd):/phoenixboot phoenixboot-tui

# Using docker-compose
docker-compose --profile tui up
```

**Volumes**:
- `/phoenixboot` - Project root
- `/phoenixboot/out` - Output directory

**Requirements**: Interactive terminal (TTY) required.

## Podman Quadlet Integration

For systemd integration on systems using Podman, quadlet configuration files are provided in each container's `quadlets/` directory.

### Installing Quadlets

```bash
# Copy quadlet files to systemd user directory
mkdir -p ~/.config/containers/systemd/
cp containers/*/quadlets/*.container ~/.config/containers/systemd/

# Or for system-wide installation
sudo cp containers/*/quadlets/*.container /etc/containers/systemd/

# Reload systemd
systemctl --user daemon-reload
# or
sudo systemctl daemon-reload
```

### Using Quadlets

```bash
# Start build container
systemctl --user start phoenixboot-build.service

# Start test container
systemctl --user start phoenixboot-test.service

# Enable auto-start on boot
systemctl --user enable phoenixboot-build.service
```

### Quadlet Benefits

- **Systemd Integration**: Containers managed like regular services
- **Dependency Management**: Service ordering and dependencies
- **Logging**: Centralized logging via journald
- **Resource Control**: CPU/memory limits via systemd
- **Security**: SELinux labels and security contexts

## Docker Compose Usage

The `docker-compose.yml` file orchestrates all containers. Profiles are used to control which containers run:

```bash
# Build only
docker-compose --profile build up

# Test only
docker-compose --profile test up

# All containers
docker-compose --profile all up

# Build and test
docker-compose --profile build --profile test up

# TUI interface
docker-compose --profile tui up
```

### Environment Variables

Configure containers via environment variables:

```bash
# Build configuration
export PG_FORCE_BUILD=1

# ISO path for installer
export ISO_PATH=/path/to/ubuntu.iso

# USB device for installer
export USB_DEVICE=/dev/sdb

# Run with variables
docker-compose --profile installer up
```

## Security Considerations

### Container Isolation

- Each container runs as a non-root user
- Minimal capabilities by default
- SELinux labels applied to volumes (`:Z` flag)
- Network isolation via dedicated bridge network

### Privileged Operations

Some operations require elevated privileges:

- **Runtime Container**: EFI variable access requires privileged mode
- **Installer Container**: USB device access may require privileged mode
- **Test Container**: KVM acceleration requires `/dev/kvm` access

**Best Practice**: Use privileged mode only when necessary and understand the security implications.

### Volume Mounting

- Mount only necessary directories
- Use read-only (`:ro`) mounts when possible
- Apply SELinux labels (`:Z` or `:z`) for shared volumes

## Development Workflow

### 1. Setup and Build

```bash
# Build all container images
docker-compose build

# Or build specific container
docker build -f containers/build/dockerfiles/Dockerfile -t phoenixboot-build .
```

### 2. Development Iteration

```bash
# Run build
docker-compose --profile build up

# Run tests
docker-compose --profile test up

# Check results
ls -la out/
```

### 3. Interactive Development

```bash
# Open TUI for interactive operations
docker-compose --profile tui up

# Or run shell in container
docker run -it --rm -v $(pwd):/phoenixboot phoenixboot-build bash
```

### 4. Production Deployment

```bash
# Build production artifacts
docker-compose --profile build up

# Validate with tests
docker-compose --profile test up

# Create installer media
docker-compose --profile installer up
```

## Troubleshooting

### Build Failures

```bash
# Clean build cache
docker volume rm phoenixboot_build-cache

# Rebuild without cache
docker-compose build --no-cache
```

### Permission Issues

```bash
# Ensure proper ownership
sudo chown -R $(id -u):$(id -g) out/

# Check SELinux contexts (Fedora/RHEL)
ls -Z out/
```

### Container Won't Start

```bash
# Check logs
docker-compose logs phoenixboot-build

# Or for specific container
docker logs phoenixboot-build
```

### Test Failures

```bash
# Increase timeout
export QEMU_TIMEOUT=600
docker-compose --profile test up

# Enable verbose output
docker-compose --profile test up --verbose
```

## CI/CD Integration

Containers are designed for CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Build PhoenixBoot
  run: docker-compose --profile build up

- name: Run Tests
  run: docker-compose --profile test up

- name: Archive Artifacts
  uses: actions/upload-artifact@v2
  with:
    name: phoenixboot-artifacts
    path: out/
```

## Migration from Direct Execution

If you've been running PhoenixBoot directly on your host:

### Before (Direct)
```bash
./pf.py build-build
./pf.py test-qemu
```

### After (Containerized)
```bash
docker-compose --profile build up
docker-compose --profile test up
```

### Or Use TUI
```bash
docker-compose --profile tui up
# Then select tasks from the interactive menu
```

## Future Enhancements

- **Kubernetes Support**: Pod definitions for container orchestration
- **Multi-Architecture**: ARM64 support for Apple Silicon
- **Registry Publishing**: Pre-built images on Docker Hub
- **CI/CD Templates**: Ready-to-use GitHub Actions workflows

## Summary

The container architecture provides:

✅ **Isolation** - Each component in its own environment
✅ **Reproducibility** - Consistent builds across systems
✅ **Maintainability** - Clear separation of concerns
✅ **Scalability** - Easy to add new components
✅ **Portability** - Works on any system with Docker/Podman

For more information, see individual container README files in `containers/*/README.md`.
