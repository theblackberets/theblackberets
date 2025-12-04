# Dockerfile for Alpine Linux environment simulation
# Uses justfile-based installation (just install)
# Updated for feature-based structure

FROM alpine:latest

# Set strict error handling
RUN set -euo pipefail || true

# Install basic dependencies needed for installation
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
    python3 \
    && rm -rf /var/cache/apk/*

# Copy all files to /root for justfile-based installation
WORKDIR /root

# Copy main justfile and lib directory
COPY justfile ./
COPY lib/ ./lib/

# Copy feature directories
COPY nix/ ./nix/
COPY just/ ./just/
COPY kali/ ./kali/
COPY localai/ ./localai/
COPY mcp/ ./mcp/
COPY models-management/ ./models-management/
COPY services/ ./services/
COPY test/ ./test/

# Copy config directory
COPY config/ ./config/

# Copy configuration.nix (for config module defaults)
# If file doesn't exist, config module will use defaults from configuration.nix structure
# Note: This will fail if configuration.nix doesn't exist - that's OK, it should be in the repo
COPY configuration.nix ./configuration.nix

# Make justfile executable and ensure lib scripts are executable
RUN chmod +x justfile && \
    find lib/ -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true && \
    find . -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# Install just first (needed to run justfile recipes)
RUN apk add --no-cache just || true

# Run installation via justfile (as root)
# This installs: Nix, just, Kali tools, LocalAI, MCP server
# Errors are handled gracefully by the install recipe itself (warnings logged, continues on optional failures)
# Suppress stderr to hide verbose error messages, but keep stdout for important info
RUN just install

# Create common directories for testing (using defaults from configuration.nix)
# Defaults: modelDir="./models", configDir="./localai-config", defaultPort=8080
RUN mkdir -p /root/models /root/localai-config /root/test-logs || true

# Set up bash profile to source Nix environment (for Docker-friendly testing)
RUN cat >> /root/.bashrc << 'EOF'
# Source Nix environment if available (Docker-friendly)
for profile in \
    /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
    /root/.nix-profile/etc/profile.d/nix.sh \
    /etc/profile.d/nix.sh; do
    if [ -f "$profile" ]; then
        . "$profile" 2>/dev/null || true
        break
    fi
done

# Set up common environment variables (defaults from configuration.nix)
# These match ai.localAI.modelDir="./models", ai.localAI.configDir="./localai-config", ai.localAI.defaultPort=8080
# In Docker context (/root), ./models becomes /root/models
export MODEL_DIR="${MODEL_DIR:-./models}"
export CONFIG_DIR="${CONFIG_DIR:-./localai-config}"
export PORT="${PORT:-8080}"

# Change to project directory if mounted
if [ -d /root/project ]; then
    cd /root/project 2>/dev/null || true
fi
EOF

# Set working directory
WORKDIR /root

# Default to bash shell with --login to source .bashrc
CMD ["/bin/bash", "--login"]
