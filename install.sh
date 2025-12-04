#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# The Black Berets - Robust Installation Script
# Installation via: curl -fsSL https://theblackberets.github.io/install.sh | bash
# ============================================================================

# Constants
readonly INSTALL_DIR="/tmp/theblackberets-install"
readonly LOCK_FILE="/tmp/theblackberets-install.lock"
readonly BASE_URL="https://theblackberets.github.io"
readonly FALLBACK_URL="https://raw.githubusercontent.com/theblackberets/theblackberets.github.io/main"

# Track temp files for cleanup
TEMP_FILES=()

# Cleanup function
cleanup() {
    local exit_code=$?
    
    # Remove lock file
    [ -d "$LOCK_FILE" ] && rmdir "$LOCK_FILE" 2>/dev/null || true
    
    # Clean up temp files
    for temp_file in "${TEMP_FILES[@]}"; do
        [ -f "$temp_file" ] && rm -f "$temp_file" 2>/dev/null || true
    done
    
    # Only remove install dir if installation failed (preserve on success for debugging)
    if [ $exit_code -ne 0 ] && [ -d "$INSTALL_DIR" ]; then
        log_warn "Installation failed - cleaning up temporary files..."
        rm -rf "$INSTALL_DIR" 2>/dev/null || true
    fi
    
    exit $exit_code
}

# Setup cleanup trap
trap cleanup EXIT ERR INT TERM

# Fallback logging functions (in case libraries aren't available)
log_info() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")
    echo "[$timestamp] [INFO] $*"
}

log_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")
    echo "[$timestamp] [ERROR] $*" >&2
}

log_warn() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")
    echo "[$timestamp] [WARN] $*" >&2
}

log_success() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")
    echo "[$timestamp] [SUCCESS] $*"
}

die() {
    log_error "$@"
    exit 1
}

# Download file with retries and fallback URLs
download_file() {
    local url_path="$1"
    local output_file="$2"
    local max_retries="${3:-3}"
    local timeout="${4:-30}"
    local error_log
    error_log=$(mktemp)
    TEMP_FILES+=("$error_log")
    
    # Determine download command
    local primary_url="${BASE_URL}/${url_path}"
    local fallback_url="${FALLBACK_URL}/${url_path}"
    
    # Try primary URL with wget
    if command -v wget >/dev/null 2>&1; then
        if wget --timeout="${timeout}" --tries="${max_retries}" --continue -qO "$output_file" "$primary_url" 2>"$error_log"; then
            rm -f "$error_log"
            return 0
        fi
        # Try fallback URL
        if wget --timeout="${timeout}" --tries="${max_retries}" --continue -qO "$output_file" "$fallback_url" 2>"$error_log"; then
            rm -f "$error_log"
            return 0
        fi
    # Try primary URL with curl
    elif command -v curl >/dev/null 2>&1; then
        if curl --max-time "${timeout}" --retry "${max_retries}" --retry-delay 2 -fsSL -C - -o "$output_file" "$primary_url" 2>"$error_log"; then
            rm -f "$error_log"
            return 0
        fi
        # Try fallback URL
        if curl --max-time "${timeout}" --retry "${max_retries}" --retry-delay 2 -fsSL -C - -o "$output_file" "$fallback_url" 2>"$error_log"; then
            rm -f "$error_log"
            return 0
        fi
    else
        rm -f "$error_log"
        return 1
    fi
    
    rm -f "$error_log"
    return 1
}

# ============================================================================
# Phase 1: Pre-Flight Checks
# ============================================================================
preflight_checks() {
    log_info "=========================================="
    log_info "Pre-Flight Checks"
    log_info "=========================================="
    
    # Check 0: Lock file (prevent concurrent execution)
    if [ -d "$LOCK_FILE" ]; then
        die "Installation already in progress (lock file: $LOCK_FILE). If no installation is running, remove the lock file manually."
    fi
    
    # Create lock file (using directory for atomic operation)
    if ! mkdir "$LOCK_FILE" 2>/dev/null; then
        die "Failed to create lock file. Another installation may be in progress."
    fi
    
    # Check 1: Root permissions
    if [ "$(id -u)" != "0" ]; then
        rmdir "$LOCK_FILE" 2>/dev/null || true
        die "Must run as root: doas bash -c '$(curl -fsSL ${BASE_URL}/install.sh)'"
    fi
    
    # Check 2: Operating system
    if [ ! -f /etc/alpine-release ]; then
        log_warn "Not running Alpine Linux - some features may not work"
    else
        log_success "Alpine Linux detected"
    fi
    
    # Check 3: Network connectivity
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        log_success "Network connectivity OK"
    else
        log_warn "No internet connectivity - installation may fail"
    fi
    
    # Check 4: Disk space (need at least 5GB on root, 2GB on /tmp, 3GB on /nix)
    if command -v df >/dev/null 2>&1; then
        # Check root filesystem
        AVAILABLE_SPACE=$(df / | tail -1 | awk '{print $4}' || echo "0")
        if [ "$AVAILABLE_SPACE" -lt 5242880 ]; then  # 5GB in KB
            log_warn "Low disk space on / (<5GB) - installation may fail"
        else
            log_success "Sufficient disk space on / available"
        fi
        
        # Check /tmp (where we download files)
        if [ -d /tmp ]; then
            TMP_SPACE=$(df /tmp | tail -1 | awk '{print $4}' || echo "0")
            if [ "$TMP_SPACE" -lt 2097152 ]; then  # 2GB in KB
                log_warn "Low disk space on /tmp (<2GB) - installation may fail"
            fi
        fi
        
        # Check /nix (if exists, where Nix will install)
        if [ -d /nix ]; then
            NIX_SPACE=$(df /nix | tail -1 | awk '{print $4}' || echo "0")
            if [ "$NIX_SPACE" -lt 3145728 ]; then  # 3GB in KB
                log_warn "Low disk space on /nix (<3GB) - installation may fail"
            fi
        fi
    fi
    
    # Check 5: Required commands (curl/wget)
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        log_info "Installing curl/wget..."
        if command -v apk >/dev/null 2>&1; then
            apk add --no-cache curl wget >/dev/null 2>&1 || die "Cannot install curl/wget"
        else
            die "curl or wget required but not available"
        fi
    fi
    
    log_success "Pre-flight checks passed"
    log_info ""
}

# ============================================================================
# Phase 2: Download All Files
# ============================================================================
download_all_files() {
    log_info "=========================================="
    log_info "Downloading Files"
    log_info "=========================================="
    
    local target_dir="${1:-$INSTALL_DIR}"
    mkdir -p "$target_dir"
    
    # Download main justfile
    log_info "Downloading justfile..."
    if ! download_file "justfile" "$target_dir/justfile"; then
        die "Failed to download justfile"
    fi
    
    # Validate justfile (must exist and be readable)
    if [ ! -f "$target_dir/justfile" ] || [ ! -r "$target_dir/justfile" ]; then
        die "Downloaded justfile is invalid or unreadable"
    fi
    
    # Basic validation: check if it looks like a justfile (contains recipe definitions)
    if ! grep -q "^[a-zA-Z0-9_-]*:" "$target_dir/justfile" 2>/dev/null; then
        log_warn "Downloaded justfile may be invalid (no recipe definitions found)"
    fi
    
    # Download all lib files
    log_info "Downloading libraries..."
    mkdir -p "$target_dir/lib"
    for lib in bootstrap.sh config.sh validation.sh idempotent.sh logging.sh test.sh; do
        if download_file "lib/${lib}" "$target_dir/lib/${lib}"; then
            log_info "  ✓ lib/${lib}"
        else
            log_warn "  ✗ lib/${lib} (optional)"
        fi
    done
    
    # Download config files
    log_info "Downloading configuration files..."
    mkdir -p "$target_dir/config"
    for config in configuration.nix config-to-json.nix flake.nix; do
        if download_file "config/${config}" "$target_dir/config/${config}"; then
            log_info "  ✓ config/${config}"
        else
            log_warn "  ✗ config/${config} (optional)"
        fi
    done
    
    # Download feature modules (justfiles)
    log_info "Downloading feature modules..."
    for feature in nix just kali localai mcp models-management services test; do
        mkdir -p "$target_dir/$feature"
        if download_file "$feature/justfile" "$target_dir/$feature/justfile"; then
            log_info "  ✓ $feature/justfile"
        else
            log_warn "  ✗ $feature/justfile (will use main justfile)"
        fi
        
        # Download module-specific files
        case "$feature" in
            kali)
                download_file "$feature/flake.nix" "$target_dir/$feature/flake.nix" || true
                ;;
            localai)
                download_file "$feature/chat.py" "$target_dir/$feature/chat.py" || true
                ;;
            mcp)
                download_file "$feature/mcp-kali-server.py" "$target_dir/$feature/mcp-kali-server.py" || true
                ;;
        esac
        
        # Download module test files
        if download_file "$feature/test.sh" "$target_dir/$feature/test.sh"; then
            log_info "  ✓ $feature/test.sh"
        fi
    done
    
    log_success "All files downloaded"
    log_info ""
    cd "$target_dir" || die "Cannot change to install directory"
}

# ============================================================================
# Phase 3: Install Module with Testing
# ============================================================================
install_module() {
    local module="$1"
    local recipe="$2"
    local install_dir="${3:-$INSTALL_DIR}"
    local log_file
    log_file=$(mktemp)
    TEMP_FILES+=("$log_file")
    
    log_info "Installing $module..."
    
    # Run installation recipe, capturing output
    if just --justfile "$install_dir/justfile" "$recipe" >"$log_file" 2>&1; then
        log_success "$module installed"
        rm -f "$log_file"
        
        # Run module-specific test if available
        if [ -f "$install_dir/$module/test.sh" ]; then
            log_info "Testing $module..."
            if bash "$install_dir/$module/test.sh" "$install_dir"; then
                log_success "$module test passed"
            else
                log_warn "$module test had warnings (continuing...)"
            fi
        fi
        
        return 0
    else
        log_error "$module installation failed"
        log_error "Installation output:"
        cat "$log_file" >&2 || true
        rm -f "$log_file"
        return 1
    fi
}

# ============================================================================
# Phase 4: Installation (with per-module validation)
# ============================================================================
run_installation() {
    log_info "=========================================="
    log_info "Installation"
    log_info "=========================================="
    
    local install_dir="${1:-$INSTALL_DIR}"
    cd "$install_dir" || die "Cannot change to install directory"
    
    # Ensure just is installed first
    ensure_just_installed
    
    # Install each module with validation
    install_module "nix" "install-nix" "$install_dir" || die "Nix installation failed"
    install_module "just" "install-just" "$install_dir" || die "just installation failed"
    install_module "just" "setup-environment" "$install_dir" || die "Environment setup failed"
    
    # Optional modules (warn but continue on failure)
    if ! install_module "kali" "install-kali-tools" "$install_dir"; then
        log_warn "Kali tools installation failed (optional, continuing...)"
    fi
    
    # Required modules
    install_module "localai" "install-localai" "$install_dir" || die "LocalAI installation failed"
    install_module "mcp" "install-mcp" "$install_dir" || die "MCP installation failed"
    
    # Configure everything
    log_info "Applying configuration..."
    local config_log
    config_log=$(mktemp)
    TEMP_FILES+=("$config_log")
    
    if just --justfile "$install_dir/justfile" configure >"$config_log" 2>&1; then
        log_success "Configuration applied"
        rm -f "$config_log"
    else
        log_warn "Configuration had issues (continuing...)"
        log_warn "Configuration output:"
        cat "$config_log" >&2 || true
        rm -f "$config_log"
    fi
    
    log_success "Installation completed"
    log_info ""
}

# ============================================================================
# Phase 5: Post-Installation Verification
# ============================================================================
post_install_verification() {
    log_info "=========================================="
    log_info "Post-Installation Verification"
    log_info "=========================================="
    
    local install_dir="${1:-$INSTALL_DIR}"
    cd "$install_dir" || die "Cannot change to install directory"
    
    # Run comprehensive test
    local test_log
    test_log=$(mktemp)
    TEMP_FILES+=("$test_log")
    
    if just --justfile "$install_dir/justfile" test >"$test_log" 2>&1; then
        log_success "All verification tests passed"
        rm -f "$test_log"
    else
        log_warn "Some verification tests had warnings (installation may still be functional)"
        log_warn "Test output:"
        cat "$test_log" >&2 || true
        rm -f "$test_log"
    fi
    
    log_info ""
}

# Install just command runner if needed
ensure_just_installed() {
    if command -v just >/dev/null 2>&1; then
        return 0
    fi
    
    log_info "Installing just command runner..."
    
    # Enable community repository if needed
    if command -v apk >/dev/null 2>&1; then
        if ! grep -q "^[^#].*community" /etc/apk/repositories 2>/dev/null; then
            local alpine_version
            alpine_version=$(cat /etc/alpine-release 2>/dev/null | cut -d. -f1,2 || echo "edge")
            if [ "$alpine_version" != "edge" ]; then
                echo "http://dl-cdn.alpinelinux.org/alpine/v${alpine_version}/community" >> /etc/apk/repositories
            else
                echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories
            fi
            apk update >/dev/null 2>&1 || true
        fi
        
        apk add --no-cache just >/dev/null 2>&1 || die "Failed to install just"
    else
        die "apk package manager not found (Alpine Linux required)"
    fi
}

# Create .nix-profile symlink for root user
ensure_nix_profile_symlink() {
    local root_nix_profile="/root/.nix-profile"
    local root_profile_path="/nix/var/nix/profiles/per-user/root/profile"
    
    # Only proceed if Nix is installed
    if [ ! -d /nix ]; then
        return 0
    fi
    
    # Ensure profile directory exists
    mkdir -p "$(dirname "$root_profile_path")" 2>/dev/null || true
    
    # Remove if exists but is not a symlink
    if [ -e "$root_nix_profile" ] && [ ! -L "$root_nix_profile" ]; then
        log_warn "Removing non-symlink $root_nix_profile"
        rm -rf "$root_nix_profile" 2>/dev/null || true
    fi
    
    # Create symlink if it doesn't exist
    if [ ! -L "$root_nix_profile" ]; then
        if ln -sf "$root_profile_path" "$root_nix_profile" 2>/dev/null; then
            log_info "Created $root_nix_profile symlink"
        fi
    fi
}

# ============================================================================
# Main Execution
# ============================================================================
main() {
    log_info "=========================================="
    log_info "The Black Berets - Installation"
    log_info "=========================================="
    log_info ""
    
    # Phase 1: Pre-flight checks
    preflight_checks
    
    # Phase 2: Download all files
    download_all_files "$INSTALL_DIR"
    
    # Phase 3: Installation with per-module tests
    run_installation "$INSTALL_DIR"
    
    # Phase 4: Post-installation verification
    post_install_verification "$INSTALL_DIR"
    
    # Create .nix-profile symlink
    ensure_nix_profile_symlink
    
    log_success "=========================================="
    log_success "Installation Complete!"
    log_success "=========================================="
    log_info ""
    log_info "Next steps:"
    log_info "  Run 'justdo test' to verify installation"
    log_info "  Run 'justdo start' to start LocalAI"
    log_info "  Run 'justdo status' to check service status"
    log_info ""
    
    # Remove lock file on successful completion
    [ -d "$LOCK_FILE" ] && rmdir "$LOCK_FILE" 2>/dev/null || true
    
    # Note: We intentionally keep INSTALL_DIR on success for debugging
    # It will be cleaned up on next run or can be manually removed
}

main "$@"
