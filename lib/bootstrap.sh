#!/usr/bin/env bash
# Bootstrap library - loads all other libraries
# Single source of truth for library loading
# Works from any feature directory

set -euo pipefail

# Find lib directory (optimized discovery)
_find_lib_dir() {
    local current_dir="$(pwd)"
    
    # Walk up directory tree looking for lib/
    while [ "$current_dir" != "/" ]; do
        if [ -d "$current_dir/lib" ] && [ -f "$current_dir/lib/config.sh" ]; then
            echo "$current_dir/lib"
            return 0
        fi
        current_dir="$(dirname "$current_dir")"
    done
    
    # Check standard system locations
    for path in "/usr/local/share/theblackberets/lib" "/root/project/lib" "/tmp/theblackberets-install/lib"; do
        if [ -d "$path" ] && [ -f "$path/config.sh" ]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# Load all libraries
LIB_DIR=$(_find_lib_dir)
if [ -n "$LIB_DIR" ] && [ -d "$LIB_DIR" ]; then
    for lib in config validation idempotent logging test; do
        [ -f "$LIB_DIR/$lib.sh" ] && . "$LIB_DIR/$lib.sh" || true
    done
else
    # Fallback: try common locations
    for lib in config validation idempotent logging test; do
        for lib_path in "./lib/$lib.sh" "/usr/local/share/theblackberets/lib/$lib.sh" "/tmp/theblackberets-install/lib/$lib.sh"; do
            if [ -f "$lib_path" ]; then
                . "$lib_path" || true
                break
            fi
        done
    done
fi

