# The Black Berets - Main Orchestrator
# Imports all feature justfiles and provides main recipes

# Import feature justfiles
import "nix/justfile"
import "just/justfile"
import "kali/justfile"
import "localai/justfile"
import "mcp/justfile"
import "models-management/justfile"
import "services/justfile"
import "test/justfile"

# Default recipe - show available commands
default:
    @just --list

# ============================================================================
# MAIN ORCHESTRATION RECIPES (for all features)
# ============================================================================

# Interactive chat interface (MOST IMPORTANT - starts all services first)
# Usage: justdo chat
chat:
    #!/usr/bin/env bash
    set -euo pipefail
    . lib/bootstrap.sh
    
    log_info "=========================================="
    log_info "The Black Berets - Chat Interface"
    log_info "=========================================="
    log_info ""
    
    # Start all services before chat
    log_info "Starting all required services..."
    just start || log_warn "Some services failed to start, continuing..."
    
    # Wait a moment for services to be ready
    sleep 2
    
    # Find chat.py script
    CHAT_SCRIPT=""
    for path in "./localai/chat.py" "/usr/local/share/theblackberets/chat.py" "/usr/local/bin/chat.py"; do
        if [ -f "$path" ]; then
            CHAT_SCRIPT="$path"
            break
        fi
    done
    
    if [ -z "$CHAT_SCRIPT" ]; then
        die "chat.py not found. Run: just install"
    fi
    
    # Check Python
    require_command python3 "Install Python 3: apk add python3"
    
    # Run chat script
    log_info "Starting chat interface..."
    exec python3 "$CHAT_SCRIPT"

# Install everything (Nix, just, Kali tools, LocalAI, MCP server)
# Usage: doas just install
install:
    #!/usr/bin/env bash
    set -euo pipefail
    . lib/bootstrap.sh
    
    # Check root
    if [ "$(id -u)" != "0" ]; then
        die "Must run as root: doas just install"
    fi
    
    log_info "=========================================="
    log_info "The Black Berets - Installation"
    log_info "=========================================="
    log_info ""
    
    # Install Nix (this starts the daemon)
    just install-nix
    
    # Verify Nix daemon is running and responding before proceeding
    # Source Nix environment first
    if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh 2>/dev/null || true
    elif [ -f /etc/profile.d/nix.sh ]; then
        . /etc/profile.d/nix.sh 2>/dev/null || true
    fi
    
    # Test actual daemon connection (not just socket existence)
    if ! nix eval --expr '1 + 1' >/dev/null 2>&1 && ! nix store info /nix/store >/dev/null 2>&1; then
        log_warn "Nix daemon not responding, attempting to start..."
        if command -v rc-service >/dev/null 2>&1; then
            rc-service nix-daemon restart >/dev/null 2>&1 || rc-service nix-daemon start >/dev/null 2>&1 || true
            sleep 3
        elif [ -f /etc/init.d/nix-daemon ]; then
            /etc/init.d/nix-daemon restart >/dev/null 2>&1 || /etc/init.d/nix-daemon start >/dev/null 2>&1 || true
            sleep 3
        fi
    fi
    
    # Install just
    just install-just
    
    # Setup environment
    just setup-environment
    
    # Install Kali tools (optional, skip if KALI_TOOLS_SKIP=1 or no network)
    if [ "${KALI_TOOLS_SKIP:-0}" != "1" ]; then
        log_info ""
        log_info "Installing Kali tools (minimal, optional)..."
        KALI_TOOLS_MODE="${KALI_TOOLS_MODE:-minimal}" FORCE_INSTALL=1 just install-kali-tools || log_warn "Kali tools installation skipped or had issues, continuing..."
    else
        log_info ""
        log_info "Skipping Kali tools installation (KALI_TOOLS_SKIP=1)"
    fi
    
    # Install LocalAI (force install, ignore config disable flags)
    log_info ""
    log_info "Installing LocalAI..."
    FORCE_INSTALL=1 just install-localai || log_warn "LocalAI installation had issues, continuing..."
    
    # Install MCP server (force install, ignore config disable flags)
    log_info ""
    log_info "Installing MCP server..."
    FORCE_INSTALL=1 just install-mcp || log_warn "MCP server installation had issues, continuing..."
    
    # Apply configuration (force create config.yaml)
    log_info ""
    log_info "Applying configuration..."
    FORCE_INSTALL=1 just configure || log_warn "Configuration application had issues, continuing..."
    
    log_info ""
    log_success "Installation completed!"
    log_info "Run 'justdo test' to verify installation"

# Start all services
# Usage: justdo start
start:
    #!/usr/bin/env bash
    set -euo pipefail
    . lib/bootstrap.sh
    
    log_info "=========================================="
    log_info "The Black Berets - Starting All Services"
    log_info "=========================================="
    log_info ""
    
    # Start LocalAI
    log_info "Starting LocalAI..."
    just start-localai || log_warn "LocalAI start failed, continuing..."
    
    # Start MCP server
    log_info "Starting MCP server..."
    just start-mcp || log_warn "MCP server start failed, continuing..."
    
    log_info ""
    log_success "All services started"
    log_info "Run 'justdo status' to check status"

# Stop all services
# Usage: justdo stop
stop:
    #!/usr/bin/env bash
    set -euo pipefail
    . lib/bootstrap.sh
    
    log_info "=========================================="
    log_info "The Black Berets - Stopping All Services"
    log_info "=========================================="
    log_info ""
    
    # Stop LocalAI
    log_info "Stopping LocalAI..."
    just stop-localai || log_warn "LocalAI stop failed, continuing..."
    
    # Stop MCP server
    log_info "Stopping MCP server..."
    just stop-mcp || log_warn "MCP server stop failed, continuing..."
    
    log_info ""
    log_success "All services stopped"

# Check status of all services
# Usage: justdo status
status:
    just status-all

# Test all features
# Usage: justdo test
test:
    #!/usr/bin/env bash
    set -euo pipefail
    . lib/bootstrap.sh
    
    log_info "=========================================="
    log_info "The Black Berets - Testing All Features"
    log_info "=========================================="
    log_info ""
    
    # Test each feature module using feature-specific test commands
    TESTS_FAILED=0
    
    log_info "Testing Nix..."
    if just test-nix 2>&1; then
        log_success "Nix tests passed"
    else
        log_warn "Nix tests had issues"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    log_info ""
    log_info "Testing just/justdo..."
    if just test-just 2>&1; then
        log_success "just/justdo tests passed"
    else
        log_warn "just/justdo tests had issues"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    log_info ""
    log_info "Testing LocalAI..."
    if just test-localai 2>&1; then
        log_success "LocalAI tests passed"
    else
        log_warn "LocalAI tests had issues"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    log_info ""
    log_info "Testing MCP server..."
    if just test-mcp 2>&1; then
        log_success "MCP server tests passed"
    else
        log_warn "MCP server tests had issues"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    log_info ""
    log_info "Testing Kali tools..."
    if just test-kali 2>&1; then
        log_success "Kali tools tests passed"
    else
        log_warn "Kali tools tests had issues (optional)"
    fi
    
    log_info ""
    log_info "Running comprehensive test..."
    if just test-all 2>&1; then
        log_success "Comprehensive tests passed"
    else
        log_warn "Comprehensive tests had issues"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    log_info ""
    if [ "$TESTS_FAILED" -eq 0 ]; then
        log_success "All tests passed!"
        exit 0
    else
        log_error "Some tests failed ($TESTS_FAILED)"
        exit 1
    fi

# ============================================================================
# CONFIGURATION RECIPES
# ============================================================================

# Apply configuration from configuration.nix
configure:
    #!/usr/bin/env bash
    set -euo pipefail
    . lib/bootstrap.sh
    
    log_info "Applying configuration..."
    
    require_command nix "just install-nix"
    
    # Source Nix
    if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    elif [ -f /etc/profile.d/nix.sh ]; then
        . /etc/profile.d/nix.sh
    elif [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi
    
    # Find configuration.nix (check multiple locations)
    CONFIG_FILE=""
    for path in "./config/configuration.nix" "./configuration.nix" "/usr/local/share/theblackberets/configuration.nix" "/root/project/configuration.nix"; do
        [ -f "$path" ] && CONFIG_FILE="$path" && break
    done
    
    # Validate config if found
    if [ -n "$CONFIG_FILE" ] && command -v validate_nix_config >/dev/null 2>&1; then
        validate_nix_config "$CONFIG_FILE" || log_warn "Invalid configuration.nix, using defaults"
    fi
    
    # Get config values using config module (defaults from configuration.nix)
    # All defaults match configuration.nix defaults
    CONFIG_DIR=$(get_config "ai.localAI.configDir" "./localai-config")
    MODEL_DIR=$(get_config "ai.localAI.modelDir" "./models")
    PORT=$(get_config "ai.localAI.defaultPort" "8080")
    THREADS=$(get_config "ai.localAI.config.threads" "4")
    CONTEXT_SIZE=$(get_config "ai.localAI.config.contextSize" "4096")
    MODEL_NAME=$(get_config "ai.localAI.config.modelName" "llama-3-8b")
    MODEL_FILE=$(get_config "ai.localAI.config.modelFile" "llama-3-8b-instruct-q4_k_m.gguf")
    TEMP=$(get_config "ai.localAI.config.temperature" "0.7")
    TOP_P=$(get_config "ai.localAI.config.topP" "0.9")
    TOP_K=$(get_config "ai.localAI.config.topK" "40")
    
    # Validate port
    if command -v validate_port >/dev/null 2>&1; then
        validate_port "$PORT"
    fi
    
    # Create directories
    mkdir -p "$MODEL_DIR" "$CONFIG_DIR"
    
    # Generate LocalAI config.yaml (always create, use defaults if config not found)
    # FORCE_INSTALL=1 bypasses config check (used by main install recipe)
    SETUP_CONFIG="true"
    if [ "${FORCE_INSTALL:-0}" != "1" ]; then
        if [ -n "$CONFIG_FILE" ] && command -v is_config_enabled >/dev/null 2>&1; then
            if ! is_config_enabled "ai.localAI.setupConfig" 2>/dev/null; then
                SETUP_CONFIG="false"
            fi
        fi
    fi
    
    if [ "$SETUP_CONFIG" = "true" ]; then
        CONFIG_YAML="$CONFIG_DIR/config.yaml"
        log_info "Creating LocalAI config.yaml at $CONFIG_YAML"
        
        # Ensure directory exists
        mkdir -p "$CONFIG_DIR"
        
        {
            echo "# LocalAI Configuration (v3.x format)"
            echo "- name: $MODEL_NAME"
            echo "  backend: llama-cpp"
            echo "  parameters:"
            echo "    model: $MODEL_FILE"
            echo "    temperature: $TEMP"
            echo "    top_p: $TOP_P"
            echo "    top_k: $TOP_K"
            echo "    threads: $THREADS"
            echo "    ctx_size: $CONTEXT_SIZE"
            echo "    f16: true"
            echo "    stop:"
            echo "      - \"<|eot_id|>\""
            echo "      - \"<|end_of_text|>\""
        } > "$CONFIG_YAML"
        
        # Verify file was created
        if [ -f "$CONFIG_YAML" ]; then
            log_success "LocalAI config.yaml created at $CONFIG_YAML"
        else
            log_error "Failed to create config.yaml at $CONFIG_YAML"
            exit 1
        fi
    else
        log_info "Config setup disabled, skipping config.yaml creation"
    fi
    
    # Download model if enabled (default to not downloading automatically)
    DOWNLOAD_ENABLED="false"
    if [ -n "$CONFIG_FILE" ] && command -v is_config_enabled >/dev/null 2>&1; then
        if is_config_enabled "ai.localAI.downloadModel.enabled" 2>/dev/null; then
            DOWNLOAD_ENABLED="true"
        fi
    fi
    
    if [ "$DOWNLOAD_ENABLED" = "true" ]; then
        just download-model MODEL_DIR="$MODEL_DIR" || log_warn "Model download had issues"
    fi
    
    log_success "Configuration applied"

# ============================================================================
# CLEANUP RECIPES
# ============================================================================

# Cleanup everything (removes all installed components)
cleanup:
    #!/usr/bin/env bash
    set -euo pipefail
    . lib/bootstrap.sh
    
    # Check root
    if [ "$(id -u)" != "0" ]; then
        die "Must run as root: doas just cleanup"
    fi
    
    log_info "=========================================="
    log_info "The Black Berets - Cleanup"
    log_info "=========================================="
    log_info ""
    
    # Phase 1: Run feature-specific cleanup commands first
    log_info "Phase 1: Feature-specific cleanup..."
    log_info ""
    
    log_info "Cleaning up LocalAI..."
    just cleanup-localai 2>/dev/null || log_warn "LocalAI cleanup had issues, continuing..."
    
    log_info "Cleaning up MCP server..."
    just cleanup-mcp 2>/dev/null || log_warn "MCP cleanup had issues, continuing..."
    
    log_info "Cleaning up Kali tools..."
    just cleanup-kali 2>/dev/null || log_warn "Kali tools cleanup had issues, continuing..."
    
    log_info "Cleaning up Nix..."
    just cleanup-nix 2>/dev/null || log_warn "Nix cleanup had issues, continuing..."
    
    log_info "Cleaning up just/justdo..."
    just cleanup-just 2>/dev/null || log_warn "just cleanup had issues, continuing..."
    
    log_info ""
    log_info "Phase 2: General cleanup..."
    log_info ""
    
    # Phase 2: General cleanup (remove remaining files and configs)
    
    # Kill any remaining processes
    log_info "Killing any remaining processes..."
    pkill -f "localai" 2>/dev/null || true
    pkill -f "mcp-kali-server.py" 2>/dev/null || true
    pkill -f "nix-daemon" 2>/dev/null || true
    sleep 1
    
    # Remove LocalAI data directories (user data - be careful)
    log_info "Removing LocalAI data directories..."
    rm -rf ./localai-config 2>/dev/null || true
    rm -rf ./models 2>/dev/null || true
    
    # Remove MCP server files from project directory
    rm -f ./mcp-kali-server.py 2>/dev/null || true
    
    # Remove config files and directories
    log_info "Removing configuration files..."
    rm -f /etc/profile.d/just-alias.sh 2>/dev/null || true
    rm -f /etc/profile.d/theblackberets-bashrc.sh 2>/dev/null || true
    rm -f /etc/profile.d/theblackberets-env.sh 2>/dev/null || true
    rm -rf /usr/local/share/theblackberets 2>/dev/null || true
    
    # Remove from .bashrc if added
    if [ -f /root/.bashrc ]; then
        sed -i '/# The Black Berets/,/^fi$/d' /root/.bashrc 2>/dev/null || true
    fi
    
    # Clean up temp files
    log_info "Cleaning up temporary files..."
    rm -rf /tmp/nix-* 2>/dev/null || true
    rm -rf /var/tmp/nix-* 2>/dev/null || true
    
    log_info ""
    log_success "Cleanup completed"
