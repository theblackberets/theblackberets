#!/usr/bin/env bash
# MCP Server Module Test
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

log_info "Testing MCP server module..."

# Test 1: Python 3 available
if is_installed python3; then
    test_pass "Python 3 available"
else
    test_fail "Python 3 not found"
fi

# Test 2: MCP server script exists
MCP_SCRIPT=""
for path in "./mcp/mcp-kali-server.py" "/usr/local/bin/mcp-kali-server" "/usr/local/share/theblackberets/mcp-kali-server.py" "./mcp-kali-server.py"; do
    if [ -f "$path" ]; then
        MCP_SCRIPT="$path"
        break
    fi
done

if [ -n "$MCP_SCRIPT" ] && [ -f "$MCP_SCRIPT" ]; then
    test_pass "MCP server script found: $MCP_SCRIPT"
else
    test_fail "MCP server script not found"
fi

# Test 3: MCP server script is executable
if [ -n "$MCP_SCRIPT" ] && [ -x "$MCP_SCRIPT" ]; then
    test_pass "MCP server script is executable"
else
    test_warn "MCP server script not executable"
fi

# Test 4: Python can import required modules (basic check)
if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import sys" >/dev/null 2>&1; then
        test_pass "Python 3 can execute scripts"
    else
        test_fail "Python 3 cannot execute scripts"
    fi
fi

# Summary
test_summary "MCP Server Module"
exit $?

