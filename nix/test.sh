#!/usr/bin/env bash
# Nix Module Test
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

log_info "Testing Nix module..."

# Test 1: Nix binary exists
if is_installed nix; then
    test_pass "Nix binary installed"
else
    test_fail "Nix binary not found"
fi

# Test 2: Nix daemon running
if is_nix_daemon_running; then
    test_pass "Nix daemon running"
else
    test_fail "Nix daemon not running"
fi

# Test 3: Nix can evaluate expressions
if command -v nix >/dev/null 2>&1; then
    if timeout 5 nix eval --expr "1 + 1" >/dev/null 2>&1 || nix eval --expr "1 + 1" >/dev/null 2>&1; then
        test_pass "Nix can evaluate expressions"
    else
        test_fail "Nix cannot evaluate expressions"
    fi
fi

# Test 4: Nix store accessible
if [ -d /nix/store ]; then
    test_pass "Nix store accessible"
else
    test_fail "Nix store not accessible"
fi

# Summary
test_summary "Nix Module"
exit $?

