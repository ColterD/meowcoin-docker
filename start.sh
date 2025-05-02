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

# Check if .env file exists, if not run setup.sh
if [ ! -f .env ]; then
    echo -e "${YELLOW}No .env file found. Running setup script...${NC}"
    ./setup.sh
fi

# Check if required directories exist
mkdir -p packages/api/services/auth
mkdir -p packages/api/services/analytics
mkdir -p packages/api/services/notifications
mkdir -p infrastructure/grafana/provisioning/dashboards/json
mkdir -p packages/dashboard/public

# Check if welcome.txt exists, if not create it
if [ ! -f welcome.txt ]; then
    echo -e "${YELLOW}Creating welcome.txt file...${NC}"
    # Run the setup script to create welcome.txt
    ./setup.sh
fi

# Start the platform
echo -e "${YELLOW}Starting MeowCoin Platform...${NC}"
docker-compose down
docker-compose up -d

echo -e "${GREEN}MeowCoin Platform started successfully!${NC}"
echo -e "${YELLOW}Access the dashboard at: http://localhost:3000${NC}"
echo -e "${YELLOW}For more information, see the README.md file.${NC}"
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