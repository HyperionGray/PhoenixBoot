# PhoenixBoot Build Container
# EDK2 compilation and artifact building

FROM ubuntu:22.04

LABEL maintainer="PhoenixBoot Team"
LABEL description="Build container for EDK2 UEFI applications"

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    g++ \
    make \
    nasm \
    iasl \
    uuid-dev \
    python3 \
    python3-pip \
    git \
    curl \
    wget \
    ca-certificates \
    dosfstools \
    mtools \
    openssl \
    sbsigntool \
    efitools \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for builds
RUN useradd -m -u 1000 -s /bin/bash phoenixbuild && \
    mkdir -p /phoenixboot && \
    chown -R phoenixbuild:phoenixbuild /phoenixboot

# Set working directory
WORKDIR /phoenixboot

# Switch to non-root user
USER phoenixbuild

# Set environment variables
ENV PATH="/phoenixboot:${PATH}"
ENV PYTHON_COMMAND=python3

# Default command: run build script
CMD ["bash", "scripts/build/build-production.sh"]
