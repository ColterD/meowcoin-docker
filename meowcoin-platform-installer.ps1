# MeowCoin Platform Installer Script (PowerShell)
# Version: 2.0.0

param(
    [Parameter(Position=0)]
    [ValidateSet('install','start','stop','update','status','uninstall','help')]
    [string]$Command = 'help',
    [switch]$tui,
    [switch]$silent,
    [switch]$yes,
    [switch]$force,
    [switch]$debug,
    [string]$config,
    [string]$env,
    [switch]$version
)

$SCRIPT_VERSION = '2.0.0'

function Show-Help {
    Write-Host "MeowCoin Platform Installer v$SCRIPT_VERSION`n"
    Write-Host "Usage: .\meowcoin-platform-installer.ps1 <command> [options]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  install         Install or update the MeowCoin platform"
    Write-Host "  start           Start the MeowCoin platform"
    Write-Host "  stop            Stop the MeowCoin platform"
    Write-Host "  update          Update installer, configs, and platform files"
    Write-Host "  status          Show status of platform services"
    Write-Host "  uninstall       Remove all installed files, containers, and configs"
    Write-Host "  help            Show this help message"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  --tui           Use text-based (TUI) setup wizard"
    Write-Host "  --silent        Run non-interactively (no prompts, use defaults)"
    Write-Host "  --yes           Assume 'yes' to all prompts"
    Write-Host "  --config <file> Use a custom config file"
    Write-Host "  --env <file>    Use a custom .env file"
    Write-Host "  --force         Force overwrite of existing files/configs"
    Write-Host "  --debug         Enable verbose/debug output"
    Write-Host "  --version       Show script version"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  iwr -useb https://github.com/ColterD/meowcoin-docker/raw/main/meowcoin-platform-installer.ps1 | iex"
    Write-Host "  .\meowcoin-platform-installer.ps1 install --tui"
    Write-Host "  .\meowcoin-platform-installer.ps1 start"
}

if ($version) {
    Write-Host $SCRIPT_VERSION
    exit 0
}

function Get-LatestMeowcoinUrl {
    param([string]$os)
    $apiUrl = "https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/latest"
    $json = Invoke-RestMethod -Uri $apiUrl
    if ($os -eq "windows") {
        $pattern = "win64.zip"
    } elseif ($os -eq "linux") {
        $pattern = "x86_64-linux-gnu.tar.gz"
    } elseif ($os -eq "darwin") {
        $pattern = "osx64.tar.gz"
    } else {
        throw "Unsupported OS: $os"
    }
    $asset = $json.assets | Where-Object { $_.name -like "*$pattern" }
    return $asset.browser_download_url
}

switch ($Command) {
    'install'   {
        Write-Host "Starting installation..." -ForegroundColor Yellow
        # Check Docker
        $dockerInstalled = $false
        try {
            docker --version | Out-Null
            $dockerInstalled = $true
        } catch {}
        if (-not $dockerInstalled) {
            Write-Host "Docker is not installed." -ForegroundColor Red
            if ($yes -or $silent) {
                Write-Host "Attempting to install Docker Desktop automatically..." -ForegroundColor Yellow
                $dockerInstaller = "$env:TEMP\DockerDesktopInstaller.exe"
                Start-BitsTransfer -Source "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe" -Destination $dockerInstaller
                Start-Process -FilePath $dockerInstaller -ArgumentList "/install", "/quiet" -Wait
                Remove-Item $dockerInstaller -Force
                # Wait for Docker to be available
                $maxWait = 300
                $waited = 0
                while ($waited -lt $maxWait) {
                    try {
                        docker --version | Out-Null
                        $dockerInstalled = $true
                        break
                    } catch {
                        Start-Sleep -Seconds 5
                        $waited += 5
                    }
                }
                if (-not $dockerInstalled) {
                    Write-Host "Automatic Docker installation failed. Please install manually." -ForegroundColor Red
                    exit 1
                }
            } else {
                $reply = Read-Host "Docker is not installed. Install now? (y/n): "
                if ($reply -match '^[Yy]$') {
                    $dockerInstaller = "$env:TEMP\DockerDesktopInstaller.exe"
                    Start-BitsTransfer -Source "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe" -Destination $dockerInstaller
                    Start-Process -FilePath $dockerInstaller -ArgumentList "/install", "/quiet" -Wait
                    Remove-Item $dockerInstaller -Force
                    $maxWait = 300
                    $waited = 0
                    while ($waited -lt $maxWait) {
                        try {
                            docker --version | Out-Null
                            $dockerInstalled = $true
                            break
                        } catch {
                            Start-Sleep -Seconds 5
                            $waited += 5
                        }
                    }
                    if (-not $dockerInstalled) {
                        Write-Host "Automatic Docker installation failed. Please install manually." -ForegroundColor Red
                        exit 1
                    }
                } else {
                    Write-Host "Docker installation required. Exiting." -ForegroundColor Red
                    exit 1
                }
            }
        }
        # Check Docker Compose
        $composeInstalled = $false
        try {
            docker-compose --version | Out-Null
            $composeInstalled = $true
        } catch {
            try {
                docker compose version | Out-Null
                $composeInstalled = $true
            } catch {}
        }
        if (-not $composeInstalled) {
            Write-Host "Docker Compose is not installed." -ForegroundColor Red
            if ($yes -or $silent) {
                Write-Host "Attempting to install Docker Compose standalone..." -ForegroundColor Yellow
                $composePath = "$env:ProgramFiles\Docker\docker-compose.exe"
                Start-BitsTransfer -Source "https://github.com/docker/compose/releases/download/v2.35.1/docker-compose-windows-x86_64.exe" -Destination $composePath
                $env:PATH += ";$env:ProgramFiles\Docker"
                try {
                    & $composePath --version | Out-Null
                    $composeInstalled = $true
                } catch {}
                if (-not $composeInstalled) {
                    Write-Host "Automatic Docker Compose installation failed. Please install manually." -ForegroundColor Red
                    exit 1
                }
            } else {
                $reply = Read-Host "Docker Compose is not installed. Install now? (y/n): "
                if ($reply -match '^[Yy]$') {
                    $composePath = "$env:ProgramFiles\Docker\docker-compose.exe"
                    Start-BitsTransfer -Source "https://github.com/docker/compose/releases/download/v2.35.1/docker-compose-windows-x86_64.exe" -Destination $composePath
                    $env:PATH += ";$env:ProgramFiles\Docker"
                    try {
                        & $composePath --version | Out-Null
                        $composeInstalled = $true
                    } catch {}
                    if (-not $composeInstalled) {
                        Write-Host "Automatic Docker Compose installation failed. Please install manually." -ForegroundColor Red
                        exit 1
                    }
                } else {
                    Write-Host "Docker Compose installation required. Exiting." -ForegroundColor Red
                    exit 1
                }
            }
        }
        # Create installation directory
        $InstallDir = "meowcoin-platform"
        if (-not (Test-Path -Path $InstallDir)) {
            New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
        }
        Set-Location -Path $InstallDir
        Write-Host "Cloning MeowCoin Platform repository..." -ForegroundColor Yellow
        try {
            if (Test-Path -Path ".git") {
                git pull
            } else {
                git clone https://github.com/ColterD/meowcoin-docker.git .
            }
            Write-Host "Repository cloned successfully." -ForegroundColor Green
            # Automated .env setup
            if (-not (Test-Path -Path ".env")) {
                if (Test-Path -Path ".env.example") {
                    if ($yes -or $silent) {
                        Copy-Item ".env.example" ".env"
                        Write-Host ".env file created from .env.example." -ForegroundColor Green
                    } else {
                        $reply = Read-Host ".env file not found. Copy .env.example to .env? (y/n): "
                        if ($reply -match '^[Yy]$') {
                            Copy-Item ".env.example" ".env"
                            Write-Host ".env file created from .env.example." -ForegroundColor Green
                        } else {
                            Write-Host ".env file is required. Exiting." -ForegroundColor Red
                            exit 1
                        }
                    }
                } else {
                    Write-Host ".env.example not found. Please provide a .env file." -ForegroundColor Red
                    exit 1
                }
            }
            # Config validation after .env setup
            $requiredVars = @('MEOWCOIN_RPC_USER', 'MEOWCOIN_RPC_PASSWORD', 'DB_PASSWORD', 'JWT_SECRET')
            $missingVars = @()
            if (Test-Path -Path ".env") {
                $envLines = Get-Content ".env"
                foreach ($var in $requiredVars) {
                    if (-not ($envLines -match "^$var=")) {
                        $missingVars += $var
                    }
                }
            } else {
                $missingVars = $requiredVars
            }
            if ($missingVars.Count -gt 0) {
                Write-Host "Missing required config values in .env: $($missingVars -join ', ')" -ForegroundColor Red
                if ($yes -or $silent) {
                    Write-Host "Cannot continue without required config. Exiting." -ForegroundColor Yellow
                    exit 1
                } else {
                    $reply = Read-Host "Attempt to auto-generate missing values? [y/N]"
                    if ($reply -match '^[Yy]$') {
                        foreach ($var in $missingVars) {
                            $val = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
                            Add-Content ".env" "$var=$val"
                            Write-Host "Generated $var and added to .env" -ForegroundColor Yellow
                        }
                    } else {
                        Write-Host "Please edit .env and add missing values. Exiting." -ForegroundColor Red
                        exit 1
                    }
                }
            }
            # Automated secret generation and Docker Compose secrets integration
            if (-not (Test-Path -Path "secrets")) {
                New-Item -ItemType Directory -Path "secrets" | Out-Null
            }
            # DB password
            $dbPasswordPath = "secrets/db_password.txt"
            if (-not (Test-Path -Path $dbPasswordPath)) {
                $dbPassword = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
                Set-Content -Path $dbPasswordPath -Value $dbPassword
                Write-Host "Generated DB password: $dbPassword" -ForegroundColor Yellow
                Write-Host "Write this down and store it securely!" -ForegroundColor Red
            }
            # JWT secret
            $jwtSecretPath = "secrets/jwt_secret.txt"
            if (-not (Test-Path -Path $jwtSecretPath)) {
                $jwtSecret = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
                Set-Content -Path $jwtSecretPath -Value $jwtSecret
                Write-Host "Generated JWT secret: $jwtSecret" -ForegroundColor Yellow
                Write-Host "Write this down and store it securely!" -ForegroundColor Red
            }
            # TUI secret management and vault selection
            if ($tui) {
                Write-Host "Secret Management Options:" -ForegroundColor Blue
                Write-Host "1) Local secret generation/storage (default, recommended for most users)"
                Write-Host "2) Lightweight integrated vault (e.g., Vaultwarden, HashiCorp Vault dev mode)"
                Write-Host "3) Third-party vault/service (AWS, Azure, HashiCorp Vault, etc.)"
                $SECRET_OPTION = Read-Host "Choose secret management option [1-3]"
                if (-not $SECRET_OPTION) { $SECRET_OPTION = '1' }
                switch ($SECRET_OPTION) {
                    '1' {
                        Write-Host "Using local secret generation/storage..." -ForegroundColor Yellow
                        # Proceed with local secret generation (existing logic)
                    }
                    '2' {
                        Write-Host "Lightweight vault integration selected. Enabling Vaultwarden service..." -ForegroundColor Yellow
                        # Install Bitwarden CLI if not present
                        if (-not (Get-Command bws -ErrorAction SilentlyContinue)) {
                            Write-Host "Installing Bitwarden Secrets Manager CLI (bws)..." -ForegroundColor Yellow
                            npm install -g @bitwarden/cli
                        }
                        # Prompt for Vaultwarden URL and admin token if not set
                        $vaultUrl = $env:VAULT_URL
                        if (-not $vaultUrl) { $vaultUrl = "http://localhost:8222" }
                        $vaultAdminToken = $env:VAULT_ADMIN_TOKEN
                        if (-not $vaultAdminToken) {
                            $vaultAdminToken = Read-Host "Enter Vaultwarden admin token"
                        }
                        # Authenticate to Vaultwarden (stub, user must log in via web UI for now)
                        Write-Host "Please log in to Vaultwarden via the web UI at $vaultUrl and create required secrets (DB password, JWT secret, etc.)." -ForegroundColor Yellow
                        Write-Host "Fetching secrets from Vaultwarden using bws..." -ForegroundColor Yellow
                        # Example: Fetch DB password (stub, replace with real logic)
                        # bws secret get <db_password_id> --output env > secrets/db_password.txt
                        # bws secret get <jwt_secret_id> --output env > secrets/jwt_secret.txt
                        Write-Host "TODO: Implement automated secret fetch from Vaultwarden via bws CLI." -ForegroundColor Red
                    }
                    '3' {
                        Write-Host "Third-party vault integration selected. (TODO: Implement third-party vault integration prompts and config)" -ForegroundColor Yellow
                        # TODO: Add logic to prompt for third-party vault config and inject secrets from external vault
                    }
                    Default {
                        Write-Host "Invalid option. Defaulting to local secret generation/storage..." -ForegroundColor Yellow
                    }
                }
            }
            # Download and extract latest MeowCoin binary
            $os = if ($IsWindows) { "windows" } elseif ($IsLinux) { "linux" } elseif ($IsMacOS) { "darwin" } else { "linux" }
            $url = Get-LatestMeowcoinUrl $os
            if (-not $url) {
                Write-Host "Could not find a suitable MeowCoin binary for $os." -ForegroundColor Red
                exit 1
            }
            $outFile = if ($os -eq "windows") { "meowcoin-latest.zip" } else { "meowcoin-latest.tar.gz" }
            Invoke-WebRequest -Uri $url -OutFile $outFile
            if ($os -eq "windows") {
                Expand-Archive -Path $outFile -DestinationPath .
            } else {
                tar -xzf $outFile
            }
            Remove-Item $outFile
        } catch {
            Write-Host "Failed to clone repository: $_" -ForegroundColor Red
            exit 1
        }
        Write-Host "Starting MeowCoin Platform..." -ForegroundColor Yellow
        Invoke-Expression "$DOCKER_COMPOSE down"
        Invoke-Expression "$DOCKER_COMPOSE up -d"
        Write-Host "MeowCoin Platform started successfully!" -ForegroundColor Green
        Write-Host "Access the dashboard at: http://localhost:3000" -ForegroundColor Yellow
        # Automated backup scheduling
        $backupScript = "scripts/backup.sh"
        $taskName = "MeowCoinBackup"
        if (Test-Path -Path $backupScript) {
            $taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            if (-not $taskExists) {
                $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -Command 'bash $(Resolve-Path $backupScript)'"
                $trigger = New-ScheduledTaskTrigger -Daily -At 2am
                if ($yes -or $silent) {
                    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Description "MeowCoin Platform daily backup" -User "$env:USERNAME" -RunLevel Highest -Force
                    Write-Host "Backup scheduled daily at 2am via Windows Task Scheduler." -ForegroundColor Green
                } else {
                    $reply = Read-Host "Would you like to schedule daily backups at 2am? (y/n): "
                    if ($reply -match '^[Yy]$') {
                        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Description "MeowCoin Platform daily backup" -User "$env:USERNAME" -RunLevel Highest -Force
                        Write-Host "Backup scheduled daily at 2am via Windows Task Scheduler." -ForegroundColor Green
                    } else {
                        Write-Host "Backup scheduling skipped. You can add it manually later." -ForegroundColor Yellow
                    }
                }
            } else {
                Write-Host "Backup scheduled task already exists. Skipping scheduling." -ForegroundColor Yellow
            }
        } else {
            Write-Host "scripts/backup.sh not found. Skipping backup scheduling." -ForegroundColor Yellow
        }
        # Placeholder: TUI/web wizard integration
    }
    'start'     {
        Write-Host "Starting MeowCoin Platform..." -ForegroundColor Yellow
        # Determine Docker Compose command
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
        Set-Location -Path "meowcoin-platform"
        Invoke-Expression "$DOCKER_COMPOSE up -d"
        Write-Host "MeowCoin Platform started successfully!" -ForegroundColor Green
        Write-Host "Access the dashboard at: http://localhost:3000" -ForegroundColor Yellow
        # Placeholder: TUI/web wizard integration
    }
    'stop'      {
        Write-Host "Stopping MeowCoin Platform..." -ForegroundColor Yellow
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
        Set-Location -Path "meowcoin-platform"
        Invoke-Expression "$DOCKER_COMPOSE down"
        Write-Host "MeowCoin Platform stopped successfully!" -ForegroundColor Green
    }
    'update'    {
        Write-Host "Updating MeowCoin Platform..." -ForegroundColor Yellow
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
        Set-Location -Path "meowcoin-platform"
        git pull
        Invoke-Expression "$DOCKER_COMPOSE down"
        Invoke-Expression "$DOCKER_COMPOSE up -d"
        Write-Host "MeowCoin Platform updated and restarted successfully!" -ForegroundColor Green
    }
    'status'    {
        Write-Host "Checking MeowCoin Platform status..." -ForegroundColor Yellow
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
        Set-Location -Path "meowcoin-platform"
        Invoke-Expression "$DOCKER_COMPOSE ps"
    }
    'uninstall' {
        Write-Host "Uninstalling MeowCoin Platform..." -ForegroundColor Yellow
        if ($yes -or $silent) {
            $CONFIRM = 'y'
        } else {
            $CONFIRM = Read-Host "Are you sure you want to uninstall MeowCoin Platform and remove all data? (y/N): "
        }
        if ($CONFIRM -match '^[Yy]$') {
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
            Set-Location -Path "meowcoin-platform"
            Invoke-Expression "$DOCKER_COMPOSE down -v"
            Set-Location -Path ".."
            Remove-Item -Recurse -Force "meowcoin-platform"
            Write-Host "MeowCoin Platform uninstalled and all data removed." -ForegroundColor Green
        } else {
            Write-Host "Uninstall cancelled." -ForegroundColor Yellow
        }
    }
    'help'      { Show-Help }
    default     { Show-Help }
}

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
    # Automated .env setup
    if (-not (Test-Path -Path ".env")) {
        if (Test-Path -Path ".env.example") {
            if ($yes -or $silent) {
                Copy-Item ".env.example" ".env"
                Write-Host ".env file created from .env.example." -ForegroundColor Green
            } else {
                $reply = Read-Host ".env file not found. Copy .env.example to .env? (y/n): "
                if ($reply -match '^[Yy]$') {
                    Copy-Item ".env.example" ".env"
                    Write-Host ".env file created from .env.example." -ForegroundColor Green
                } else {
                    Write-Host ".env file is required. Exiting." -ForegroundColor Red
                    exit 1
                }
            }
        } else {
            Write-Host ".env.example not found. Please provide a .env file." -ForegroundColor Red
            exit 1
        }
    }
    # Config validation after .env setup
    $requiredVars = @('MEOWCOIN_RPC_USER', 'MEOWCOIN_RPC_PASSWORD', 'DB_PASSWORD', 'JWT_SECRET')
    $missingVars = @()
    if (Test-Path -Path ".env") {
        $envLines = Get-Content ".env"
        foreach ($var in $requiredVars) {
            if (-not ($envLines -match "^$var=")) {
                $missingVars += $var
            }
        }
    } else {
        $missingVars = $requiredVars
    }
    if ($missingVars.Count -gt 0) {
        Write-Host "Missing required config values in .env: $($missingVars -join ', ')" -ForegroundColor Red
        if ($yes -or $silent) {
            Write-Host "Cannot continue without required config. Exiting." -ForegroundColor Yellow
            exit 1
        } else {
            $reply = Read-Host "Attempt to auto-generate missing values? [y/N]"
            if ($reply -match '^[Yy]$') {
                foreach ($var in $missingVars) {
                    $val = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
                    Add-Content ".env" "$var=$val"
                    Write-Host "Generated $var and added to .env" -ForegroundColor Yellow
                }
            } else {
                Write-Host "Please edit .env and add missing values. Exiting." -ForegroundColor Red
                exit 1
            }
        }
    }
    # Automated secret generation and Docker Compose secrets integration
    if (-not (Test-Path -Path "secrets")) {
        New-Item -ItemType Directory -Path "secrets" | Out-Null
    }
    # DB password
    $dbPasswordPath = "secrets/db_password.txt"
    if (-not (Test-Path -Path $dbPasswordPath)) {
        $dbPassword = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
        Set-Content -Path $dbPasswordPath -Value $dbPassword
        Write-Host "Generated DB password: $dbPassword" -ForegroundColor Yellow
        Write-Host "Write this down and store it securely!" -ForegroundColor Red
    }
    # JWT secret
    $jwtSecretPath = "secrets/jwt_secret.txt"
    if (-not (Test-Path -Path $jwtSecretPath)) {
        $jwtSecret = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
        Set-Content -Path $jwtSecretPath -Value $jwtSecret
        Write-Host "Generated JWT secret: $jwtSecret" -ForegroundColor Yellow
        Write-Host "Write this down and store it securely!" -ForegroundColor Red
    }
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
 | |  | |  __/ (_) >  <| |___| (_) | | | | | |    | | (_| | |_| || (_) | |  | | | | |
 |_|  |_|\___|\___/_/\_\\_____\___/|_|_| |_|_|    |_|\__,_|\__|_| \___/|_|  |_| |_| |_|
                                                                                       
"@

Write-Host "Thank you for using MeowCoin Platform!" -ForegroundColor Green
Write-Host "Open your browser and navigate to http://localhost:3000 to complete setup." -ForegroundColor Yellow