#!/usr/bin/env bash
# Configuration access library - uses Nix evaluation for type-safe config reading
# All config access goes through this library

set -euo pipefail

# Cache for config JSON (avoids re-evaluating Nix)
_CONFIG_CACHE=""
_CONFIG_CACHE_FILE=""

# Get config JSON (cached)
_get_config_json() {
    local config_file="${1:-}"
    
    # Find config file
    if [ -z "$config_file" ]; then
        for path in "./configuration.nix" "/usr/local/share/theblackberets/configuration.nix"; do
            if [ -f "$path" ]; then
                config_file="$path"
                break
            fi
        done
    fi
    
    # Return empty if no config found
    [ -z "$config_file" ] || [ ! -f "$config_file" ] && return 1
    
    # Check cache
    local file_hash
    file_hash=$(stat -c %Y "$config_file" 2>/dev/null || echo "0")
    
    if [ "$_CONFIG_CACHE_FILE" != "$config_file" ] || [ "${_CONFIG_CACHE_FILE_HASH:-0}" != "$file_hash" ]; then
        # Evaluate Nix config to JSON
        if command -v nix >/dev/null 2>&1; then
            # Source Nix if needed
            if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
                . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh 2>/dev/null || true
            elif [ -f /etc/profile.d/nix.sh ]; then
                . /etc/profile.d/nix.sh 2>/dev/null || true
            elif [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
                . "$HOME/.nix-profile/etc/profile.d/nix.sh" 2>/dev/null || true
            fi
            
            # Use Nix to evaluate config
            local config_dir
            config_dir=$(dirname "$config_file")
            if [ -f "$config_dir/config-to-json.nix" ]; then
                _CONFIG_CACHE=$(cd "$config_dir" && timeout 10 nix eval --json -f config-to-json.nix 2>/dev/null || echo "{}")
            else
                # Fallback: try to parse Nix file with grep/sed (basic support)
                _CONFIG_CACHE="{}"
            fi
            _CONFIG_CACHE_FILE="$config_file"
            _CONFIG_CACHE_FILE_HASH="$file_hash"
        else
            # Fallback: return empty JSON (Nix not installed yet)
            _CONFIG_CACHE="{}"
            _CONFIG_CACHE_FILE="$config_file"
            _CONFIG_CACHE_FILE_HASH="$file_hash"
            return 1
        fi
    fi
    
    echo "$_CONFIG_CACHE"
    return 0
}

# Get config value using jq path
# Usage: get_config "ai.localAI.defaultPort" "8080"
get_config() {
    local key="$1"
    local default="${2:-}"
    local config_json
    
    config_json=$(_get_config_json 2>/dev/null || echo "{}")
    
    # Convert dot notation to jq path
    local jq_path
    jq_path=$(echo "$key" | sed 's/\./\./g')
    
    # Extract value with jq (fallback to grep/sed if jq not available)
    local value
    if command -v jq >/dev/null 2>&1; then
        value=$(echo "$config_json" | jq -r ".$key // \"\"" 2>/dev/null || echo "")
    else
        # Fallback: try to extract from JSON manually (basic support)
        # Convert dot notation to nested access
        local search_key
        search_key=$(echo "$key" | sed 's/\./"."/g')
        value=$(echo "$config_json" | grep -o "\"$search_key\":[^,}]*" 2>/dev/null | sed 's/.*": *"\([^"]*\)".*/\1/' | head -n1 || echo "")
    fi
    
    # Use default if empty
    [ -z "$value" ] || [ "$value" = "null" ] && value="$default"
    
    echo "$value"
}

# Check if config is enabled (boolean)
# Usage: is_config_enabled "ai.localAI.enabled"
is_config_enabled() {
    local key="$1"
    local value
    value=$(get_config "$key" "false")
    [ "$value" = "true" ]
}

# Get nested config value (alias for get_config)
# Usage: get_nested_config "ai.localAI.config.threads" "4"
get_nested_config() {
    get_config "$@"
}

