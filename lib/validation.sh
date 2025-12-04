#!/usr/bin/env bash
# Validation library - input validation and error checking

set -euo pipefail

# Die with error message
die() {
    echo "ERROR: $*" >&2
    exit 1
}

# Warn with message
warn() {
    echo "WARNING: $*" >&2
}

# Info message
info() {
    echo "INFO: $*"
}

# Validate port number (1-65535)
validate_port() {
    local port="$1"
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        die "Invalid port number: $port (must be 1-65535)"
    fi
}

# Validate path exists
validate_path() {
    local path="$1"
    local path_type="${2:-any}"  # file, dir, any
    
    case "$path_type" in
        file)
            [ ! -f "$path" ] && die "File does not exist: $path"
            ;;
        dir)
            [ ! -d "$path" ] && die "Directory does not exist: $path"
            ;;
        any)
            [ ! -e "$path" ] && die "Path does not exist: $path"
            ;;
    esac
}

# Validate URL format
validate_url() {
    local url="$1"
    if [[ ! "$url" =~ ^https?:// ]]; then
        die "Invalid URL format: $url (must start with http:// or https://)"
    fi
}

# Validate required parameter
validate_required() {
    local param_name="$1"
    local param_value="$2"
    [ -z "$param_value" ] && die "Required parameter missing: $param_name"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Require command exists
require_command() {
    local cmd="$1"
    local install_hint="${2:-}"
    if ! command_exists "$cmd"; then
        if [ -n "$install_hint" ]; then
            die "Command not found: $cmd. Install with: $install_hint"
        else
            die "Command not found: $cmd"
        fi
    fi
}

# Validate Nix config syntax
validate_nix_config() {
    local config_file="$1"
    [ ! -f "$config_file" ] && die "Config file not found: $config_file"
    
    # Source Nix if needed
    if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh 2>/dev/null || true
    fi
    
    # Validate Nix syntax
    if command_exists nix; then
        if ! nix-instantiate --parse "$config_file" >/dev/null 2>&1; then
            die "Invalid Nix syntax in config file: $config_file"
        fi
    fi
}

