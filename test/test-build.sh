#!/bin/bash
set -euo pipefail

# Simple test script to verify the Docker build process
# This script builds the Docker images and performs basic validation

echo "=== Testing Meowcoin Docker Build ==="

# Create test directory
TEST_DIR=$(mktemp -d)
echo "Using temporary directory: $TEST_DIR"

# Function to clean up on exit
cleanup() {
  echo "Cleaning up..."
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Copy necessary files to test directory
echo "Copying files to test directory..."
cp -r /workspace/meowcoin-docker/* "$TEST_DIR/"
cd "$TEST_DIR"

# Build the Docker images
echo "Building Docker images..."
docker compose build

# Verify the images were created
echo "Verifying images..."
if ! docker image ls | grep -q "meowcoin-core"; then
  echo "ERROR: meowcoin-core image not found!"
  exit 1
fi

if ! docker image ls | grep -q "meowcoin-monitor"; then
  echo "ERROR: meowcoin-monitor image not found!"
  exit 1
fi

echo "Images built successfully!"

# Test the healthcheck in entrypoint.sh
echo "Testing healthcheck in entrypoint.sh..."
if ! grep -q "getblockchaininfo" meowcoin-core/entrypoint.sh; then
  echo "ERROR: entrypoint.sh does not contain healthcheck functionality!"
  exit 1
fi

# Verify Dockerfile contains healthcheck
echo "Verifying Dockerfile configuration..."
if ! grep -q "HEALTHCHECK" meowcoin-core/Dockerfile; then
  echo "ERROR: Dockerfile does not contain HEALTHCHECK directive!"
  exit 1
fi

# Verify Docker Compose configuration
echo "Verifying Docker Compose configuration..."
if ! grep -q "healthcheck" docker-compose.yml; then
  echo "ERROR: docker-compose.yml does not contain healthcheck configuration!"
  exit 1
fi

echo "=== All tests passed! ==="
echo "The Docker build process is working correctly."