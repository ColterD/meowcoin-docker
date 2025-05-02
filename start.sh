#!/bin/bash

# MeowCoin Platform Startup Script
# This script starts the MeowCoin Platform with automatic setup

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}   MeowCoin Platform Startup Script   ${NC}"
echo -e "${BLUE}=======================================${NC}"

# Create required directories
mkdir -p packages/dashboard/public
mkdir -p config

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