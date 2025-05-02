# MeowCoin Platform Startup Script for Windows
# This script starts the MeowCoin Platform with automatic setup

Write-Host "=======================================" -ForegroundColor Blue
Write-Host "   MeowCoin Platform Startup Script   " -ForegroundColor Blue
Write-Host "=======================================" -ForegroundColor Blue

# Create required directories
if (-not (Test-Path -Path "packages/dashboard/public")) {
    New-Item -Path "packages/dashboard/public" -ItemType Directory -Force | Out-Null
    Write-Host "Created dashboard public directory" -ForegroundColor Green
}

if (-not (Test-Path -Path "config")) {
    New-Item -Path "config" -ItemType Directory -Force | Out-Null
    Write-Host "Created config directory" -ForegroundColor Green
}

# Create .env file if it doesn't exist
if (-not (Test-Path -Path ".env")) {
    Write-Host "Creating .env file with default values..." -ForegroundColor Yellow
    @"
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
"@ | Out-File -FilePath ".env" -Encoding utf8
    Write-Host "Created .env file with default values." -ForegroundColor Green
}

# Create initial config.json if it doesn't exist
if (-not (Test-Path -Path "config/config.json")) {
    Write-Host "Creating initial configuration..." -ForegroundColor Yellow
    @"
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
"@ | Out-File -FilePath "config/config.json" -Encoding utf8
    Write-Host "Created initial configuration." -ForegroundColor Green
}

# Check if Docker is installed
try {
    docker --version | Out-Null
} catch {
    Write-Host "Docker is not installed. Please install Docker Desktop before running this script." -ForegroundColor Red
    exit 1
}

# Check if Docker Compose is installed
try {
    docker-compose --version | Out-Null
    $DOCKER_COMPOSE = "docker-compose"
} catch {
    try {
        docker compose version | Out-Null
        $DOCKER_COMPOSE = "docker compose"
    } catch {
        Write-Host "Docker Compose is not installed. Please install Docker Compose before running this script." -ForegroundColor Red
        exit 1
    }
}

# Start the platform
Write-Host "Starting MeowCoin Platform..." -ForegroundColor Yellow
docker-compose down
docker-compose up -d

Write-Host "MeowCoin Platform started successfully!" -ForegroundColor Green
Write-Host "Access the dashboard at: http://localhost:3000" -ForegroundColor Yellow
Write-Host "=======================================" -ForegroundColor Blue

# Display welcome message
Write-Host @"
  __  __                 _____      _       _____  _       _    __                     
 |  \/  |               / ____|    (_)     |  __ \| |     | |  / _|                    
 | \  / | ___  _____  _| |     ___  _ _ __ | |__) | | __ _| |_| |_ ___  _ __ _ __ ___  
 | |\/| |/ _ \/ _ \ \/ / |    / _ \| | '_ \|  ___/| |/ _` | __|  _/ _ \| '__| '_ ` _ \ 
 | |  | |  __/ (_) >  <| |___| (_) | | | | | |    | | (_| | |_| || (_) | |  | | | | | |
 |_|  |_|\___|\___/_/\_\\_____\___/|_|_| |_|_|    |_|\__,_|\__|_| \___/|_|  |_| |_| |_|
                                                                                       
"@

Write-Host "Thank you for using MeowCoin Platform!" -ForegroundColor Green
Write-Host "Open your browser and navigate to http://localhost:3000 to complete setup." -ForegroundColor Yellow