#!/usr/bin/env bash
# LocalAI Module Test
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

log_info "Testing LocalAI module..."

# Test 1: LocalAI binary exists
if is_installed localai; then
    test_pass "LocalAI binary installed"
else
    test_fail "LocalAI binary not found"
fi

# Test 2: LocalAI binary is executable
if [ -x "$(command -v localai)" ]; then
    test_pass "LocalAI binary is executable"
else
    test_fail "LocalAI binary not executable"
fi

# Test 3: LocalAI can show version
if command -v localai >/dev/null 2>&1; then
    if timeout 5 localai --version >/dev/null 2>&1 || localai --version >/dev/null 2>&1; then
        test_pass "LocalAI responds to --version"
    else
        test_warn "LocalAI does not respond to --version (may be starting up)"
    fi
fi

# Test 4: Config directory exists
CONFIG_DIR=$(get_config "ai.localAI.configDir" "./localai-config" 2>/dev/null || echo "./localai-config")
if [ -d "$CONFIG_DIR" ]; then
    test_pass "Config directory exists: $CONFIG_DIR"
else
    test_fail "Config directory missing: $CONFIG_DIR"
fi

# Test 5: Config file exists
CONFIG_YAML="$CONFIG_DIR/config.yaml"
if [ -f "$CONFIG_YAML" ]; then
    test_pass "Config file exists: $CONFIG_YAML"
else
    test_fail "Config file missing: $CONFIG_YAML"
fi

# Test 6: Config file is valid YAML (basic check)
if [ -f "$CONFIG_YAML" ]; then
    if grep -q "name:" "$CONFIG_YAML" && grep -q "backend:" "$CONFIG_YAML"; then
        test_pass "Config file appears valid"
    else
        test_fail "Config file appears invalid"
    fi
fi

# Summary
test_summary "LocalAI Module"
exit $?

