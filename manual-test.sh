#!/usr/bin/env bash
# Test script for Docker image
# Builds with no cache and runs ephemeral container with bash

set -euo pipefail

IMAGE_NAME="alpine-blackberets-test"
CONTAINER_NAME="alpine-test-$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building Docker image with --no-cache...${NC}"
docker build --no-cache -t "$IMAGE_NAME" .

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Docker build failed${NC}" >&2
    exit 1
fi

echo -e "${GREEN}Build completed successfully${NC}"
echo -e "${YELLOW}Starting ephemeral container (will be removed on exit)...${NC}"
echo -e "${YELLOW}Type 'exit' to close and remove container${NC}"
echo ""

# Run container with:
# --rm: Remove container on exit (no memory)
# -it: Interactive terminal
# --name: Unique name based on PID
# bash: Override CMD to run bash
docker run --rm -it --name "$CONTAINER_NAME" "$IMAGE_NAME" /bin/bash

echo -e "${GREEN}Container removed. No traces left.${NC}"

