# PhoenixBoot Runtime Container
# Minimal runtime for executing on-host operations

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    efibootmgr \
    mokutil \
    sbsigntool \
    openssl \
    python3 \
    python3-pip \
    python3-venv \
    util-linux \
    kmod \
    bash \
    coreutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /phoenixboot

# Create runtime user
RUN groupadd -r phoenixrun && useradd -r -g phoenixrun -m phoenixrun

# Copy runtime scripts and utilities
COPY scripts/ /phoenixboot/scripts/
COPY utils/ /phoenixboot/utils/
COPY *.pf /phoenixboot/
COPY pf*.py /phoenixboot/

RUN chown -R phoenixrun:phoenixrun /phoenixboot

USER phoenixrun

# Set up Python environment
RUN python3 -m venv /home/phoenixrun/.venv
ENV PATH="/home/phoenixrun/.venv/bin:$PATH"

# Default command shows UUEFI report
CMD ["bash", "scripts/uuefi-report.sh"]
