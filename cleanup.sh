#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# The Black Berets - Complete System Cleanup
# Removes all installed components: Nix, just, Kali tools, LocalAI, MCP, configs
# ============================================================================

# Constants
readonly USERS_TO_DELETE=("uiuser1" "testdesktop")
readonly SERVICES_TO_DISABLE=("lightdm" "sddm" "gdm" "lxdm" "xdm" "display-manager" "x11" "alsa" "pulseaudio")
readonly DIRECTORIES_TO_CLEAN=("/tmp" "/var/tmp" "/var/cache/apk" "/root/.cache" "/root/.local/share" "/root/.config")
readonly UI_DIRECTORIES_TO_REMOVE=(
    "/usr/share/xsessions" "/usr/share/applications" "/usr/share/desktop-directories"
    "/usr/share/icons" "/usr/share/pixmaps" "/etc/X11"
    "/root/.Xauthority" "/root/.xinitrc" "/root/.xsession" "/root/.xsessionrc"
)

# Logging functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_success() {
    log "✓ $*"
}

log_warn() {
    log "WARNING: $*" >&2
}

log_error() {
    log "ERROR: $*" >&2
}

# Check root permissions
check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_error "This script must be run as root or using 'doas ./cleanup.sh'"
        exit 1
    fi
}

# Verify Alpine Linux
check_alpine() {
    if ! command -v apk >/dev/null 2>&1; then
        log_error "This script is designed for Alpine Linux (apk package manager)"
        exit 1
    fi
}

# Stop and disable services
stop_services() {
    log "Stopping UI-related services..."
    
    # Kill running processes
    for proc in Xorg lightdm sddm gdm lxdm desktop-session; do
        pkill -x "$proc" >/dev/null 2>&1 || true
    done
    sleep 1
    
    # Stop and disable services
    for service in "${SERVICES_TO_DISABLE[@]}"; do
        if [ -f "/etc/init.d/$service" ] || [ -f "/etc/conf.d/$service" ]; then
            [ -f "/etc/init.d/$service" ] && /etc/init.d/"$service" stop >/dev/null 2>&1 || true
            command -v rc-service >/dev/null 2>&1 && rc-service "$service" stop >/dev/null 2>&1 || true
            command -v rc-update >/dev/null 2>&1 && rc-update del "$service" >/dev/null 2>&1 || true
            rm -f "/etc/init.d/$service" "/etc/conf.d/$service" 2>/dev/null || true
            rm -f "/etc/systemd/system/${service}.service" "/usr/lib/systemd/system/${service}.service" 2>/dev/null || true
        fi
    done
    
    log_success "Services stopped"
}

# Remove users
remove_users() {
    local count=0
    log "Removing users..."
    
    for user in "${USERS_TO_DELETE[@]}"; do
        if id "$user" &>/dev/null; then
            pkill -u "$user" >/dev/null 2>&1 || true
            sleep 1
            if deluser --remove-home "$user" 2>/dev/null; then
                count=$((count + 1))
            fi
        fi
    done
    
    log_success "Removed $count users"
}

# Clean directories
clean_directories() {
    log "Cleaning directories..."
    
    for dir in "${DIRECTORIES_TO_CLEAN[@]}"; do
        [ -d "$dir" ] && find "$dir" -mindepth 1 -delete 2>/dev/null || true
    done
    
    # Remove UI directories
    for dir in "${UI_DIRECTORIES_TO_REMOVE[@]}"; do
        [ -d "$dir" ] && rm -rf "$dir" 2>/dev/null || true
        [ -f "$dir" ] && rm -f "$dir" 2>/dev/null || true
    done
    
    # Clean additional caches
    rm -rf /var/cache/* /root/.cache/* /tmp/* /var/tmp/* 2>/dev/null || true
    rm -f /tmp/.X*-lock /tmp/.ICE-unix/* 2>/dev/null || true
    rm -rf /tmp/.X11-unix /tmp/.ICE-unix 2>/dev/null || true
    
    log_success "Directories cleaned"
}

# Remove just and related files
remove_just() {
    log "Removing just command runner..."
    
    # Stop processes
    pkill -f "mcp-kali-server.py" >/dev/null 2>&1 || true
    
    # Remove binaries and wrappers
    rm -f /usr/local/bin/just{do,,-wrapper,.real} 2>/dev/null || true
    
    # Remove bash completion
    rm -f /etc/bash_completion.d/justdo 2>/dev/null || true
    [ -f /etc/bash_completion ] && sed -i '/# The Black Berets - justdo completion/,/^fi$/d' /etc/bash_completion 2>/dev/null || true
    
    # Remove default justfile
    rm -rf /usr/local/share/theblackberets 2>/dev/null || true
    
    # Remove via apk
    if apk info -e just >/dev/null 2>&1; then
        apk del just >/dev/null 2>&1 || log_warn "Failed to remove just via apk"
    fi
    
    # Remove from Nix profile if exists
    if command -v nix >/dev/null 2>&1; then
        [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ] && \
            . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh 2>/dev/null || true
        local just_profile
        just_profile=$(nix profile list 2>/dev/null | grep "just" | awk '{print $1}' || echo "")
        [ -n "$just_profile" ] && nix profile remove "$just_profile" >/dev/null 2>&1 || true
    fi
    
    log_success "just removed"
}

# Remove Nix completely
remove_nix() {
    log "Removing Nix package manager..."
    
    if [ ! -d /nix ]; then
        log "Nix not installed, skipping"
        return 0
    fi
    
    # Clean temp files
    rm -rf /nix/var/nix/temproots/* /nix/var/nix/gcroots/auto/* /tmp/nix-* 2>/dev/null || true
    
    # Stop daemon
    if command -v rc-service >/dev/null 2>&1; then
        rc-service nix-daemon stop >/dev/null 2>&1 || true
        rc-update del nix-daemon >/dev/null 2>&1 || true
    elif [ -f /etc/init.d/nix-daemon ]; then
        /etc/init.d/nix-daemon stop >/dev/null 2>&1 || true
    fi
    
    # Remove config
    rm -f /etc/nix/nix.conf 2>/dev/null || true
    sed -i '/nix/d' /etc/profile 2>/dev/null || true
    
    # Remove via apk
    if apk info -e nix >/dev/null 2>&1; then
        apk del nix >/dev/null 2>&1 || log_warn "Failed to remove Nix via apk"
    fi
    
    # Remove .nix-profile symlink if it exists
    if [ -L /root/.nix-profile ]; then
        rm -f /root/.nix-profile 2>/dev/null || true
    elif [ -e /root/.nix-profile ]; then
        # If it's not a symlink, remove it anyway (shouldn't happen, but handle it)
        rm -rf /root/.nix-profile 2>/dev/null || true
    fi
    
    # Remove store (WARNING: removes ALL Nix packages)
    rm -rf /nix 2>/dev/null || true
    
    # Remove user
    id -u nixbld >/dev/null 2>&1 && deluser nixbld >/dev/null 2>&1 || true
    
    log_success "Nix removed"
}

# Remove LocalAI and related files
remove_localai() {
    log "Removing LocalAI and llama.cpp..."
    
    # Try to load config module to get directories (if available)
    CONFIG_DIR="./localai-config"
    MODEL_DIR="./models"
    
    # Try to source config module if available
    if [ -f "./lib/bootstrap.sh" ]; then
        . ./lib/bootstrap.sh 2>/dev/null || true
        if command -v get_config >/dev/null 2>&1; then
            CONFIG_DIR=$(get_config "ai.localAI.configDir" "./localai-config")
            MODEL_DIR=$(get_config "ai.localAI.modelDir" "./models")
        fi
    elif [ -f "/usr/local/share/theblackberets/lib/bootstrap.sh" ]; then
        . /usr/local/share/theblackberets/lib/bootstrap.sh 2>/dev/null || true
        if command -v get_config >/dev/null 2>&1; then
            CONFIG_DIR=$(get_config "ai.localAI.configDir" "./localai-config")
            MODEL_DIR=$(get_config "ai.localAI.modelDir" "./models")
        fi
    fi
    
    rm -f /usr/local/bin/localai 2>/dev/null || true
    rm -rf ./llama.cpp "$CONFIG_DIR" 2>/dev/null || true
    rm -rf /root/llama.cpp "/root/$CONFIG_DIR" 2>/dev/null || true
    # Also try absolute paths in case we're in a different directory
    [ -d "$CONFIG_DIR" ] && rm -rf "$CONFIG_DIR" 2>/dev/null || true
    [ -d "$MODEL_DIR" ] && rm -rf "$MODEL_DIR" 2>/dev/null || true
    
    log_success "LocalAI removed"
}

# Remove MCP server
remove_mcp() {
    log "Removing MCP server..."
    
    pkill -f "mcp-kali-server.py" >/dev/null 2>&1 || true
    rm -f /usr/local/bin/mcp-kali-server ./mcp-kali-server.py /root/mcp-kali-server.py \
          /usr/local/share/theblackberets/mcp-kali-server.py 2>/dev/null || true
    
    log_success "MCP server removed"
}

# Remove configuration files
remove_configs() {
    log "Removing configuration files..."
    
    # Remove profile scripts
    rm -f /etc/profile.d/{just-alias,theblackberets-bashrc,theblackberets-env}.sh 2>/dev/null || true
    
    # Remove bashrc configs
    for bashrc in /etc/skel/.bashrc /root/.bashrc; do
        [ -f "$bashrc" ] && sed -i '/# The Black Berets - Source system-wide bashrc configuration/,/^fi$/d' "$bashrc" 2>/dev/null || true
    done
    
    # Remove auto-update service
    rm -f /etc/init.d/nix-auto-update /var/run/nix-auto-update.pid /var/log/nix-auto-update.log 2>/dev/null || true
    rm -rf /var/lib/nix-auto-update 2>/dev/null || true
    command -v rc-update >/dev/null 2>&1 && rc-update del nix-auto-update >/dev/null 2>&1 || true
    
    # Remove test logs
    rm -rf ./test-logs /root/test-logs 2>/dev/null || true
    
    log_success "Configuration files removed"
}

# Clean package cache
clean_package_cache() {
    log "Cleaning package cache..."
    apk cache clean >/dev/null 2>&1 || true
    apk autoremove >/dev/null 2>&1 || true
    log_success "Package cache cleaned"
}

# Main execution
main() {
    log "=========================================="
    log "The Black Berets - Complete Cleanup"
    log "=========================================="
    log ""
    
    check_root
    check_alpine
    
    stop_services
    remove_users
    clean_directories
    clean_package_cache
    remove_just
    remove_nix
    remove_localai
    remove_mcp
    remove_configs
    
    log ""
    log "=========================================="
    log "Cleanup Summary"
    log "=========================================="
    log_success "Services stopped and disabled"
    log_success "Users removed"
    log_success "Directories cleaned"
    log_success "just/justdo removed"
    log_success "Nix removed"
    log_success "LocalAI removed"
    log_success "MCP server removed"
    log_success "Configuration files removed"
    log ""
    log "Cleanup completed!"
    log ""
    log "To verify:"
    log "  - Check /etc/init.d/ for remaining services"
    log "  - Check /usr/local/bin/ for remaining binaries"
    log "  - Check /nix/ directory (should be removed)"
}

main "$@"
