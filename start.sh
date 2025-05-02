#!/bin/bash

# MeowCoin Platform Startup Script
# This script starts the MeowCoin Platform with automatic setup and self-update capability

# Repository information
REPO_OWNER="ColterD"
REPO_NAME="meowcoin-docker"
BRANCH="main"

# Script version
SCRIPT_VERSION="1.0.0"

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}   MeowCoin Platform Startup Script   ${NC}"
echo -e "${BLUE}   Version: ${SCRIPT_VERSION}         ${NC}"
echo -e "${BLUE}=======================================${NC}"

# Function to check for script updates
check_for_updates() {
    echo -e "${YELLOW}Checking for script updates...${NC}"
    
    # Create a temporary directory
    TMP_DIR=$(mktemp -d)
    
    # Download the latest version of the script
    if curl -s -o "${TMP_DIR}/start.sh" "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}/start.sh"; then
        # Compare the versions
        LATEST_VERSION=$(grep "SCRIPT_VERSION=" "${TMP_DIR}/start.sh" | head -n 1 | cut -d'"' -f2)
        
        if [ -n "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "$SCRIPT_VERSION" ]; then
            echo -e "${YELLOW}A new version of the script is available: ${LATEST_VERSION}${NC}"
            echo -e "${YELLOW}Updating script...${NC}"
            
            # Make the new script executable
            chmod +x "${TMP_DIR}/start.sh"
            
            # Replace the current script with the new one
            cp "${TMP_DIR}/start.sh" "$0"
            
            echo -e "${GREEN}Script updated successfully!${NC}"
            echo -e "${YELLOW}Restarting script...${NC}"
            
            # Clean up
            rm -rf "${TMP_DIR}"
            
            # Restart the script
            exec "$0" "$@"
            exit 0
        else
            echo -e "${GREEN}Script is up to date.${NC}"
        fi
    else
        echo -e "${YELLOW}Could not check for updates. Continuing with current version.${NC}"
    fi
    
    # Clean up
    rm -rf "${TMP_DIR}"
}

# Function to download required files
download_required_files() {
    echo -e "${YELLOW}Downloading required files...${NC}"
    
    # Create required directories
    mkdir -p packages/dashboard/public
    mkdir -p config
    
    # Download the setup.html file
    if [ ! -f packages/dashboard/public/setup.html ]; then
        echo -e "${YELLOW}Downloading setup.html...${NC}"
        mkdir -p packages/dashboard/public
        if curl -s -o "packages/dashboard/public/setup.html" "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}/packages/dashboard/public/setup.html"; then
            echo -e "${GREEN}Downloaded setup.html successfully.${NC}"
        else
            echo -e "${RED}Failed to download setup.html. Please check your internet connection.${NC}"
            exit 1
        fi
    fi
    
    # Download the index.html file
    if [ ! -f packages/dashboard/public/index.html ]; then
        echo -e "${YELLOW}Downloading index.html...${NC}"
        if curl -s -o "packages/dashboard/public/index.html" "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}/packages/dashboard/public/index.html"; then
            echo -e "${GREEN}Downloaded index.html successfully.${NC}"
        else
            echo -e "${RED}Failed to download index.html. Please check your internet connection.${NC}"
            exit 1
        fi
    fi
    
    # Download the docker-compose.yml file
    if [ ! -f docker-compose.yml ]; then
        echo -e "${YELLOW}Downloading docker-compose.yml...${NC}"
        if curl -s -o "docker-compose.yml" "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}/docker-compose.yml"; then
            echo -e "${GREEN}Downloaded docker-compose.yml successfully.${NC}"
        else
            echo -e "${RED}Failed to download docker-compose.yml. Please check your internet connection.${NC}"
            exit 1
        fi
    fi
}

# Check for updates
check_for_updates

# Download required files
download_required_files

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env file with default values...${NC}"
    cat > .env << EOL
# Database Configuration
DATABASE_TYPE=sqlite
DATABASE_HOST=postgres
DATABASE_PORT=5432
DATABASE_NAME=meowcoin
DATABASE_USER=postgres
DATABASE_PASSWORD=postgres

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=

# MeowCoin Node
MEOWCOIN_RPC_USER=meowcoinuser
MEOWCOIN_RPC_PASSWORD=meowcoinpassword

# Monitoring
GRAFANA_ADMIN_PASSWORD=admin
EOL
    echo -e "${GREEN}Created .env file with default values.${NC}"
fi

# Create initial config.json if it doesn't exist
if [ ! -f config/config.json ]; then
    echo -e "${YELLOW}Creating initial configuration...${NC}"
    mkdir -p config
    cat > config/config.json << EOL
{
  "setupCompleted": false,
  "database": {
    "type": "sqlite",
    "path": "/config/meowcoin.db"
  },
  "node": {
    "name": "MeowNode-1",
    "rpcEnabled": true,
    "rpcPort": 9332,
    "p2pPort": 9333,
    "dataDir": "/data/meowcoin",
    "maxConnections": 125
  }
}
EOL
    echo -e "${GREEN}Created initial configuration.${NC}"
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker is not installed. Please install Docker and Docker Compose before running this script.${NC}"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}Docker Compose is not installed. Please install Docker Compose before running this script.${NC}"
    exit 1
fi

# Determine Docker Compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
else
    DOCKER_COMPOSE="docker compose"
fi

# Start the platform
echo -e "${YELLOW}Starting MeowCoin Platform...${NC}"
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