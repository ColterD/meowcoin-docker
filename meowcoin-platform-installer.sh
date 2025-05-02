#!/bin/bash

# MeowCoin Platform Installer Script
# This script downloads and starts the MeowCoin Platform
# Version: 1.0.0

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Repository information
REPO_OWNER="ColterD"
REPO_NAME="meowcoin-docker"
SCRIPT_VERSION="1.0.0"

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}   MeowCoin Platform Installer        ${NC}"
echo -e "${BLUE}   Version: ${SCRIPT_VERSION}         ${NC}"
echo -e "${BLUE}=======================================${NC}"

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed. Please install curl before running this script.${NC}"
    exit 1
fi

# Create installation directory
INSTALL_DIR="meowcoin-platform"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo -e "${YELLOW}Downloading MeowCoin Platform...${NC}"

# Download required files
echo -e "${YELLOW}Downloading required files...${NC}"

# Download start.sh script
echo -e "${YELLOW}Downloading start script...${NC}"
curl -s "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/start.sh" -o "start.sh"
chmod +x "start.sh"

# Download docker-compose.yml
echo -e "${YELLOW}Downloading docker-compose.yml...${NC}"
curl -s "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/docker-compose.yml" -o "docker-compose.yml"

# Create config directory
mkdir -p config

# Create packages/dashboard/public directory
mkdir -p packages/dashboard/public

# Download setup.html
echo -e "${YELLOW}Downloading setup.html...${NC}"
curl -s "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/packages/dashboard/public/setup.html" -o "packages/dashboard/public/setup.html"

# Download index.html
echo -e "${YELLOW}Downloading index.html...${NC}"
curl -s "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/packages/dashboard/public/index.html" -o "packages/dashboard/public/index.html"

echo -e "${GREEN}MeowCoin Platform downloaded successfully!${NC}"
echo -e "${YELLOW}Starting MeowCoin Platform...${NC}"

# Run the start script
./start.sh

echo -e "${GREEN}Installation complete!${NC}"
echo -e "${YELLOW}You can start the platform again by running ./start.sh in the ${INSTALL_DIR} directory.${NC}"