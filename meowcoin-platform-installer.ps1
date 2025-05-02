# MeowCoin Platform Installer Script for Windows
# This script downloads and starts the MeowCoin Platform
# Version: 1.0.0

# Repository information
$RepoOwner = "ColterD"
$RepoName = "meowcoin-docker"
$ScriptVersion = "1.0.0"

Write-Host "=======================================" -ForegroundColor Blue
Write-Host "   MeowCoin Platform Installer        " -ForegroundColor Blue
Write-Host "   Version: $ScriptVersion            " -ForegroundColor Blue
Write-Host "=======================================" -ForegroundColor Blue

# Create installation directory
$InstallDir = "meowcoin-platform"
if (-not (Test-Path -Path $InstallDir)) {
    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
}
Set-Location -Path $InstallDir

Write-Host "Downloading MeowCoin Platform..." -ForegroundColor Yellow

# Download required files
Write-Host "Downloading required files..." -ForegroundColor Yellow

# Download start.ps1 script
Write-Host "Downloading start script..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$RepoOwner/$RepoName/main/start.ps1" -OutFile "start.ps1" -UseBasicParsing
    Write-Host "Downloaded start script successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to download start script: $_" -ForegroundColor Red
    exit 1
}

# Download docker-compose.yml
Write-Host "Downloading docker-compose.yml..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$RepoOwner/$RepoName/main/docker-compose.yml" -OutFile "docker-compose.yml" -UseBasicParsing
    Write-Host "Downloaded docker-compose.yml successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to download docker-compose.yml: $_" -ForegroundColor Red
    exit 1
}

# Create config directory
if (-not (Test-Path -Path "config")) {
    New-Item -Path "config" -ItemType Directory -Force | Out-Null
}

# Create packages/dashboard/public directory
if (-not (Test-Path -Path "packages/dashboard/public")) {
    New-Item -Path "packages/dashboard/public" -ItemType Directory -Force | Out-Null
}

# Download setup.html
Write-Host "Downloading setup.html..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$RepoOwner/$RepoName/main/packages/dashboard/public/setup.html" -OutFile "packages/dashboard/public/setup.html" -UseBasicParsing
    Write-Host "Downloaded setup.html successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to download setup.html: $_" -ForegroundColor Red
    exit 1
}

# Download index.html
Write-Host "Downloading index.html..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$RepoOwner/$RepoName/main/packages/dashboard/public/index.html" -OutFile "packages/dashboard/public/index.html" -UseBasicParsing
    Write-Host "Downloaded index.html successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to download index.html: $_" -ForegroundColor Red
    exit 1
}

Write-Host "MeowCoin Platform downloaded successfully!" -ForegroundColor Green
Write-Host "Starting MeowCoin Platform..." -ForegroundColor Yellow

# Run the start script
& .\start.ps1

Write-Host "Installation complete!" -ForegroundColor Green
Write-Host "You can start the platform again by running .\start.ps1 in the $InstallDir directory." -ForegroundColor Yellow