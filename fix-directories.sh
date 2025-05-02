#!/bin/bash

# MeowCoin Platform Directory Fix Script
# This script creates any missing directories needed for the platform

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}   MeowCoin Platform Directory Fix    ${NC}"
echo -e "${BLUE}=======================================${NC}"

# Create required directories
echo -e "${YELLOW}Creating required directories...${NC}"

# API services
mkdir -p packages/api/services/auth
mkdir -p packages/api/services/analytics
mkdir -p packages/api/services/notifications

# Create placeholder Dockerfiles in each service directory
echo -e "${YELLOW}Creating placeholder Dockerfiles...${NC}"

# Auth service
mkdir -p packages/api/services/auth/src
cat > packages/api/services/auth/Dockerfile << EOL
FROM node:20-alpine
WORKDIR /app
RUN echo "Auth Service Placeholder" > index.js
CMD ["node", "index.js"]
EOL

# Analytics service
mkdir -p packages/api/services/analytics/src
cat > packages/api/services/analytics/Dockerfile << EOL
FROM node:20-alpine
WORKDIR /app
RUN echo "Analytics Service Placeholder" > index.js
CMD ["node", "index.js"]
EOL

# Notifications service
mkdir -p packages/api/services/notifications/src
cat > packages/api/services/notifications/Dockerfile << EOL
FROM node:20-alpine
WORKDIR /app
RUN echo "Notifications Service Placeholder" > index.js
CMD ["node", "index.js"]
EOL

# Grafana
mkdir -p infrastructure/grafana/provisioning/dashboards/json

# Dashboard
mkdir -p packages/dashboard/public

echo -e "${GREEN}Directory structure fixed successfully!${NC}"
echo -e "${YELLOW}You can now run 'docker-compose up -d' to start the platform.${NC}"
echo -e "${BLUE}=======================================${NC}"