#!/bin/bash

# MeowCoin Platform Setup Script
# This script prepares the environment for running the MeowCoin Platform

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}   MeowCoin Platform Setup Script     ${NC}"
echo -e "${BLUE}=======================================${NC}"

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env file with default values...${NC}"
    cat > .env << EOL
# API and Authentication
JWT_SECRET=meowcoin_platform_secret_key_change_in_production
JWT_EXPIRY=24h
API_KEY=meowcoin_api_key_change_in_production

# MeowCoin Node
MEOWCOIN_RPC_USER=meowcoinuser
MEOWCOIN_RPC_PASSWORD=meowcoinpassword
MEOWCOIN_DATA_DIR=/data/meowcoin

# Database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=

# RabbitMQ
RABBITMQ_USER=guest
RABBITMQ_PASSWORD=guest
RABBITMQ_HOST=rabbitmq
RABBITMQ_PORT=5672

# Email Notifications (optional - can be configured later)
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=notifications@example.com
SMTP_PASSWORD=smtp_password
EMAIL_FROM=notifications@meowcoin.com

# SMS Notifications (optional - can be configured later)
TWILIO_ACCOUNT_SID=your_twilio_account_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token
TWILIO_PHONE_NUMBER=+1234567890

# Monitoring
GRAFANA_ADMIN_PASSWORD=admin

# Security
CORS_ALLOWED_ORIGINS=http://localhost:3000,https://dashboard.meowcoin.com
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX_REQUESTS=100

# Feature Flags
ENABLE_MFA=true
ENABLE_ANALYTICS=true
ENABLE_NOTIFICATIONS=true
ENABLE_AUTO_BACKUP=true
EOL
    echo -e "${GREEN}Created .env file with default values.${NC}"
else
    echo -e "${GREEN}.env file already exists. Using existing configuration.${NC}"
fi

# Create required directories
echo -e "${YELLOW}Creating required directories...${NC}"
mkdir -p packages/api/services/auth
mkdir -p packages/api/services/analytics
mkdir -p packages/api/services/notifications
mkdir -p infrastructure/grafana/provisioning/dashboards/json

# Create a welcome message file
cat > welcome.txt << EOL
======================================================
       WELCOME TO MEOWCOIN PLATFORM (2025 Edition)
======================================================

Your MeowCoin Platform is now running! Here's how to access the different components:

DASHBOARDS:
- Main Dashboard: http://localhost:3000
  Default credentials: admin / admin

- Grafana Monitoring: http://localhost:3001
  Default credentials: admin / ${GRAFANA_ADMIN_PASSWORD:-admin}

- Prometheus: http://localhost:9090

- RabbitMQ Management: http://localhost:15672
  Default credentials: ${RABBITMQ_USER:-guest} / ${RABBITMQ_PASSWORD:-guest}

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

echo -e "${GREEN}Setup completed successfully!${NC}"
echo -e "${YELLOW}Next step: Run 'docker-compose up -d' to start the platform.${NC}"
echo -e "${YELLOW}After starting, check 'docker-compose logs' for any issues.${NC}"
echo -e "${BLUE}=======================================${NC}"