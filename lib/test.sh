#!/usr/bin/env bash
# Test utilities library - shared test functions

set -euo pipefail

# Test result tracking
declare -g TESTS_PASSED=0
declare -g TESTS_FAILED=0
declare -g TESTS_WARNINGS=0

test_pass() {
    log_success "✓ $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    log_error "✗ $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

test_warn() {
    log_warn "⚠ $1"
    TESTS_WARNINGS=$((TESTS_WARNINGS + 1))
}

test_info() {
    log_info "ℹ $1"
}

test_summary() {
    local module_name="${1:-Module}"
    log_info "=========================================="
    log_info "$module_name Test Summary"
    log_info "=========================================="
    log_info "Passed: $TESTS_PASSED"
    log_info "Warnings: $TESTS_WARNINGS"
    log_info "Failed: $TESTS_FAILED"
    log_info ""
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        [ "$TESTS_WARNINGS" -eq 0 ] && log_success "All tests passed!" || log_warn "Tests passed with warnings"
        return 0
    else
        log_error "Some tests failed"
        return 1
    fi
}

# Test command exists and works
test_command() {
    local cmd="$1"
    local test_args="${2:---version}"
    
    if is_installed "$cmd"; then
        if timeout 5 "$cmd" $test_args >/dev/null 2>&1 2>/dev/null || "$cmd" $test_args >/dev/null 2>&1; then
            test_pass "$cmd works"
            return 0
        else
            test_fail "$cmd installed but not working"
            return 1
        fi
    else
        test_fail "$cmd not installed"
        return 1
    fi
}

# Test port is available
test_port_available() {
    local port="$1"
    
    if ! is_port_in_use "$port"; then
        test_pass "Port $port is available"
        return 0
    else
        test_fail "Port $port is already in use"
        return 1
    fi
}

# Test file exists and is readable
test_file() {
    local file="$1"
    local description="${2:-$file}"
    
    if [ -f "$file" ] && [ -r "$file" ]; then
        test_pass "$description exists and is readable"
        return 0
    else
        test_fail "$description missing or not readable"
        return 1
    fi
}

# Test directory exists and is writable
test_directory() {
    local dir="$1"
    local description="${2:-$dir}"
    
    if [ -d "$dir" ] && [ -w "$dir" ]; then
        test_pass "$description exists and is writable"
        return 0
    else
        test_fail "$description missing or not writable"
        return 1
    fi
}

