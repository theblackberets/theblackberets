#!/usr/bin/env bash
# Shared configuration parser library
# Efficiently parses configuration.nix values

# Cache for parsed values (avoids re-parsing)
declare -A CONFIG_CACHE

# Parse configuration.nix file once and cache results
# Usage: parse_config_file "path/to/configuration.nix"
parse_config_file() {
    local config_file="${1:-}"
    [ -z "$config_file" ] || [ ! -f "$config_file" ] && return 1
    
    # Clear cache if file changed
    local file_hash=$(stat -c %Y "$config_file" 2>/dev/null || echo "0")
    if [ "${CONFIG_CACHE[_file_hash]:-}" != "$file_hash" ]; then
        CONFIG_CACHE=()
        CONFIG_CACHE[_file_hash]="$file_hash"
        CONFIG_CACHE[_file]="$config_file"
    fi
    
    return 0
}

# Get config value (cached)
# Usage: get_config_value "key" "default"
get_config_value() {
    local key="$1"
    local default="${2:-}"
    local config_file="${CONFIG_CACHE[_file]:-}"
    
    [ -z "$config_file" ] && return 1
    
    # Check cache first
    if [ -n "${CONFIG_CACHE[$key]:+x}" ]; then
        echo "${CONFIG_CACHE[$key]}"
        return 0
    fi
    
    # Parse and cache
    local value=""
    # Handle nested keys (e.g., "ai.localAI.defaultPort")
    if [[ "$key" == *.* ]]; then
        # For nested keys, search for the last part in context of parent sections
        local last_part="${key##*.}"
        local parent_path="${key%.*}"
        # Build pattern: find last_part = value within parent sections
        local pattern="^\s*${last_part}\s*="
        # Try to find in context (simplified - looks for last key in file)
        value=$(grep -E "$pattern" "$config_file" 2>/dev/null | head -n1 | \
            sed -E "s/.*=\s*([^;]+);?.*/\1/" | sed 's/"//g' | tr -d ' ')
    else
        # Simple key - direct match
        value=$(grep -E "^\s*${key}\s*=" "$config_file" 2>/dev/null | head -n1 | \
            sed -E "s/.*=\s*([^;]+);?.*/\1/" | sed 's/"//g' | tr -d ' ')
    fi
    
    # Use default if empty or boolean
    if [ -z "$value" ] || [ "$value" = "true" ] || [ "$value" = "false" ]; then
        [ -n "$default" ] && value="$default"
    fi
    
    # Cache and return
    CONFIG_CACHE[$key]="$value"
    echo "$value"
}

# Check if config is enabled (boolean check)
# Usage: is_config_enabled "key"
is_config_enabled() {
    local key="$1"
    local config_file="${CONFIG_CACHE[_file]:-}"
    [ -z "$config_file" ] && return 1
    
    # Check cache first
    local cache_key="${key}_enabled"
    if [ -n "${CONFIG_CACHE[$cache_key]:+x}" ]; then
        [ "${CONFIG_CACHE[$cache_key]}" = "1" ]
        return $?
    fi
    
    # Parse and cache
    local enabled=false
    if grep -qE "^\s*${key}\s*=\s*true" "$config_file" 2>/dev/null; then
        enabled=true
    fi
    
    CONFIG_CACHE[$cache_key]=$([ "$enabled" = "true" ] && echo "1" || echo "0")
    [ "$enabled" = "true" ]
}

# Get nested config value
# Usage: get_nested_config "section.subsection.key" "default"
get_nested_config() {
    local path="$1"
    local default="${2:-}"
    get_config_value "$path" "$default"
}

