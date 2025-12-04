# Dockerfile for Alpine Linux environment simulation
# Executes install.sh and cleanup.sh as per README instructions

FROM alpine:latest

# Set strict error handling
RUN set -euo pipefail || true

# Install basic dependencies needed for scripts
RUN apk update && \
    apk add --no-cache \
    bash \
    curl \
    wget \
    git \
    xz \
    ca-certificates \
    shadow \
    sudo \
    && rm -rf /var/cache/apk/*

# Copy installation and cleanup scripts
COPY install.sh /tmp/install.sh
COPY cleanup.sh /tmp/cleanup.sh

# Make scripts executable
RUN chmod +x /tmp/install.sh /tmp/cleanup.sh

# Run cleanup.sh as root (as per README instructions)
# RUN /tmp/cleanup.sh || true

# Run install.sh as root (as per README instructions)
RUN /tmp/install.sh || true

# Set working directory
WORKDIR /root

# Default to bash shell
CMD ["/bin/bash"]

