# PhoenixBoot Installer Container
# Handles ESP manipulation, ISO integration, and bootable media creation

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install installer dependencies
RUN apt-get update && apt-get install -y \
    dosfstools \
    mtools \
    syslinux \
    syslinux-utils \
    isolinux \
    xorriso \
    genisoimage \
    squashfs-tools \
    efibootmgr \
    sbsigntool \
    openssl \
    python3 \
    python3-pip \
    python3-venv \
    util-linux \
    parted \
    gdisk \
    e2fsprogs \
    curl \
    wget \
    bash \
    coreutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /phoenixboot

# Create installer user
RUN groupadd -r phoenixinstall && useradd -r -g phoenixinstall -m phoenixinstall

# Copy necessary files
COPY scripts/ /phoenixboot/scripts/
COPY staging/ /phoenixboot/staging/
COPY utils/ /phoenixboot/utils/
COPY create-secureboot-bootable-media.sh /phoenixboot/
COPY *.pf /phoenixboot/
COPY pf*.py /phoenixboot/

RUN chown -R phoenixinstall:phoenixinstall /phoenixboot

USER phoenixinstall

# Set up Python environment
RUN python3 -m venv /home/phoenixinstall/.venv
ENV PATH="/home/phoenixinstall/.venv/bin:$PATH"

# Default command packages ESP
CMD ["bash", "scripts/esp-packaging/esp-package.sh"]
