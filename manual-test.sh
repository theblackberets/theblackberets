#!/usr/bin/env bash
# Test script for Docker image
# Builds with no cache and runs ephemeral container with bash
# Test logs are saved to ./test-logs on the host via shared volume

set -euo pipefail

IMAGE_NAME="alpine-blackberets-test"
CONTAINER_NAME="alpine-test-$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get absolute path of current directory for volume mount
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_LOGS_DIR="$SCRIPT_DIR/test-logs"
MODELS_DIR="$SCRIPT_DIR/models"
PROJECT_DIR="$SCRIPT_DIR"

# Create test-logs and models directories if they don't exist
mkdir -p "$TEST_LOGS_DIR"
mkdir -p "$MODELS_DIR"

echo -e "${GREEN}Building Docker image with --no-cache...${NC}"
docker build --no-cache -t "$IMAGE_NAME" .

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Docker build failed${NC}" >&2
    exit 1
fi

echo -e "${GREEN}Build completed successfully${NC}"
echo -e "${YELLOW}Starting ephemeral container (will be removed on exit)...${NC}"
echo -e "${YELLOW}Test logs will be saved to: $TEST_LOGS_DIR${NC}"
echo -e "${YELLOW}Models directory mounted at: $MODELS_DIR${NC}"
echo -e "${YELLOW}Project files mounted at: /root/project${NC}"
echo -e "${YELLOW}Type 'exit' to close and remove container${NC}"
echo ""
echo -e "${GREEN}Quick test commands:${NC}"
echo -e "  ${YELLOW}cd /root/project && justdo test${NC}              # Run comprehensive tests (RECOMMENDED)"
echo -e "  ${YELLOW}cd /root/project && justdo status${NC}           # Check service status"
echo -e "  ${YELLOW}cd /root/project && justdo configure${NC}        # Apply configuration"
echo -e "  ${YELLOW}cd /root/project && justdo download-model${NC}   # Download model"
echo -e "  ${YELLOW}cd /root/project && justdo start${NC}            # Start LocalAI"
echo -e "  ${YELLOW}cd /root/project && justdo start-mcp${NC}        # Start MCP server"
echo -e "  ${YELLOW}cd /root/project && doas just cleanup${NC}        # Cleanup everything"
echo ""
echo -e "${YELLOW}Note:${NC} Use ${YELLOW}cd /root/project${NC} first to use the latest justfile from your project!"
echo -e "${YELLOW}Note:${NC} All commands work by default - no parameters needed!"
echo ""

# Run container with:
# --rm: Remove container on exit (no memory)
# -it: Interactive terminal
# --name: Unique name based on PID
# -v: Mount test-logs directory, models directory, and project directory as shared volumes
# -e: Set environment variables for convenience
# bash: Override CMD to run bash with --login to source .bashrc
docker run --rm -it \
    --name "$CONTAINER_NAME" \
    -v "$TEST_LOGS_DIR:/root/test-logs" \
    -v "$MODELS_DIR:/root/models" \
    -v "$PROJECT_DIR:/root/project:ro" \
    -e MODEL_DIR="/root/models" \
    -e CONFIG_DIR="/root/localai-config" \
    -e PORT="8080" \
    "$IMAGE_NAME" /bin/bash --login

echo -e "${GREEN}Container removed. Test logs preserved in: $TEST_LOGS_DIR${NC}"

