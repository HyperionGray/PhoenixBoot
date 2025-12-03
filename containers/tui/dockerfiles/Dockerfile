# PhoenixBoot TUI Container
# Interactive text user interface for managing PhoenixBoot

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install TUI dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    bash \
    coreutils \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /phoenixboot

# Create TUI user
RUN groupadd -r phoenixtui && useradd -r -g phoenixtui -m phoenixtui

# Copy application files
COPY scripts/ /phoenixboot/scripts/
COPY utils/ /phoenixboot/utils/
COPY containers/tui/app/ /phoenixboot/tui/
COPY *.pf /phoenixboot/
COPY pf*.py /phoenixboot/

RUN chown -R phoenixtui:phoenixtui /phoenixboot

USER phoenixtui

# Set up Python environment and install textual
RUN python3 -m venv /home/phoenixtui/.venv
ENV PATH="/home/phoenixtui/.venv/bin:$PATH"
RUN pip install --no-cache-dir textual rich pyyaml

# Default command runs the TUI
CMD ["python3", "tui/phoenixboot_tui.py"]
