# PhoenixBoot Test Container
# Runs QEMU tests and validation

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install QEMU and testing dependencies
RUN apt-get update && apt-get install -y \
    qemu-system-x86 \
    qemu-utils \
    ovmf \
    python3 \
    python3-pip \
    python3-venv \
    python3-pytest \
    sbsigntool \
    efibootmgr \
    dosfstools \
    mtools \
    util-linux \
    curl \
    wget \
    bash \
    coreutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /phoenixboot

# Create test user
RUN groupadd -r phoenixtest && useradd -r -g phoenixtest -m phoenixtest

# Copy test scripts and artifacts
COPY scripts/ /phoenixboot/scripts/
COPY tests/ /phoenixboot/tests/
COPY utils/ /phoenixboot/utils/
COPY staging/ /phoenixboot/staging/
COPY *.pf /phoenixboot/
COPY pf*.py /phoenixboot/

RUN chown -R phoenixtest:phoenixtest /phoenixboot

USER phoenixtest

# Set up Python environment
RUN python3 -m venv /home/phoenixtest/.venv
ENV PATH="/home/phoenixtest/.venv/bin:$PATH"

# Expose QEMU monitor ports (optional)
EXPOSE 4444 5555

# Default command runs all QEMU tests
CMD ["bash", "scripts/run-e2e-tests.sh"]
