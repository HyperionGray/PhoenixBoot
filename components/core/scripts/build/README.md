# PhoenixBoot Build Scripts

This directory contains scripts for building PhoenixBoot artifacts from source.

## Scripts

### build-production.sh

**Purpose**: Build or verify UEFI applications for production use

**Usage**:
```bash
# Check for pre-built artifacts (default behavior)
./scripts/build/build-production.sh

# Force rebuild from source
PG_FORCE_BUILD=1 ./scripts/build/build-production.sh

# Or via pf task
./pf.py build-build
```

**Artifacts Built**:
- `NuclearBootEdk2.efi` - Main UEFI application for boot protection
- `UUEFI.efi` - Universal UEFI diagnostic tool
- `KeyEnrollEdk2.efi` - SecureBoot key enrollment utility

**Behavior**:
1. **Default**: Checks if pre-built artifacts exist in `staging/boot/`
   - If all artifacts exist, uses them without rebuilding
   - This is fast and works for most users
   
2. **Force Build** (`PG_FORCE_BUILD=1`): Rebuilds from source
   - Requires EDK2 toolchain
   - Compiles from `staging/src/`
   - Copies built artifacts to `staging/boot/`

**Requirements for Source Builds**:
- EDK2 toolchain (automatically cloned if missing)
- GCC, Make, NASM
- Python 3
- ~2GB disk space for EDK2

**Output Location**: `staging/boot/`

## Integration with Containers

The build process is containerized for reproducibility:

```bash
# Using Docker Compose
docker-compose --profile build up

# Using the container directly
docker build -f containers/build/dockerfiles/Dockerfile -t phoenixboot-build .
docker run --rm -v $(pwd):/phoenixboot phoenixboot-build
```

## Troubleshooting

### Build Fails with EDK2 Errors
- Ensure you have enough disk space (2GB+)
- Check that git submodules are initialized
- Try cleaning the EDK2 workspace: `rm -rf ~/edk2`

### Permission Errors
- Ensure build scripts are executable: `chmod +x scripts/build/*.sh`
- Check ownership of staging/ directory

### Missing Dependencies
- Install build-essential: `apt install build-essential nasm iasl uuid-dev`

## See Also

- [Container Architecture](../../docs/CONTAINER_ARCHITECTURE.md)
- [Build container](../../containers/build/)
- [Staging directory](../../staging/)
