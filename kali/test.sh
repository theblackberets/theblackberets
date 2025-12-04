#!/usr/bin/env bash
# Kali Tools Module Test
set -euo pipefail

INSTALL_DIR="${1:-/tmp/theblackberets-install}"
cd "$INSTALL_DIR" || exit 1

# Load libraries
. lib/bootstrap.sh || {
    echo "ERROR: Failed to load libraries"
    exit 1
}

# Reset counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNINGS=0

log_info "Testing Kali tools module..."

# Test: Check for common Kali tools
KALI_TOOLS=("nmap" "sqlmap" "hashcat" "john" "aircrack-ng")
TOOLS_FOUND=0

for tool in "${KALI_TOOLS[@]}"; do
    if is_installed "$tool"; then
        TOOLS_FOUND=$((TOOLS_FOUND + 1))
        test_pass "$tool installed"
    else
        test_warn "$tool not installed (optional)"
    fi
done

# Summary
test_summary "Kali Tools Module"

# Don't fail - Kali tools are optional
if [ "$TOOLS_FOUND" -gt 0 ]; then
    exit 0
else
    exit 0  # Still exit 0 - optional module
fi

