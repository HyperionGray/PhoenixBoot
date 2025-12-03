# PhoenixBoot Container Directory

This directory contains the container-based architecture for PhoenixBoot, providing isolated, reproducible, and maintainable execution environments.

## Directory Structure

```
containers/
├── build/                      # Build container
│   ├── dockerfiles/
│   │   └── Dockerfile         # EDK2 compilation and artifact building
│   └── quadlets/
│       └── phoenixboot-build.container  # Systemd quadlet definition
│
├── test/                       # Test container
│   ├── dockerfiles/
│   │   └── Dockerfile         # QEMU tests and validation
│   └── quadlets/
│       └── phoenixboot-test.container
│
├── installer/                  # Installer container
│   ├── dockerfiles/
│   │   └── Dockerfile         # ESP manipulation and bootable media
│   └── quadlets/
│       └── phoenixboot-installer.container
│
├── runtime/                    # Runtime container
│   ├── dockerfiles/
│   │   └── Dockerfile         # On-host operations
│   └── quadlets/
│       └── phoenixboot-runtime.container
│
└── tui/                        # TUI container
    ├── app/
    │   └── phoenixboot_tui.py # Terminal user interface application
    ├── dockerfiles/
    │   └── Dockerfile         # TUI container
    └── quadlets/
        └── phoenixboot-tui.container
```

## Quick Start

### Using Docker Compose

```bash
# Build all containers
docker-compose build

# Run specific profile
docker-compose --profile build up     # Build artifacts
docker-compose --profile test up      # Run tests
docker-compose --profile tui up       # Launch TUI

# Run all containers
docker-compose --profile all up
```

### Using Individual Containers

```bash
# Build container
docker build -f containers/build/dockerfiles/Dockerfile -t phoenixboot-build .
docker run --rm -v $(pwd):/phoenixboot phoenixboot-build

# Test container
docker build -f containers/test/dockerfiles/Dockerfile -t phoenixboot-test .
docker run --rm -v $(pwd):/phoenixboot phoenixboot-test

# TUI container
docker build -f containers/tui/dockerfiles/Dockerfile -t phoenixboot-tui .
docker run -it --rm -v $(pwd):/phoenixboot phoenixboot-tui
```

### Using Podman Quadlets

```bash
# Install quadlets
mkdir -p ~/.config/containers/systemd/
cp containers/*/quadlets/*.container ~/.config/containers/systemd/
systemctl --user daemon-reload

# Start services
systemctl --user start phoenixboot-build.service
systemctl --user start phoenixboot-test.service
```

## Container Descriptions

### Build Container

**Purpose**: Compile UEFI applications and build artifacts

**Key Tools**:
- EDK2 toolchain
- GCC, Make, NASM
- Python build scripts
- Signing tools (sbsigntool, openssl)

**Use Cases**:
- Compile NuclearBoot, UUEFI, KeyEnroll
- Package ESP images
- Create release artifacts

### Test Container

**Purpose**: Run QEMU-based tests and validation

**Key Tools**:
- QEMU system emulation
- OVMF firmware
- Python test frameworks
- JUnit report generation

**Use Cases**:
- Boot tests
- SecureBoot validation
- Negative attestation testing
- UUEFI functionality tests

### Installer Container

**Purpose**: Create bootable media and manage ESP

**Key Tools**:
- dosfstools, mtools
- ISO manipulation (xorriso, genisoimage)
- Partition tools (parted, gdisk)
- SecureBoot integration

**Use Cases**:
- Create bootable USB drives
- Integrate with existing ISOs
- Package ESP images
- Prepare installation media

### Runtime Container

**Purpose**: Execute on-host operations

**Key Tools**:
- efibootmgr, mokutil
- Kernel module signing
- EFI variable access
- Boot entry manipulation

**Use Cases**:
- UUEFI operations
- MOK enrollment
- Module signing
- Security checks

### TUI Container

**Purpose**: Interactive terminal user interface

**Key Tools**:
- Textual framework
- Rich library
- Python task orchestration

**Use Cases**:
- Interactive task execution
- Browse and run tasks
- Real-time output viewing
- System management

## Documentation

- **[Container Architecture](../docs/CONTAINER_ARCHITECTURE.md)** - Detailed architecture documentation
- **[TUI Guide](../docs/TUI_GUIDE.md)** - Terminal user interface guide
- **[README.md](../README.md)** - Project overview

## Key Features

✅ **Isolation** - Each component in its own environment
✅ **Reproducibility** - Consistent builds across systems
✅ **Security** - Non-root users, SELinux labels, minimal privileges
✅ **Maintainability** - Clear separation of concerns
✅ **Portability** - Works with Docker or Podman
✅ **Systemd Integration** - Quadlet support for service management

## Development

### Building Containers

```bash
# Build all
docker-compose build

# Build specific container
docker build -f containers/build/dockerfiles/Dockerfile -t phoenixboot-build .
```

### Testing Changes

```bash
# Test build
docker-compose --profile build up

# Test tests
docker-compose --profile test up
```

### Adding New Containers

1. Create directory: `containers/newcontainer/`
2. Add Dockerfile: `containers/newcontainer/dockerfiles/Dockerfile`
3. Add quadlet: `containers/newcontainer/quadlets/phoenixboot-newcontainer.container`
4. Update docker-compose.yml
5. Document in CONTAINER_ARCHITECTURE.md

## Environment Variables

Configure containers via environment:

- `PG_FORCE_BUILD=1` - Force rebuild from source
- `ISO_PATH=/path/to.iso` - ISO path for installer
- `USB_DEVICE=/dev/sdX` - USB device for installer
- `QEMU_TIMEOUT=300` - QEMU test timeout

## Troubleshooting

### Permission Issues

```bash
# Fix ownership
sudo chown -R $(id -u):$(id -g) out/

# Check SELinux labels
ls -Z out/
```

### Container Won't Start

```bash
# Check logs
docker logs phoenixboot-build

# Or with compose
docker-compose logs
```

### Build Failures

```bash
# Clean cache
docker volume rm phoenixboot_build-cache

# Rebuild without cache
docker-compose build --no-cache
```

## CI/CD Integration

Containers are designed for CI/CD:

```yaml
# GitHub Actions example
- name: Build
  run: docker-compose --profile build up
  
- name: Test
  run: docker-compose --profile test up
```

## Migration Guide

### From Direct Execution

**Before**:
```bash
./pf.py build-build
./pf.py test-qemu
```

**After**:
```bash
docker-compose --profile build up
docker-compose --profile test up
```

### From Legacy Setup

If you have an existing PhoenixBoot setup:

1. Backup your work: `tar -czf phoenixboot-backup.tar.gz .`
2. Pull latest changes: `git pull`
3. Build containers: `docker-compose build`
4. Run new workflow: `docker-compose --profile build up`

## Support

For issues or questions:

- **GitHub Issues**: https://github.com/P4X-ng/PhoenixBoot/issues
- **Documentation**: `../docs/`
- **Container Architecture**: `../docs/CONTAINER_ARCHITECTURE.md`

---

**Made with 🔥 for a more secure boot process**
