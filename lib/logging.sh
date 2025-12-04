#!/usr/bin/env bash
# Structured logging library

set -euo pipefail

# Log level (DEBUG, INFO, WARN, ERROR)
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Get timestamp
_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Log at specific level
_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(_timestamp)
    
    # Color codes
    local color_reset='\033[0m'
    local color_debug='\033[0;36m'
    local color_info='\033[0;32m'
    local color_warn='\033[1;33m'
    local color_error='\033[0;31m'
    
    case "$level" in
        DEBUG)
            [ "$LOG_LEVEL" = "DEBUG" ] && echo -e "${color_debug}[$timestamp] [DEBUG]${color_reset} $message" >&2
            ;;
        INFO)
            echo -e "${color_info}[$timestamp] [INFO]${color_reset} $message"
            ;;
        WARN)
            echo -e "${color_warn}[$timestamp] [WARN]${color_reset} $message" >&2
            ;;
        ERROR)
            echo -e "${color_error}[$timestamp] [ERROR]${color_reset} $message" >&2
            ;;
    esac
}

# Log functions
log_debug() {
    _log DEBUG "$@"
}

log_info() {
    _log INFO "$@"
}

log_warn() {
    _log WARN "$@"
}

log_error() {
    _log ERROR "$@"
}

# Success message (green checkmark)
log_success() {
    echo -e "\033[0;32m✓\033[0m $*"
}

# Failure message (red X)
log_fail() {
    echo -e "\033[0;31m✗\033[0m $*" >&2
}

# Warning message (yellow warning)
log_warning() {
    echo -e "\033[1;33m⚠\033[0m $*" >&2
}

# Info message (blue info)
log_info() {
    echo -e "\033[0;34mℹ\033[0m $*"
}

