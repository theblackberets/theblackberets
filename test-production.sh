#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Production Test Script
# Tests the production installation flow by downloading install.sh from site
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DOCKERFILE="Dockerfile.test-prod"
IMAGE_NAME="theblackberets-test-prod"
CONTAINER_NAME="theblackberets-prod-test"
TEST_LOGS_DIR="$SCRIPT_DIR/test-logs"

# Create test-logs directory if it doesn't exist
mkdir -p "$TEST_LOGS_DIR"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

die() {
    log_error "$*"
    exit 1
}

# Check prerequisites
if ! command -v docker >/dev/null 2>&1; then
    die "Docker is required but not installed"
fi

# Check if Dockerfile exists
if [ ! -f "$DOCKERFILE" ]; then
    die "Dockerfile not found: $DOCKERFILE"
fi

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
}

trap cleanup EXIT

# Build Docker image (without content trust/signatures, with --no-cache for clean test)
log_info "Building production test Docker image with --no-cache..."
if ! DOCKER_CONTENT_TRUST=0 docker build --no-cache  -f "$DOCKERFILE" -t "$IMAGE_NAME" .; then
    die "Failed to build Docker image"
fi

log_info "Docker image built successfully"

# Run container (detached, non-interactive, without signatures)
log_info "Running production test container..."
log_info "This simulates a real user downloading install.sh from the site"

# Start container in detached mode with volume mount for test logs (non-interactive, no signatures)
log_info "Starting container with test-logs volume mount..."
if ! DOCKER_CONTENT_TRUST=0 docker run \
    --name "$CONTAINER_NAME" \
    -d \
    -v "$TEST_LOGS_DIR:/root/test-logs" \
    -e MODEL_DIR="/root/models" \
    -e CONFIG_DIR="/root/localai-config" \
    -e PORT="8080" \
    "$IMAGE_NAME" sleep infinity; then
    die "Failed to start container"
fi

# Wait a bit for installation to complete
log_info "Waiting for installation to complete..."
sleep 10

# Source Nix environment in container for commands to work
log_info "Setting up Nix environment in container..."
docker exec "$CONTAINER_NAME" bash -c '
    for profile in \
        /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
        /root/.nix-profile/etc/profile.d/nix.sh \
        /etc/profile.d/nix.sh; do
        if [ -f "$profile" ]; then
            . "$profile" 2>/dev/null || true
            break
        fi
    done
' || true

# Check installation status while container is running (non-interactive)
log_info ""
log_info "=========================================="
log_info "Checking installation status..."
log_info "=========================================="

check_command() {
    local cmd=$1
    if docker exec "$CONTAINER_NAME" bash -c "command -v $cmd >/dev/null 2>&1"; then
        log_info "✅ $cmd command is available"
        return 0
    else
        log_warn "⚠️  $cmd command not found"
        return 1
    fi
}

check_command "just"
check_command "nix"
check_command "justdo"

# Run comprehensive tests
log_info ""
log_info "=========================================="
log_info "Running comprehensive tests (justdo test)..."
log_info "=========================================="
log_info "Test logs will be saved to: $TEST_LOGS_DIR"

if docker exec "$CONTAINER_NAME" bash -c '
    for profile in \
        /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
        /root/.nix-profile/etc/profile.d/nix.sh \
        /etc/profile.d/nix.sh; do
        if [ -f "$profile" ]; then
            . "$profile" 2>/dev/null || true
            break
        fi
    done
    cd /root
    justdo test 2>&1 | tee /root/test-logs/test-output.log
'; then
    log_info "✅ Comprehensive tests completed"
else
    log_warn "⚠️  Comprehensive tests had issues (check logs)"
fi

# Check service status
log_info ""
log_info "=========================================="
log_info "Checking service status (justdo status)..."
log_info "=========================================="

if docker exec "$CONTAINER_NAME" bash -c '
    for profile in \
        /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
        /root/.nix-profile/etc/profile.d/nix.sh \
        /etc/profile.d/nix.sh; do
        if [ -f "$profile" ]; then
            . "$profile" 2>/dev/null || true
            break
        fi
    done
    cd /root
    justdo status 2>&1 | tee /root/test-logs/status-output.log
'; then
    log_info "✅ Status check completed"
else
    log_warn "⚠️  Status check had issues (check logs)"
fi

log_info ""
log_info "=========================================="
log_info "Production test completed"
log_info "=========================================="
log_info "Test logs saved to: $TEST_LOGS_DIR"
log_info ""
log_info "Dropping into bash shell in container..."
log_info "Container is still running. You can:"
log_info "  - Run commands: justdo test, justdo status, etc."
log_info "  - View logs: docker logs $CONTAINER_NAME"
log_info "  - Exit shell: type 'exit' or press Ctrl+D"
log_info "  - Stop container: docker stop $CONTAINER_NAME"
log_info ""

# Drop into interactive bash shell
docker exec -it "$CONTAINER_NAME" bash -c '
    for profile in \
        /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
        /root/.nix-profile/etc/profile.d/nix.sh \
        /etc/profile.d/nix.sh; do
        if [ -f "$profile" ]; then
            . "$profile" 2>/dev/null || true
            break
        fi
    done
    cd /root
    exec bash
'

