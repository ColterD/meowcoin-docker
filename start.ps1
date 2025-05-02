# MeowCoin Platform Startup Script for Windows
# This script starts the MeowCoin Platform with automatic setup

Write-Host "=======================================" -ForegroundColor Blue
Write-Host "   MeowCoin Platform Startup Script   " -ForegroundColor Blue
Write-Host "=======================================" -ForegroundColor Blue

# Create required directories
New-Item -ItemType Directory -Force -Path "packages/dashboard/public" | Out-Null
New-Item -ItemType Directory -Force -Path "infrastructure/grafana/provisioning/dashboards/json" | Out-Null
New-Item -ItemType Directory -Force -Path "infrastructure/postgres/init" | Out-Null

# Check if postgres init script exists, if not create it
if (-not (Test-Path "infrastructure/postgres/init/create-multiple-databases.sh")) {
    Write-Host "Creating PostgreSQL initialization script..." -ForegroundColor Yellow
    $script = @"
#!/bin/bash

set -e
set -u

function create_user_and_database() {
    local database=`$1
    echo "Creating user and database '`$database'"
    psql -v ON_ERROR_STOP=1 --username "`$POSTGRES_USER" <<-EOSQL
        CREATE DATABASE `$database;
        GRANT ALL PRIVILEGES ON DATABASE `$database TO `$POSTGRES_USER;
EOSQL
}

if [ -n "`$POSTGRES_MULTIPLE_DATABASES" ]; then
    echo "Multiple database creation requested: `$POSTGRES_MULTIPLE_DATABASES"
    for db in `$(echo `$POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
        create_user_and_database `$db
    done
    echo "Multiple databases created"
fi
"@
    $script | Out-File -FilePath "infrastructure/postgres/init/create-multiple-databases.sh" -Encoding utf8
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