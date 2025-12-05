# PhoenixBoot Container Architecture Diagram

## High-Level Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     PhoenixBoot System                          │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Direct     │  │  Container   │  │   Systemd    │         │
│  │  Execution   │  │  Execution   │  │  (Quadlet)   │         │
│  │  ./pf.py     │  │  docker/     │  │  systemctl   │         │
│  │              │  │  podman      │  │              │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│         │                  │                  │                │
│         └──────────────────┴──────────────────┘                │
│                           │                                    │
│                           ▼                                    │
│              ┌─────────────────────────┐                       │
│              │    Task Runner (pf.py)  │                       │
│              └─────────────────────────┘                       │
└─────────────────────────────────────────────────────────────────┘
```

## Container Architecture

```
┌───────────────────────────────────────────────────────────────────────┐
│                         Container Network                             │
│                        (phoenixboot-net)                              │
│                                                                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐ │
│  │   Build     │  │    Test     │  │  Installer  │  │  Runtime   │ │
│  │ Container   │  │  Container  │  │  Container  │  │ Container  │ │
│  │             │  │             │  │             │  │            │ │
│  │ EDK2        │  │ QEMU        │  │ ESP Tools   │  │ efibootmgr │ │
│  │ GCC/Make    │  │ OVMF        │  │ ISO Tools   │  │ mokutil    │ │
│  │ Build Tools │  │ Test Tools  │  │ Partition   │  │ EFI Access │ │
│  │             │  │             │  │ Tools       │  │            │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └────────────┘ │
│        │                │                  │               │        │
│        └────────────────┴──────────────────┴───────────────┘        │
│                              │                                       │
│                    ┌─────────▼─────────┐                            │
│                    │   TUI Container   │                            │
│                    │  (Interactive)    │                            │
│                    │                   │                            │
│                    │  Textual/Rich     │                            │
│                    │  Task Execution   │                            │
│                    │  Output Display   │                            │
│                    └───────────────────┘                            │
└───────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │   Host Filesystem     │
                    │   (Mounted Volumes)   │
                    │                       │
                    │   /phoenixboot        │
                    │   /phoenixboot/out    │
                    │   /phoenixboot/keys   │
                    └───────────────────────┘
```

## Data Flow

### Build Workflow

```
┌─────────────┐
│    User     │
└──────┬──────┘
       │
       │ make run-build
       │ OR docker compose --profile build up
       │
       ▼
┌──────────────────────────┐
│   Build Container        │
│                          │
│  1. Load source from     │◄──── /phoenixboot (mounted)
│     staging/src/         │
│                          │
│  2. Compile with EDK2    │
│     gcc, make, nasm      │
│                          │
│  3. Package artifacts    │
│                          │
│  4. Write output         │────► /phoenixboot/out (mounted)
│                          │
└──────────────────────────┘
       │
       ▼
┌──────────────────────────┐
│   out/staging/           │
│   - NuclearBootEdk2.efi  │
│   - UUEFI.efi            │
│   - KeyEnrollEdk2.efi    │
└──────────────────────────┘
```

### Test Workflow

```
┌─────────────┐
│    User     │
└──────┬──────┘
       │
       │ make run-test
       │
       ▼
┌──────────────────────────┐
│   Test Container         │
│                          │
│  1. Load artifacts       │◄──── /phoenixboot/out
│     from out/            │
│                          │
│  2. Start QEMU with      │◄──── /phoenixboot/ovmf_stuff
│     OVMF firmware        │
│                          │
│  3. Boot and validate    │
│                          │
│  4. Generate reports     │────► /phoenixboot/out/qemu
│     (JUnit XML)          │
│                          │
└──────────────────────────┘
       │
       ▼
┌──────────────────────────┐
│   out/qemu/              │
│   - serial*.log          │
│   - report*.xml          │
└──────────────────────────┘
```

### Installer Workflow

```
┌─────────────┐
│    User     │
└──────┬──────┘
       │
       │ ISO_PATH=/path/to.iso make run-installer
       │
       ▼
┌──────────────────────────┐
│  Installer Container     │
│                          │
│  1. Load artifacts       │◄──── /phoenixboot/out
│     and keys             │      /phoenixboot/keys
│                          │
│  2. Create ESP image     │
│     (FAT32 partition)    │
│                          │
│  3. Integrate ISO        │◄──── ISO_PATH (env var)
│     (optional)           │
│                          │
│  4. Package bootable     │────► /phoenixboot/out/esp
│     media                │
│                          │
└──────────────────────────┘
       │
       ▼
┌──────────────────────────┐
│   out/esp/               │
│   - secureboot-*.img     │
│   - esp.img              │
└──────────────────────────┘
```

### TUI Interaction Flow

```
┌─────────────┐
│    User     │
│  (Terminal) │
└──────┬──────┘
       │
       │ make run-tui
       │
       ▼
┌──────────────────────────────────────────┐
│   TUI Container                          │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │   Textual Application              │  │
│  │                                    │  │
│  │  ┌──────────────┐  ┌────────────┐ │  │
│  │  │  Sidebar     │  │  Content   │ │  │
│  │  │  Categories  │  │  Tasks     │ │  │
│  │  │              │  │            │ │  │
│  │  │  Build       │  │  Execute   │ │  │
│  │  │  Test        │  │  Display   │ │  │
│  │  │  SecureBoot  │  │  Output    │ │  │
│  │  │  MOK         │  │            │ │  │
│  │  │  UUEFI       │  │            │ │  │
│  │  │  ...         │  │            │ │  │
│  │  └──────────────┘  └────────────┘ │  │
│  │                                    │  │
│  └────────────────────────────────────┘  │
│                  │                        │
│                  ▼                        │
│        ┌──────────────────┐               │
│        │  Task Executor   │               │
│        │  (pf.py wrapper) │               │
│        └──────────────────┘               │
│                  │                        │
└──────────────────┼────────────────────────┘
                   │
                   ▼
          ┌─────────────────┐
          │   pf.py          │
          │   (Task Runner)  │
          └─────────────────┘
```

## Component Interactions

```
┌─────────────────────────────────────────────────────────────────┐
│                     User Interaction Layer                      │
├───────────────┬───────────────────┬─────────────────────────────┤
│  TUI          │  CLI (Makefile)   │  Direct (./pf.py)          │
│  Interactive  │  Convenient       │  Traditional               │
│  GUI-like     │  Shortcuts        │  Scriptable                │
└───────┬───────┴─────────┬─────────┴─────────┬─────────────────┘
        │                 │                   │
        └─────────────────┴───────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Container Orchestration                      │
├───────────────┬───────────────────┬─────────────────────────────┤
│ docker-compose│  Podman Compose   │  Systemd (Quadlet)         │
│ Development   │  Alternative      │  Production                │
└───────┬───────┴─────────┬─────────┴─────────┬─────────────────┘
        │                 │                   │
        └─────────────────┴───────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Container Runtime                            │
├───────────────┬──────────────┬──────────────┬──────────────────┤
│  Docker       │  Podman      │  containerd  │  CRI-O           │
│  (common)     │  (rootless)  │  (k8s)       │  (k8s)           │
└───────┬───────┴──────┬───────┴──────┬───────┴────────┬─────────┘
        │              │              │                │
        └──────────────┴──────────────┴────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Container Image                            │
├────────────┬──────────────┬──────────────┬─────────────────────┤
│  Build     │  Test        │  Installer   │  Runtime  │  TUI    │
│  Container │  Container   │  Container   │  Container│Container│
└────────────┴──────────────┴──────────────┴───────────┴─────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    PhoenixBoot Core                             │
├────────────┬──────────────┬──────────────┬─────────────────────┤
│  pf.py     │  Scripts     │  Staging     │  Utils              │
│  Task      │  Bash        │  Source/     │  Python             │
│  Runner    │  Operations  │  Binaries    │  Tools              │
└────────────┴──────────────┴──────────────┴─────────────────────┘
```

## Deployment Options

### Option 1: Development (Docker Compose)

```
Developer
    │
    ▼
make run-tui
    │
    ▼
Docker Compose
    │
    ├─► Build Container
    ├─► Test Container
    ├─► Installer Container
    ├─► Runtime Container
    └─► TUI Container
```

### Option 2: Production (Systemd + Quadlet)

```
System Administrator
    │
    ▼
systemctl start phoenixboot-*.service
    │
    ▼
Systemd
    │
    ▼
Podman Quadlet
    │
    ├─► Build Service
    ├─► Test Service
    ├─► Installer Service
    ├─► Runtime Service
    └─► TUI Service
```

### Option 3: CI/CD (GitHub Actions)

```
Git Push
    │
    ▼
GitHub Actions
    │
    ├─► make build
    │   └─► Build all containers
    │
    ├─► make run-build
    │   └─► Compile artifacts
    │
    ├─► make run-test
    │   └─► Run validation
    │
    └─► Upload artifacts
        └─► Store results
```

## Benefits of This Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Benefits                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ✅ Isolation        Each component in clean environment       │
│  ✅ Reproducibility  Same results everywhere                   │
│  ✅ Portability      Works on any system with containers       │
│  ✅ Scalability      Easy to add new components                │
│  ✅ Maintainability  Clear separation of concerns              │
│  ✅ Testability      Independent testing of components         │
│  ✅ Security         Minimal privileges, SELinux support       │
│  ✅ Documentation    Self-documenting Dockerfiles              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

**Made with 🔥 for a more secure boot process**
