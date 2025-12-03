# PhoenixBoot Quick Reference Card

## Container Commands

### Using Makefile (Recommended)

```bash
make help           # Show all commands
make build          # Build all containers
make run-tui        # Launch TUI (interactive)
make run-build      # Run build container
make run-test       # Run test container
make shell-build    # Open shell in build container
make clean          # Clean up containers
```

### Using Docker Compose

```bash
docker compose build                    # Build all containers
docker compose --profile tui up         # Launch TUI
docker compose --profile build up       # Run build
docker compose --profile test up        # Run tests
docker compose --profile all up         # Run all containers
docker compose ps                       # Show running containers
docker compose logs -f                  # Follow logs
```

### Using Docker Directly

```bash
docker build -f containers/build/dockerfiles/Dockerfile -t phoenixboot-build .
docker run --rm -v $(pwd):/phoenixboot phoenixboot-build
docker run -it --rm -v $(pwd):/phoenixboot phoenixboot-tui
```

## TUI Interface

### Launch TUI

```bash
./phoenixboot-tui.sh          # Direct launch
make run-tui                  # Via container
docker compose --profile tui up
```

### Navigation

- `Arrow Keys` - Navigate menu items
- `Enter` - Execute selected task
- `Tab` - Switch between panels
- `Esc` - Go back
- `q` - Quit
- `d` - Toggle dark/light mode

### Task Categories

- 🔨 **Build & Setup** - Bootstrap, build, package
- 🧪 **Testing** - QEMU tests, validation
- 🔐 **SecureBoot** - Key generation, enrollment
- 🔑 **MOK & Signing** - Module signing, certificates
- 🔧 **UUEFI** - Diagnostics, firmware analysis
- 💿 **Installer** - Bootable media, ESP images
- 🛡️ **Security** - Security checks, audits
- ⚙️ **Maintenance** - Cleanup, verification

## Direct Task Execution

### Build Tasks

```bash
./pf.py build-setup         # Bootstrap toolchain
./pf.py build-build         # Build artifacts
./pf.py build-package-esp   # Package ESP
```

### Test Tasks

```bash
./pf.py test-qemu                        # Main boot test
./pf.py test-qemu-secure-positive        # SecureBoot test
./pf.py test-qemu-uuefi                  # UUEFI test
./pf.py test-qemu-secure-negative-attest # Corruption test
```

### SecureBoot Tasks

```bash
./pf.py secure-keygen       # Generate keys (PK, KEK, db)
./pf.py secure-make-auth    # Create auth files
./pf.py secureboot-create   # Create bootable media
```

### MOK Tasks

```bash
./pf.py secure-mok-new      # Generate MOK cert
./pf.py os-mok-enroll       # Enroll MOK
./pf.py os-mok-list-keys    # List MOK keys
./pf.py os-kmod-sign        # Sign kernel module
```

### Security Tasks

```bash
./pf.py secure-env                 # Full security check
./pf.py kernel-hardening-check     # Kernel analysis
./pf.py firmware-checksum-list     # Firmware checksums
```

### UUEFI Tasks

```bash
./pf.py uuefi-install       # Install UUEFI.efi
./pf.py uuefi-apply         # Set BootNext
./pf.py uuefi-report        # System status
```

## Common Workflows

### 1. Initial Setup

```bash
make build              # Build containers
make run-build          # Build artifacts
make run-test           # Verify with tests
```

### 2. Create SecureBoot USB

```bash
# Generate keys
./pf.py secure-keygen

# Create bootable media
ISO_PATH=/path/to.iso ./pf.py secureboot-create

# Write to USB (outside container)
sudo dd if=out/esp/secureboot-bootable.img of=/dev/sdX bs=4M status=progress
```

### 3. Sign Kernel Module

```bash
# Generate MOK certificate
./pf.py secure-mok-new

# Enroll MOK
./pf.py os-mok-enroll

# Sign module
PATH=/lib/modules/.../module.ko ./pf.py os-kmod-sign
```

### 4. Security Audit

```bash
# Run comprehensive check
./pf.py secure-env

# Or via TUI
make run-tui
# Select 🛡️ Security > secure-env
```

### 5. Build and Test

```bash
# Option 1: Via Makefile
make run-build && make run-test

# Option 2: Via docker-compose
docker compose --profile build --profile test up

# Option 3: Direct
./pf.py build-build && ./pf.py test-qemu
```

## Environment Variables

### Build Configuration

```bash
export PG_FORCE_BUILD=1         # Force source rebuild
export PYTHONUNBUFFERED=1       # Unbuffered output
```

### Installer Configuration

```bash
export ISO_PATH=/path/to.iso    # ISO for bootable media
export USB_DEVICE=/dev/sdX      # USB device target
```

### Test Configuration

```bash
export QEMU_TIMEOUT=600         # Test timeout (seconds)
```

## File Locations

### Input Directories

```
PhoenixBoot/
├── scripts/         # Operational scripts
├── staging/         # Source code and binaries
│   ├── src/        # UEFI source (C)
│   └── boot/       # Pre-built EFI binaries
├── utils/           # Python utilities
├── keys/            # SecureBoot keys
└── containers/      # Container definitions
```

### Output Directories

```
PhoenixBoot/
└── out/
    ├── staging/     # Compiled binaries
    ├── esp/         # ESP images
    ├── artifacts/   # Release packages
    ├── qemu/        # Test logs/reports
    └── keys/        # Generated keys
```

## Troubleshooting

### Container Won't Build

```bash
make clean-images   # Remove old images
make build          # Rebuild
```

### Permission Errors

```bash
sudo chown -R $(id -u):$(id -g) out/
```

### TUI Dependencies Missing

```bash
pip install textual rich pyyaml
# Or use containerized version
make run-tui
```

### Test Failures

```bash
# Check logs
ls -la out/qemu/
cat out/qemu/serial*.log

# Or debug in container
make shell-test
cd /phoenixboot
./pf.py test-qemu
```

### Docker Daemon Issues

```bash
# Start Docker
sudo systemctl start docker

# Or for Podman
sudo systemctl start podman
```

## Documentation

- **README.md** - Project overview
- **docs/CONTAINER_ARCHITECTURE.md** - Container details
- **docs/CONTAINER_SETUP.md** - Setup guide
- **docs/TUI_GUIDE.md** - TUI usage
- **containers/README.md** - Container directory info

## Getting Help

```bash
make help           # Makefile commands
./pf.py list        # Available tasks
./pf.py <task> -h   # Task help (if available)
```

**GitHub Issues**: https://github.com/P4X-ng/PhoenixBoot/issues

## Key Shortcuts

| Action | Command |
|--------|---------|
| List tasks | `./pf.py list` |
| Build everything | `make run-build` |
| Run tests | `make run-test` |
| Launch TUI | `make run-tui` |
| Security check | `./pf.py secure-env` |
| Generate keys | `./pf.py secure-keygen` |
| Create USB | `./pf.py secureboot-create` |
| Sign module | `./pf.py os-kmod-sign` |
| Clean up | `make clean` |
| Help | `make help` |

---

**Made with 🔥 for a more secure boot process**
