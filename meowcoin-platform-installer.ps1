# MeowCoin Platform Installer Script for Windows
# This script sets up and starts the MeowCoin Platform
# Version: 1.0.0

# Script version
$ScriptVersion = "1.0.0"

Write-Host "=======================================" -ForegroundColor Blue
Write-Host "   MeowCoin Platform Installer        " -ForegroundColor Blue
Write-Host "   Version: $ScriptVersion            " -ForegroundColor Blue
Write-Host "=======================================" -ForegroundColor Blue

# Check if Docker is installed
try {
    docker --version | Out-Null
} catch {
    Write-Host "Error: Docker is not installed. Please install Docker Desktop before running this script." -ForegroundColor Red
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
        Write-Host "Error: Docker Compose is not installed. Please install Docker Compose before running this script." -ForegroundColor Red
        exit 1
    }
}

# Create installation directory
$InstallDir = "meowcoin-platform"
if (-not (Test-Path -Path $InstallDir)) {
    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
}
Set-Location -Path $InstallDir

Write-Host "Setting up MeowCoin Platform..." -ForegroundColor Yellow

# Clone the repository
Write-Host "Cloning MeowCoin Platform repository..." -ForegroundColor Yellow
try {
    if (Test-Path -Path ".git") {
        git pull
    } else {
        git clone https://github.com/ColterD/meowcoin-docker.git .
    }
    Write-Host "Repository cloned successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to clone repository: $_" -ForegroundColor Red
    exit 1
}

Write-Host "MeowCoin Platform setup completed!" -ForegroundColor Green
Write-Host "Starting MeowCoin Platform..." -ForegroundColor Yellow

# Start the platform
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