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

# Create welcome.txt if it doesn't exist
if [ ! -f welcome.txt ]; then
    echo -e "${YELLOW}Creating welcome.txt file...${NC}"
    cat > welcome.txt << EOL
======================================================
       WELCOME TO MEOWCOIN PLATFORM (2025 Edition)
======================================================

Your MeowCoin Platform is now running! Here's how to access the different components:

DASHBOARDS:
- Main Dashboard: http://localhost:3000
  Default credentials: admin / admin

- Grafana Monitoring: http://localhost:3001
  Default credentials: admin / admin

- Prometheus: http://localhost:9090

- RabbitMQ Management: http://localhost:15672
  Default credentials: guest / guest

API ENDPOINTS:
- API Gateway: http://localhost:8080
- Blockchain API: http://localhost:3002
- Authentication API: http://localhost:3001

IMPORTANT SECURITY NOTICE:
- Default credentials have been set for demonstration purposes
- For production use, please update the passwords in the .env file
- Particularly important to change: JWT_SECRET, MEOWCOIN_RPC_PASSWORD, 
  POSTGRES_PASSWORD, GRAFANA_ADMIN_PASSWORD, and RABBITMQ_PASSWORD

NEXT STEPS:
1. Review and update the .env file with your preferred settings
2. Restart the platform with: docker-compose down && docker-compose up -d
3. Check the logs with: docker-compose logs -f

For more information, see the documentation in the /docs directory.

======================================================
EOL
    echo -e "${GREEN}Created welcome.txt file.${NC}"
fi

echo -e "${GREEN}Directory structure fixed successfully!${NC}"
echo -e "${YELLOW}You can now run 'docker-compose up -d' to start the platform.${NC}"
echo -e "${BLUE}=======================================${NC}"