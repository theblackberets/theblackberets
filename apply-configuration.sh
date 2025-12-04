#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Apply Configuration Script
# Applies configuration.nix to the system (NixOS-style declarative config)
# Optimized version with shared config parser
# ============================================================================

# Source shared config parser library and bootstrap
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/bootstrap.sh" ]; then
    . "$SCRIPT_DIR/lib/bootstrap.sh"
elif [ -f "/usr/local/share/theblackberets/lib/bootstrap.sh" ]; then
    . "/usr/local/share/theblackberets/lib/bootstrap.sh"
fi

# Also try lib-config-parser.sh for backward compatibility
if [ -f "$SCRIPT_DIR/lib-config-parser.sh" ]; then
    . "$SCRIPT_DIR/lib-config-parser.sh" 2>/dev/null || true
elif [ -f "/usr/local/share/theblackberets/lib-config-parser.sh" ]; then
    . "/usr/local/share/theblackberets/lib-config-parser.sh" 2>/dev/null || true
fi

# Setup cleanup trap
TEMP_FILES=()
cleanup_temp() {
    for file in "${TEMP_FILES[@]}"; do
        rm -f "$file" 2>/dev/null || true
    done
}
trap cleanup_temp EXIT

# Logging functions
log() {
    echo "$*"
}

log_error() {
    echo "ERROR: $*" >&2
}

log_warning() {
    echo "WARNING: $*" >&2
}

# Check for root privileges
if [ "$(id -u)" != "0" ]; then
    if command -v doas >/dev/null 2>&1; then
        log_error "This script must be run as root or using 'doas ./apply-configuration.sh'"
    elif command -v sudo >/dev/null 2>&1; then
        log_error "This script must be run as root or using 'sudo ./apply-configuration.sh'"
    else
        log_error "This script must be run as root. Install doas or sudo, or run as root user."
    fi
    exit 1
fi

# Enable Nix commands
if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
elif [ -f /etc/profile.d/nix.sh ]; then
    . /etc/profile.d/nix.sh
fi

if ! command -v nix >/dev/null 2>&1; then
    log_error "Nix is not installed. Please run: doas ./install.sh"
    exit 1
fi

# Optimize Nix configuration for faster downloads (if just is available)
# This configures binary caches, parallel downloads, and connection limits
if command -v just >/dev/null 2>&1; then
    # Find justfile location
    JUSTFILE_DIR=""
    for path in "." "/usr/local/share/theblackberets" "/root/project"; do
        if [ -f "$path/justfile" ]; then
            JUSTFILE_DIR="$path"
            break
        fi
    done
    
    if [ -n "$JUSTFILE_DIR" ]; then
        log "Optimizing Nix configuration for faster downloads..."
        (cd "$JUSTFILE_DIR" && just optimize-nix >/dev/null 2>&1) || true
    fi
else
    # Fallback: Enable flakes if needed (minimal config)
    if ! nix show-config 2>/dev/null | grep -q "experimental-features.*flakes"; then
        log "Enabling Nix flakes..."
        mkdir -p /etc/nix
        echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf 2>/dev/null || true
    fi
fi

# Find configuration.nix and flake.nix
CONFIG_DIR=""
FLAKE_DIR=""

# Check current directory first
if [ -f "configuration.nix" ] && [ -f "flake.nix" ]; then
    CONFIG_DIR="."
    FLAKE_DIR="."
elif [ -f "/usr/local/share/theblackberets/configuration.nix" ] && [ -f "/usr/local/share/theblackberets/flake.nix" ]; then
    CONFIG_DIR="/usr/local/share/theblackberets"
    FLAKE_DIR="/usr/local/share/theblackberets"
elif [ -f "/root/theblackberets/configuration.nix" ] && [ -f "/root/theblackberets/flake.nix" ]; then
    CONFIG_DIR="/root/theblackberets"
    FLAKE_DIR="/root/theblackberets"
else
    log_error "Could not find configuration.nix and flake.nix"
    log_error "Please run this script from the repository directory"
    exit 1
fi

log "=========================================="
log "Applying Declarative Configuration"
log "=========================================="
log ""
log "Configuration directory: $CONFIG_DIR"
log "Flake directory: $FLAKE_DIR"
log ""

# Parse configuration.nix using shared parser
CONFIG_FILE="$CONFIG_DIR/configuration.nix"

if ! parse_config_file "$CONFIG_FILE"; then
    log_error "Failed to parse configuration file: $CONFIG_FILE"
    exit 1
fi

log "Reading configuration from $CONFIG_FILE..."

# Use config module with proper nested paths (from lib/config.sh)
# Fallback to get_config_value if get_config not available (backward compatibility)
if command -v get_config >/dev/null 2>&1; then
    # Use proper nested config paths
    BASE_DIR=$(get_config "paths.baseDir" "/usr/local/share/theblackberets")
    DEFAULT_JUSTFILE=$(get_config "paths.defaultJustfile" "$BASE_DIR/justfile")
    MODEL_DIR=$(get_config "ai.localAI.modelDir" "./models")
    CONFIG_DIR_VALUE=$(get_config "ai.localAI.configDir" "./localai-config")
    IMAGES_DIR=$(get_config "ai.localAI.imagesDir" "$CONFIG_DIR_VALUE/images")
    
    # Extract AI/LocalAI settings using nested paths
    LOCALAI_PORT=$(get_config "ai.localAI.defaultPort" "8080")
    LOCALAI_BIND=$(get_config "ai.localAI.bindAddress" "0.0.0.0")
    LOCALAI_THREADS=$(get_config "ai.localAI.config.threads" "4")
    LOCALAI_CONTEXT=$(get_config "ai.localAI.config.contextSize" "4096")
    LOCALAI_MODEL_NAME=$(get_config "ai.localAI.config.modelName" "llama-3-8b")
    LOCALAI_MODEL_FILE=$(get_config "ai.localAI.config.modelFile" "llama-3-8b-instruct-q4_k_m.gguf")
    LOCALAI_TEMP=$(get_config "ai.localAI.config.temperature" "0.7")
    LOCALAI_TOP_P=$(get_config "ai.localAI.config.topP" "0.9")
    LOCALAI_TOP_K=$(get_config "ai.localAI.config.topK" "40")
    
    # Extract environment variables
    ENV_LOCAL_AI=$(get_config "environment.LOCAL_AI" "http://localhost:$LOCALAI_PORT")
    ENV_LOCALAI_PORT=$(get_config "environment.LOCALAI_PORT" "$LOCALAI_PORT")
    ENV_LOCALAI_MODEL_DIR=$(get_config "environment.LOCALAI_MODEL_DIR" "$MODEL_DIR")
    ENV_LOCALAI_CONFIG_DIR=$(get_config "environment.LOCALAI_CONFIG_DIR" "$CONFIG_DIR_VALUE")
else
    # Fallback to old method if config module not available
    log_warning "Config module not available, using fallback parsing"
    BASE_DIR=$(get_config_value "baseDir" "/usr/local/share/theblackberets" 2>/dev/null || echo "/usr/local/share/theblackberets")
    DEFAULT_JUSTFILE=$(get_config_value "defaultJustfile" "$BASE_DIR/justfile" 2>/dev/null || echo "$BASE_DIR/justfile")
    MODEL_DIR=$(get_config_value "modelDir" "./models" 2>/dev/null || echo "./models")
    CONFIG_DIR_VALUE=$(get_config_value "configDir" "./localai-config" 2>/dev/null || echo "./localai-config")
    IMAGES_DIR=$(get_config_value "imagesDir" "$CONFIG_DIR_VALUE/images" 2>/dev/null || echo "$CONFIG_DIR_VALUE/images")
    
    # Fallback: try grep/sed parsing
    [ "$BASE_DIR" = "/usr/local/share/theblackberets" ] && \
        BASE_DIR=$(grep -A 5 "paths = {" "$CONFIG_FILE" 2>/dev/null | grep "baseDir" | sed 's/.*baseDir.*"\(.*\)".*/\1/' | head -n1 || echo "$BASE_DIR")
    [ "$MODEL_DIR" = "./models" ] && \
        MODEL_DIR=$(grep -A 10 "localAI = {" "$CONFIG_FILE" 2>/dev/null | grep "modelDir" | sed 's/.*modelDir.*"\(.*\)".*/\1/' | head -n1 || echo "$MODEL_DIR")
    [ "$CONFIG_DIR_VALUE" = "./localai-config" ] && \
        CONFIG_DIR_VALUE=$(grep -A 10 "localAI = {" "$CONFIG_FILE" 2>/dev/null | grep "configDir" | sed 's/.*configDir.*"\(.*\)".*/\1/' | head -n1 || echo "$CONFIG_DIR_VALUE")
    
    LOCALAI_PORT=$(grep -A 15 "localAI = {" "$CONFIG_FILE" 2>/dev/null | grep "defaultPort" | sed 's/.*defaultPort.*=\s*\([0-9]*\).*/\1/' | head -n1 || echo "8080")
    LOCALAI_BIND=$(grep -A 15 "localAI = {" "$CONFIG_FILE" 2>/dev/null | grep "bindAddress" | sed 's/.*bindAddress.*"\(.*\)".*/\1/' | head -n1 || echo "0.0.0.0")
    LOCALAI_THREADS=$(grep -A 20 "config = {" "$CONFIG_FILE" 2>/dev/null | grep "threads" | sed 's/.*threads.*=\s*\([0-9]*\).*/\1/' | head -n1 || echo "4")
    LOCALAI_CONTEXT=$(grep -A 20 "config = {" "$CONFIG_FILE" 2>/dev/null | grep "contextSize" | sed 's/.*contextSize.*=\s*\([0-9]*\).*/\1/' | head -n1 || echo "4096")
    LOCALAI_MODEL_NAME=$(grep -A 20 "config = {" "$CONFIG_FILE" 2>/dev/null | grep "modelName" | sed 's/.*modelName.*"\(.*\)".*/\1/' | head -n1 || echo "llama-3-8b")
    LOCALAI_MODEL_FILE=$(grep -A 20 "config = {" "$CONFIG_FILE" 2>/dev/null | grep "modelFile" | sed 's/.*modelFile.*"\(.*\)".*/\1/' | head -n1 || echo "llama-3-8b-instruct-q4_k_m.gguf")
    LOCALAI_TEMP=$(grep -A 20 "config = {" "$CONFIG_FILE" 2>/dev/null | grep "temperature" | sed 's/.*temperature.*=\s*\([0-9.]*\).*/\1/' | head -n1 || echo "0.7")
    LOCALAI_TOP_P=$(grep -A 20 "config = {" "$CONFIG_FILE" 2>/dev/null | grep "topP" | sed 's/.*topP.*=\s*\([0-9.]*\).*/\1/' | head -n1 || echo "0.9")
    LOCALAI_TOP_K=$(grep -A 20 "config = {" "$CONFIG_FILE" 2>/dev/null | grep "topK" | sed 's/.*topK.*=\s*\([0-9]*\).*/\1/' | head -n1 || echo "40")
    
    ENV_LOCAL_AI=$(grep -A 10 "environment = {" "$CONFIG_FILE" 2>/dev/null | grep "LOCAL_AI" | sed 's/.*LOCAL_AI.*"\(.*\)".*/\1/' | head -n1 || echo "http://localhost:$LOCALAI_PORT")
    ENV_LOCALAI_PORT=$(grep -A 10 "environment = {" "$CONFIG_FILE" 2>/dev/null | grep "LOCALAI_PORT" | sed 's/.*LOCALAI_PORT.*"\(.*\)".*/\1/' | head -n1 || echo "$LOCALAI_PORT")
    ENV_LOCALAI_MODEL_DIR=$(grep -A 10 "environment = {" "$CONFIG_FILE" 2>/dev/null | grep "LOCALAI_MODEL_DIR" | sed 's/.*LOCALAI_MODEL_DIR.*"\(.*\)".*/\1/' | head -n1 || echo "$MODEL_DIR")
    ENV_LOCALAI_CONFIG_DIR=$(grep -A 10 "environment = {" "$CONFIG_FILE" 2>/dev/null | grep "LOCALAI_CONFIG_DIR" | sed 's/.*LOCALAI_CONFIG_DIR.*"\(.*\)".*/\1/' | head -n1 || echo "$CONFIG_DIR_VALUE")
fi

# Read package configuration (optimized)
PACKAGES_TO_INSTALL=()

# Check packages (optimized - single grep per package)
if grep -qE "^\s*just\s*=\s*true" "$CONFIG_FILE" 2>/dev/null; then
    PACKAGES_TO_INSTALL+=("just")
fi

if grep -qE "^\s*kali-tools\s*=\s*true" "$CONFIG_FILE" 2>/dev/null; then
    PACKAGES_TO_INSTALL+=("kali-tools")
elif grep -qE "^\s*kali-tools-full\s*=\s*true" "$CONFIG_FILE" 2>/dev/null; then
    PACKAGES_TO_INSTALL+=("kali-tools-full")
fi

log "Packages to install/update: ${PACKAGES_TO_INSTALL[*]}"
log ""

# Update flake inputs first
log "Step 1: Updating flake inputs..."
if (cd "$FLAKE_DIR" && nix flake update >/dev/null 2>&1); then
    log "✓ Flake inputs updated successfully"
else
    log_warning "Flake update had issues, continuing with current state..."
fi

# Install/update each package
for package in "${PACKAGES_TO_INSTALL[@]}"; do
    log ""
    log "Step 2: Installing/updating $package..."
    
    # Check if package is already installed
    if nix profile list 2>/dev/null | grep -q "$package"; then
        log "  -> Package $package is installed, updating..."
        if nix profile install "$FLAKE_DIR#$package" --reinstall >/dev/null 2>&1; then
            log "  ✓ $package updated successfully"
        else
            log_warning "  Failed to update $package, may already be up to date"
        fi
    else
        log "  -> Installing $package..."
        if nix profile install "$FLAKE_DIR#$package" >/dev/null 2>&1; then
            log "  ✓ $package installed successfully"
        else
            log_error "  Failed to install $package"
            exit 1
        fi
    fi
done

# Check if AI/LocalAI should be installed
log ""
log "Step 3: Checking AI/LocalAI configuration..."

if grep -qE "enabled\s*=\s*true" "$CONFIG_FILE" 2>/dev/null && grep -q "localAI = {" "$CONFIG_FILE" 2>/dev/null; then
    log "  -> LocalAI is enabled in configuration"
    
    # Check if just command is available (needed for AI setup)
    if ! command -v just >/dev/null 2>&1; then
        log_warning "  just command not found, skipping AI setup"
    else
        # Find justfile location (optimized - check most likely first)
        JUSTFILE=""
        for path in "$CONFIG_DIR/justfile" "$DEFAULT_JUSTFILE" "/usr/local/share/theblackberets/justfile" "justfile"; do
            if [ -f "$path" ]; then
                JUSTFILE="$path"
                break
            fi
        done
        
        if [ -z "$JUSTFILE" ] || [ ! -f "$JUSTFILE" ]; then
            log_warning "  justfile not found, skipping AI setup"
        else
            # Change to justfile directory for running just commands
            JUSTFILE_DIR="$(dirname "$JUSTFILE")"
            cd "$JUSTFILE_DIR" || {
                log_error "  Failed to change to justfile directory: $JUSTFILE_DIR"
                exit 1
            }
            
            # Install LocalAI if enabled (direct installation - no justfile commands)
            if grep -A 5 "localAI = {" "$CONFIG_FILE" 2>/dev/null | grep -q "enabled = true"; then
                log "  -> Installing LocalAI..."
                
                # Check if already installed
                if command -v localai >/dev/null 2>&1; then
                    log "  ✓ LocalAI already installed"
                else
                    # Download LocalAI binary directly
                    LOCALAI_VERSION="v2.17.0"
                    LOCALAI_BINARY="/usr/local/bin/localai"
                    LOCALAI_URL="https://github.com/mudler/LocalAI/releases/download/${LOCALAI_VERSION}/localai-linux-amd64"
                    
                    log "  -> Downloading LocalAI binary..."
                    if command -v wget >/dev/null 2>&1; then
                        if wget -qO "$LOCALAI_BINARY" "$LOCALAI_URL" 2>/dev/null; then
                            chmod +x "$LOCALAI_BINARY"
                            log "  ✓ LocalAI installed successfully"
                        else
                            log_warning "  Failed to download LocalAI binary"
                        fi
                    elif command -v curl >/dev/null 2>&1; then
                        if curl -fsSL "$LOCALAI_URL" -o "$LOCALAI_BINARY" 2>/dev/null; then
                            chmod +x "$LOCALAI_BINARY"
                            log "  ✓ LocalAI installed successfully"
                        else
                            log_warning "  Failed to download LocalAI binary"
                        fi
                    else
                        log_warning "  wget/curl not found, cannot download LocalAI"
                    fi
                fi
            fi
            
            # Setup LocalAI config if enabled
            if grep -A 5 "localAI = {" "$CONFIG_FILE" 2>/dev/null | grep -q "setupConfig = true"; then
                log "  -> Setting up LocalAI configuration from configuration.nix..."
                
                # Create config directory structure
                mkdir -p "$CONFIG_DIR_VALUE/models" "$IMAGES_DIR"
                
                # Generate config.yaml from configuration.nix values
                CONFIG_YAML="$CONFIG_DIR_VALUE/config.yaml"
                cat > "$CONFIG_YAML" << EOF
# LocalAI Configuration (generated from configuration.nix)
models_path: "$CONFIG_DIR_VALUE/models"
threads: $LOCALAI_THREADS
context_size: $LOCALAI_CONTEXT
f16: true
debug: true
models:
  - name: $LOCALAI_MODEL_NAME
    backend: llama-cpp
    parameters:
      model: $LOCALAI_MODEL_FILE
      temperature: $LOCALAI_TEMP
      top_p: $LOCALAI_TOP_P
      top_k: $LOCALAI_TOP_K
      stop:
        - "<|eot_id|>"
        - "<|end_of_text|>"
EOF
                
                if [ -f "$CONFIG_YAML" ]; then
                    log "  ✓ LocalAI configuration created from configuration.nix"
                    log "    Config file: $CONFIG_YAML"
                    log "    Port: $LOCALAI_PORT"
                    log "    Model: $LOCALAI_MODEL_FILE"
                else
                    log_warning "  Failed to create LocalAI config file"
                fi
            fi
        fi
    fi
else
    log "  -> LocalAI is disabled in configuration, skipping AI setup"
fi

# Apply environment variables from configuration.nix
log ""
log "Step 4: Applying environment configuration..."

# Create environment configuration script
ENV_CONFIG="/etc/profile.d/theblackberets-env.sh"
cat > "$ENV_CONFIG" << EOF
# The Black Berets - Environment Variables (from configuration.nix)
# Generated automatically - edit configuration.nix to change values

export LOCAL_AI="$ENV_LOCAL_AI"
export LOCALAI_PORT="$ENV_LOCALAI_PORT"
export LOCALAI_MODEL_DIR="$ENV_LOCALAI_MODEL_DIR"
export LOCALAI_CONFIG_DIR="$ENV_LOCALAI_CONFIG_DIR"
EOF

chmod +x "$ENV_CONFIG"
log "  ✓ Environment variables configured from configuration.nix"
log "    LOCAL_AI=$ENV_LOCAL_AI"
log "    LOCALAI_PORT=$ENV_LOCALAI_PORT"
log "    LOCALAI_MODEL_DIR=$ENV_LOCALAI_MODEL_DIR"
log "    LOCALAI_CONFIG_DIR=$ENV_LOCALAI_CONFIG_DIR"

log ""
log "=========================================="
log "Configuration Applied Successfully!"
log "=========================================="
log ""
log "All settings from configuration.nix have been applied:"
log "  ✓ Packages installed/updated"
log "  ✓ AI/LocalAI configured"
log "  ✓ Environment variables set"
log ""
log "Configuration Summary:"
log "  - Base directory: $BASE_DIR"
log "  - Model directory: $MODEL_DIR"
log "  - Config directory: $CONFIG_DIR_VALUE"
log "  - LocalAI port: $LOCALAI_PORT"
log ""
log "AI/LocalAI Setup:"
if [ -n "$JUSTFILE" ] && [ -f "$JUSTFILE" ]; then
    JUSTFILE_DIR="$(dirname "$JUSTFILE")"
    log "  - LocalAI: $(command -v localai >/dev/null 2>&1 && echo 'Installed' || echo 'Not installed')"
    log "  - llama.cpp: $([ -d "$JUSTFILE_DIR/llama.cpp" ] 2>/dev/null && echo 'Installed' || echo 'Not installed')"
    log "  - Config file: $([ -f "$CONFIG_DIR_VALUE/config.yaml" ] && echo 'Created' || echo 'Not found')"
else
    log "  - AI setup skipped (justfile not found)"
fi
# Download model if enabled in configuration (uses Nix-provided script if available)
log ""
log "Step 5: Model download (if enabled)..."
DOWNLOAD_ENABLED=$(grep -A 5 "downloadModel = {" "$CONFIG_FILE" 2>/dev/null | grep -q "enabled = true" && echo "true" || echo "false")

if [ "$DOWNLOAD_ENABLED" = "true" ]; then
    MODEL_FILE_NAME=$(grep -A 5 "downloadModel = {" "$CONFIG_FILE" 2>/dev/null | grep "modelName" | sed 's/.*modelName.*"\(.*\)".*/\1/' | head -n1 || echo "llama-3-8b-instruct-q4_k_m.gguf")
    DOWNLOAD_BG=$(grep -A 5 "downloadModel = {" "$CONFIG_FILE" 2>/dev/null | grep -q "downloadInBackground = true" && echo "true" || echo "false")
    
    MODEL_FILE_PATH="$MODEL_DIR/$MODEL_FILE_NAME"
    
    if [ ! -f "$MODEL_FILE_PATH" ]; then
        # Try to use Nix-provided download script first (from flake.nix)
        if command -v download-llama3-8b >/dev/null 2>&1; then
            log "  -> Using Nix-provided download script..."
            if [ "$DOWNLOAD_BG" = "true" ]; then
                log "  -> Downloading model in background (large file, ~5GB)..."
                log "     This will continue after installation completes"
                (
                    download-llama3-8b "$MODEL_DIR" 2>&1 | tee /tmp/model-download.log || true
                ) &
                DOWNLOAD_PID=$!
                echo "$DOWNLOAD_PID" > /tmp/model-download.pid
                log "  ✓ Model download started in background (PID: $DOWNLOAD_PID)"
                log "  ✓ Check progress: tail -f /tmp/model-download.log"
            else
                log "  -> Downloading model (this may take a while, ~5GB)..."
                if download-llama3-8b "$MODEL_DIR"; then
                    log "  ✓ Model downloaded successfully"
                else
                    log_warning "  Model download failed"
                fi
            fi
        else
            # Fallback to manual download (original method)
            log "  -> Using manual download (Nix script not available)..."
            MODEL_URL=$(grep -A 5 "downloadModel = {" "$CONFIG_FILE" 2>/dev/null | grep "modelUrl" | sed 's/.*modelUrl.*"\(.*\)".*/\1/' | head -n1 || echo "")
            
            if [ -n "$MODEL_URL" ]; then
                if [ "$DOWNLOAD_BG" = "true" ]; then
                    log "  -> Downloading model in background (large file, ~5GB)..."
                    log "     This will continue after installation completes"
                    (
                        cd "$MODEL_DIR" || exit 1
                        if command -v wget >/dev/null 2>&1; then
                            wget -q --show-progress "$MODEL_URL" -O "$MODEL_FILE_NAME" 2>&1 | tee /tmp/model-download.log || true
                        elif command -v curl >/dev/null 2>&1; then
                            curl -L --progress-bar "$MODEL_URL" -o "$MODEL_FILE_NAME" 2>&1 | tee /tmp/model-download.log || true
                        else
                            echo "ERROR: wget/curl not found" >> /tmp/model-download.log
                            exit 1
                        fi
                        if [ -f "$MODEL_FILE_NAME" ]; then
                            echo "Model downloaded: $MODEL_FILE_NAME" >> /tmp/model-download.log
                        fi
                    ) &
                    DOWNLOAD_PID=$!
                    echo "$DOWNLOAD_PID" > /tmp/model-download.pid
                    log "  ✓ Model download started in background (PID: $DOWNLOAD_PID)"
                    log "  ✓ Check progress: tail -f /tmp/model-download.log"
                else
                    log "  -> Downloading model (this may take a while, ~5GB)..."
                    cd "$MODEL_DIR" || exit 1
                    if command -v wget >/dev/null 2>&1; then
                        wget -q --show-progress "$MODEL_URL" -O "$MODEL_FILE_NAME" && log "  ✓ Model downloaded" || log_warning "  Model download failed"
                    elif command -v curl >/dev/null 2>&1; then
                        curl -L --progress-bar "$MODEL_URL" -o "$MODEL_FILE_NAME" && log "  ✓ Model downloaded" || log_warning "  Model download failed"
                    else
                        log_warning "  wget/curl not found, skipping model download"
                    fi
                fi
            else
                log_warning "  Model URL not configured, skipping download"
            fi
        fi
    else
        log "  ✓ Model already exists: $MODEL_FILE_NAME"
    fi
else
    log "  - Model download disabled in configuration"
    log "  - To download manually: justdo download-llama3-8b"
fi

# Install and start MCP server if enabled
log ""
log "Step 6: MCP server installation (if enabled)..."
MCP_ENABLED=$(grep -A 3 "mcp = {" "$CONFIG_FILE" 2>/dev/null | grep -q "enabled = true" && echo "true" || echo "false")
MCP_AUTO_START=$(grep -A 3 "mcp = {" "$CONFIG_FILE" 2>/dev/null | grep -q "autoStart = true" && echo "true" || echo "false")

if [ "$MCP_ENABLED" = "true" ]; then
    MCP_SCRIPT_PATH=$(grep -A 5 "mcp = {" "$CONFIG_FILE" 2>/dev/null | grep "scriptPath" | sed 's/.*scriptPath.*"\(.*\)".*/\1/' | head -n1 || echo "$CONFIG_DIR/mcp-kali-server.py")
    MCP_BINARY_PATH=$(grep -A 5 "mcp = {" "$CONFIG_FILE" 2>/dev/null | grep "binaryPath" | sed 's/.*binaryPath.*"\(.*\)".*/\1/' | head -n1 || echo "/usr/local/bin/mcp-kali-server")
    
    # Check if MCP server script exists
    if [ -f "$MCP_SCRIPT_PATH" ]; then
        log "  -> Installing MCP server..."
        chmod +x "$MCP_SCRIPT_PATH" 2>/dev/null || true
        mkdir -p "$(dirname "$MCP_BINARY_PATH")"
        ln -sf "$MCP_SCRIPT_PATH" "$MCP_BINARY_PATH" 2>/dev/null || true
        log "  ✓ MCP server installed: $MCP_BINARY_PATH"
        
        # Start MCP server if autoStart is enabled
        if [ "$MCP_AUTO_START" = "true" ]; then
            if command -v python3 >/dev/null 2>&1; then
                # Check if already running
                if pgrep -f "mcp-kali-server.py" >/dev/null 2>&1; then
                    log "  ✓ MCP server already running"
                else
                    log "  -> Starting MCP server in background..."
                    nohup python3 "$MCP_SCRIPT_PATH" >/dev/null 2>&1 &
                    MCP_PID=$!
                    sleep 1
                    if kill -0 $MCP_PID 2>/dev/null; then
                        log "  ✓ MCP server started in background (PID: $MCP_PID)"
                    else
                        log_warning "  MCP server may have failed to start"
                    fi
                fi
            else
                log_warning "  Python 3 not found, cannot start MCP server"
            fi
        fi
    else
        log_warning "  MCP server script not found: $MCP_SCRIPT_PATH"
    fi
else
    log "  - MCP server disabled in configuration"
fi

log ""
log "=========================================="
log "Configuration Applied Successfully!"
log "=========================================="
log ""
log "All settings from configuration.nix have been applied:"
log "  ✓ Packages installed/updated"
log "  ✓ AI/LocalAI configured"
log "  ✓ Environment variables set"
log "  ✓ Model download (if enabled)"
log "  ✓ MCP server installed and started (if enabled)"
log ""
log "Next steps:"
if [ -f "$MODEL_FILE_PATH" ] 2>/dev/null; then
    log "  ✓ Model ready - Run LocalAI: justdo start"
else
    if [ "$DOWNLOAD_ENABLED" = "true" ] && [ -f /tmp/model-download.pid ]; then
        log "  1. Wait for model download (check: tail -f /tmp/model-download.log)"
        log "  2. Run LocalAI: justdo start"
    else
        log "  1. Download model: justdo download-llama3-8b"
        log "  2. Run LocalAI: justdo start"
    fi
fi
log ""
log "Note: All configuration is in configuration.nix"
log "      Use 'justdo start' to start LocalAI"
log "      Use 'justdo start-mcp' / 'justdo stop-mcp' for MCP server"

