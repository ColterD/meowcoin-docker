# MeowCoin Platform Startup Script for Windows
# This script starts the MeowCoin Platform with automatic setup and self-update capability

# Repository information
$RepoOwner = "ColterD"
$RepoName = "meowcoin-docker"
$Branch = "main"

# Script version
$ScriptVersion = "1.0.0"

Write-Host "=======================================" -ForegroundColor Blue
Write-Host "   MeowCoin Platform Startup Script   " -ForegroundColor Blue
Write-Host "   Version: $ScriptVersion            " -ForegroundColor Blue
Write-Host "=======================================" -ForegroundColor Blue

# Function to check for script updates
function Check-ForUpdates {
    Write-Host "Checking for script updates..." -ForegroundColor Yellow
    
    # Create a temporary file
    $TempFile = [System.IO.Path]::GetTempFileName()
    
    try {
        # Download the latest version of the script
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch/start.ps1" -OutFile $TempFile -ErrorAction Stop
        
        # Get the version from the downloaded script
        $LatestVersion = Select-String -Path $TempFile -Pattern 'ScriptVersion\s*=\s*"([^"]+)"' | ForEach-Object { $_.Matches.Groups[1].Value }
        
        if ($LatestVersion -and $LatestVersion -ne $ScriptVersion) {
            Write-Host "A new version of the script is available: $LatestVersion" -ForegroundColor Yellow
            Write-Host "Updating script..." -ForegroundColor Yellow
            
            # Replace the current script with the new one
            Copy-Item -Path $TempFile -Destination $PSCommandPath -Force
            
            Write-Host "Script updated successfully!" -ForegroundColor Green
            Write-Host "Restarting script..." -ForegroundColor Yellow
            
            # Restart the script
            & $PSCommandPath
            exit
        }
        else {
            Write-Host "Script is up to date." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Could not check for updates. Continuing with current version." -ForegroundColor Yellow
    }
    finally {
        # Clean up
        if (Test-Path $TempFile) {
            Remove-Item -Path $TempFile -Force
        }
    }
}

# Function to download required files
function Download-RequiredFiles {
    Write-Host "Downloading required files..." -ForegroundColor Yellow
    
    # Create required directories
    if (-not (Test-Path -Path "packages/dashboard/public")) {
        New-Item -Path "packages/dashboard/public" -ItemType Directory -Force | Out-Null
        Write-Host "Created dashboard public directory" -ForegroundColor Green
    }
    
    if (-not (Test-Path -Path "config")) {
        New-Item -Path "config" -ItemType Directory -Force | Out-Null
        Write-Host "Created config directory" -ForegroundColor Green
    }
    
    # Download the setup.html file
    if (-not (Test-Path -Path "packages/dashboard/public/setup.html")) {
        Write-Host "Downloading setup.html..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch/packages/dashboard/public/setup.html" -OutFile "packages/dashboard/public/setup.html" -ErrorAction Stop
            Write-Host "Downloaded setup.html successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to download setup.html. Please check your internet connection." -ForegroundColor Red
            exit 1
        }
    }
    
    # Download the index.html file
    if (-not (Test-Path -Path "packages/dashboard/public/index.html")) {
        Write-Host "Downloading index.html..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch/packages/dashboard/public/index.html" -OutFile "packages/dashboard/public/index.html" -ErrorAction Stop
            Write-Host "Downloaded index.html successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to download index.html. Please check your internet connection." -ForegroundColor Red
            exit 1
        }
    }
    
    # Download the docker-compose.yml file
    if (-not (Test-Path -Path "docker-compose.yml")) {
        Write-Host "Downloading docker-compose.yml..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch/docker-compose.yml" -OutFile "docker-compose.yml" -ErrorAction Stop
            Write-Host "Downloaded docker-compose.yml successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to download docker-compose.yml. Please check your internet connection." -ForegroundColor Red
            exit 1
        }
    }
}

# Check for updates
Check-ForUpdates

# Download required files
Download-RequiredFiles

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
Invoke-Expression "$DOCKER_COMPOSE down"
Invoke-Expression "$DOCKER_COMPOSE up -d"

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