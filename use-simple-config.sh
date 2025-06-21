#!/bin/bash
# This script switches to the simplified configuration

echo "Switching to simplified configuration..."

# Copy the simplified files
cp meowcoin-core/Dockerfile.simple meowcoin-core/Dockerfile
cp meowcoin-core/entrypoint.simple.sh meowcoin-core/entrypoint.sh
cp meowcoin-monitor/Dockerfile.simple meowcoin-monitor/Dockerfile
cp meowcoin-monitor/entrypoint.simple.sh meowcoin-monitor/entrypoint.sh
cp docker-compose.simple.yml docker-compose.yml

# Make the entrypoint scripts executable
chmod +x meowcoin-core/entrypoint.sh
chmod +x meowcoin-monitor/entrypoint.sh

echo "Done! You can now build and run the containers with:"
echo "docker compose up -d --build"