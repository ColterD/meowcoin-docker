#!/bin/bash

# MeowCoin Platform Installer Script
# This script sets up and starts the MeowCoin Platform
# Version: 1.0.0

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Script version
SCRIPT_VERSION="1.0.0"

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}   MeowCoin Platform Installer        ${NC}"
echo -e "${BLUE}   Version: ${SCRIPT_VERSION}         ${NC}"
echo -e "${BLUE}=======================================${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed. Please install Docker before running this script.${NC}"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: Docker Compose is not installed. Please install Docker Compose before running this script.${NC}"
    exit 1
fi

# Determine Docker Compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
else
    DOCKER_COMPOSE="docker compose"
fi

# Create installation directory
INSTALL_DIR="meowcoin-platform"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo -e "${YELLOW}Setting up MeowCoin Platform...${NC}"

# Clone the repository
echo -e "${YELLOW}Cloning MeowCoin Platform repository...${NC}"
if [ -d ".git" ]; then
    git pull
else
    git clone https://github.com/ColterD/meowcoin-docker.git .
fi

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to clone repository. Please check your internet connection.${NC}"
    exit 1
fi

echo -e "${GREEN}Repository cloned successfully.${NC}"

echo -e "${GREEN}MeowCoin Platform setup completed!${NC}"
echo -e "${YELLOW}Starting MeowCoin Platform...${NC}"

# Start the platform
$DOCKER_COMPOSE down
$DOCKER_COMPOSE up -d

echo -e "${GREEN}MeowCoin Platform started successfully!${NC}"
echo -e "${YELLOW}Access the dashboard at: http://localhost:3000${NC}"
echo -e "${BLUE}=======================================${NC}"

# Display welcome message
cat << "EOF"
  __  __                 _____      _       _____  _       _    __                     
 |  \/  |               / ____|    (_)     |  __ \| |     | |  / _|                    
 | \  / | ___  _____  _| |     ___  _ _ __ | |__) | | __ _| |_| |_ ___  _ __ _ __ ___  
 | |\/| |/ _ \/ _ \ \/ / |    / _ \| | '_ \|  ___/| |/ _` | __|  _/ _ \| '__| '_ ` _ \ 
 | |  | |  __/ (_) >  <| |___| (_) | | | | | |    | | (_| | |_| || (_) | |  | | | | | |
 |_|  |_|\___|\___/_/\_\\_____\___/|_|_| |_|_|    |_|\__,_|\__|_| \___/|_|  |_| |_| |_|
                                                                                       
EOF

echo -e "${GREEN}Thank you for using MeowCoin Platform!${NC}"
echo -e "${YELLOW}Open your browser and navigate to http://localhost:3000 to complete setup.${NC}"