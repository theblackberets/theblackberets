#!/usr/bin/env bash
# Idempotency helpers - check state before operations

set -euo pipefail

# Check if command is installed
is_installed() {
    command -v "$1" >/dev/null 2>&1
}

# Check if service is running
is_service_running() {
    local service="$1"
    pgrep -f "$service" >/dev/null 2>&1
}

# Check if port is in use
is_port_in_use() {
    local port="$1"
    if command -v lsof >/dev/null 2>&1; then
        lsof -Pi :"$port" -sTCP:LISTEN >/dev/null 2>&1
    else
        # Fallback: check with netstat if available
        if command -v netstat >/dev/null 2>&1; then
            netstat -tuln 2>/dev/null | grep -q ":$port " || return 1
        else
            # Last resort: try to connect
            if command -v nc >/dev/null 2>&1; then
                nc -z localhost "$port" 2>/dev/null
            else
                return 1
            fi
        fi
    fi
}

# Get PID using port
get_pid_by_port() {
    local port="$1"
    local pid=""
    
    # Try lsof first (most reliable)
    if command -v lsof >/dev/null 2>&1; then
        pid=$(lsof -ti :"$port" 2>/dev/null | head -n1 | grep -E '^[0-9]+$' || echo "")
        [ -n "$pid" ] && echo "$pid" && return 0
    fi
    
    # Fallback: try ss (common on modern Linux)
    if command -v ss >/dev/null 2>&1; then
        # ss output format: ... users:(("cmd",pid=12345,fd=3))
        pid=$(ss -tlnp 2>/dev/null | grep ":$port " | sed -n 's/.*pid=\([0-9]*\).*/\1/p' | head -n1 || echo "")
        [ -n "$pid" ] && echo "$pid" && return 0
    fi
    
    # Fallback: try netstat
    if command -v netstat >/dev/null 2>&1; then
        # netstat output format varies: ... LISTEN  12345/cmd or ... LISTEN  12345
        # Try to extract PID from the last field that contains numbers
        pid=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{for(i=NF;i>=1;i--) if($i ~ /^[0-9]+\//) {print $i; break}}' | cut -d'/' -f1 | head -n1 | grep -E '^[0-9]+$' || echo "")
        # If that didn't work, try simpler approach (last numeric field)
        if [ -z "$pid" ]; then
            pid=$(netstat -tlnp 2>/dev/null | grep ":$port " | sed -n 's/.*[[:space:]]\([0-9][0-9]*\)\/.*/\1/p' | head -n1 | grep -E '^[0-9]+$' || echo "")
        fi
        [ -n "$pid" ] && echo "$pid" && return 0
    fi
    
    # Last resort: try to find process by port using /proc/net
    if [ -r /proc/net/tcp ] || [ -r /proc/net/tcp6 ]; then
        # This is complex, so we'll skip it for now
        echo ""
        return 0
    fi
    
    echo ""
}

# Check if file exists and is readable
file_exists() {
    [ -f "$1" ] && [ -r "$1" ]
}

# Check if directory exists and is writable
dir_exists() {
    [ -d "$1" ] && [ -w "$1" ]
}

# Check if Nix daemon is running
is_nix_daemon_running() {
    if command -v rc-service >/dev/null 2>&1; then
        rc-service nix-daemon status >/dev/null 2>&1
    else
        pgrep -f "nix-daemon" >/dev/null 2>&1
    fi
}

