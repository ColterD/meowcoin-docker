# MeowCoin Platform Startup Script for Windows
# This script starts the MeowCoin Platform with automatic setup
# Version: 1.0.0

# Repository information
$RepoOwner = "ColterD"
$RepoName = "meowcoin-docker"
$ScriptVersion = "1.0.0"
$ScriptName = "start.ps1"

Write-Host "=======================================" -ForegroundColor Blue
Write-Host "   MeowCoin Platform Startup Script   " -ForegroundColor Blue
Write-Host "   Version: $ScriptVersion            " -ForegroundColor Blue
Write-Host "=======================================" -ForegroundColor Blue

# Function to check for script updates
function Check-ForUpdates {
    Write-Host "Checking for script updates..." -ForegroundColor Yellow
    
    try {
        # Get the latest version of the script from GitHub
        $LatestScript = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$RepoOwner/$RepoName/main/$ScriptName" -UseBasicParsing
        
        if ($LatestScript.StatusCode -ne 200) {
            Write-Host "Failed to check for updates. Continuing with current version." -ForegroundColor Yellow
            return
        }
        
        # Extract version from the latest script
        $LatestVersionMatch = [regex]::Match($LatestScript.Content, '# Version: ([\d\.]+)')
        
        if (-not $LatestVersionMatch.Success) {
            Write-Host "Could not determine latest version. Continuing with current version." -ForegroundColor Yellow
            return
        }
        
        $LatestVersion = $LatestVersionMatch.Groups[1].Value
        
        # Compare versions (simple string comparison for now)
        if ($LatestVersion -ne $ScriptVersion) {
            Write-Host "New version available: $LatestVersion" -ForegroundColor Green
            Write-Host "Updating script..." -ForegroundColor Yellow
            
            # Create a backup of the current script
            Copy-Item -Path $PSCommandPath -Destination "$PSCommandPath.bak" -Force
            
            # Update the script
            Set-Content -Path $PSCommandPath -Value $LatestScript.Content
            
            Write-Host "Script updated successfully!" -ForegroundColor Green
            Write-Host "Restarting script with new version..." -ForegroundColor Yellow
            
            # Execute the updated script
            & $PSCommandPath
            exit
        } else {
            Write-Host "You are using the latest version." -ForegroundColor Green
        }
    } catch {
        Write-Host "Error checking for updates: $_" -ForegroundColor Yellow
        Write-Host "Continuing with current version." -ForegroundColor Yellow
    }
}

# Function to download required files
function Download-RequiredFiles {
    Write-Host "Checking for required files..." -ForegroundColor Yellow
    
    # Create required directories
    $Directories = @(
        "packages/dashboard/public",
        "infrastructure/grafana/provisioning/dashboards/json",
        "infrastructure/postgres/init",
        "config"
    )
    
    foreach ($Dir in $Directories) {
        if (-not (Test-Path -Path $Dir)) {
            New-Item -Path $Dir -ItemType Directory -Force | Out-Null
            Write-Host "Created directory: $Dir" -ForegroundColor Green
        }
    }
    
    # List of essential files to download if they don't exist
    $EssentialFiles = @(
        "docker-compose.yml",
        "packages/dashboard/public/index.html",
        "packages/dashboard/public/setup-wizard.html",
        "infrastructure/postgres/init/create-multiple-databases.sh"
    )
    
    # Download essential files
    foreach ($File in $EssentialFiles) {
        if (-not (Test-Path -Path $File)) {
            Write-Host "Downloading $File..." -ForegroundColor Yellow
            
            try {
                # Create directory if it doesn't exist
                $Directory = Split-Path -Path $File -Parent
                if (-not (Test-Path -Path $Directory)) {
                    New-Item -Path $Directory -ItemType Directory -Force | Out-Null
                }
                
                # Download file
                Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$RepoOwner/$RepoName/main/$File" -OutFile $File -UseBasicParsing
                Write-Host "Downloaded $File successfully." -ForegroundColor Green
                
                # Make scripts executable on Unix systems
                if ($File -like "*.sh" -and $IsLinux) {
                    chmod +x $File
                }
            } catch {
                Write-Host "Failed to download $File: $_" -ForegroundColor Red
            }
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