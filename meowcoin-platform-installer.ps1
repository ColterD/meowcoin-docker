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

# Download start.ps1 script
Write-Host "Downloading start script..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$RepoOwner/$RepoName/main/start.ps1" -OutFile "start.ps1" -UseBasicParsing
    Write-Host "Downloaded start script successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to download start script: $_" -ForegroundColor Red
    exit 1
}

Write-Host "MeowCoin Platform downloaded successfully!" -ForegroundColor Green
Write-Host "Starting MeowCoin Platform..." -ForegroundColor Yellow

# Run the start script
& .\start.ps1

Write-Host "Installation complete!" -ForegroundColor Green
Write-Host "You can start the platform again by running .\start.ps1 in the $InstallDir directory." -ForegroundColor Yellow