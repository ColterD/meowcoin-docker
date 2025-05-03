#!/bin/bash

set -e

# MeowCoin Platform Installer Script
# This script sets up and starts the MeowCoin Platform
# Version: 2.0.0

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_VERSION="2.0.0"

show_help() {
  cat <<EOF
MeowCoin Platform Installer v$SCRIPT_VERSION

Usage: $0 <command> [options]

Commands:
  install         Install or update the MeowCoin platform
  start           Start the MeowCoin platform
  stop            Stop the MeowCoin platform
  update          Update installer, configs, and platform files
  status          Show status of platform services
  uninstall       Remove all installed files, containers, and configs
  help            Show this help message

Options:
  --tui           Use text-based (TUI) setup wizard
  --silent        Run non-interactively (no prompts, use defaults)
  --yes, -y       Assume "yes" to all prompts
  --config <file> Use a custom config file
  --env <file>    Use a custom .env file
  --force         Force overwrite of existing files/configs
  --debug         Enable verbose/debug output
  --version       Show script version

Examples:
  curl -fsSL https://github.com/ColterD/meowcoin-docker/raw/main/meowcoin-platform-installer.sh | bash -s install --yes
  ./meowcoin-platform-installer.sh install --tui
  ./meowcoin-platform-installer.sh start
EOF
}

# Default values for options
TUI=0
SILENT=0
YES=0
FORCE=0
DEBUG=0
CONFIG_FILE=""
ENV_FILE=""

COMMAND=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    install|start|stop|update|status|uninstall|help)
      COMMAND="$1"
      shift
      ;;
    --tui)
      TUI=1
      shift
      ;;
    --silent)
      SILENT=1
      shift
      ;;
    --yes|-y)
      YES=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --debug)
      DEBUG=1
      shift
      ;;
    --config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --env)
      ENV_FILE="$2"
      shift 2
      ;;
    --version)
      echo "$SCRIPT_VERSION"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      show_help
      exit 1
      ;;
  esac
done

if [[ -z "$COMMAND" ]]; then
  show_help
  exit 0
fi

case "$COMMAND" in
  install)
    echo -e "${YELLOW}Starting installation...${NC}"
    # Check Docker
    if ! command -v docker &> /dev/null; then
      echo -e "${RED}Docker is not installed.${NC}"
      if [[ $YES -eq 1 || $SILENT -eq 1 ]]; then
        echo -e "${YELLOW}Attempting to install Docker automatically...${NC}"
        curl -fsSL https://get.docker.com | sh
        if ! command -v docker &> /dev/null; then
          echo -e "${RED}Automatic Docker installation failed. Please install manually.${NC}"
          exit 1
        fi
      else
        read -p "Docker is not installed. Install now? (y/n): " REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          curl -fsSL https://get.docker.com | sh
          if ! command -v docker &> /dev/null; then
            echo -e "${RED}Automatic Docker installation failed. Please install manually.${NC}"
            exit 1
          fi
        else
          echo -e "${RED}Docker installation required. Exiting.${NC}"
          exit 1
        fi
      fi
    fi
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
      echo -e "${RED}Docker Compose is not installed.${NC}"
      if [[ $YES -eq 1 || $SILENT -eq 1 ]]; then
        echo -e "${YELLOW}Attempting to install Docker Compose plugin automatically...${NC}"
        DOCKER_COMPOSE_VERSION="v2.29.2"
        mkdir -p ~/.docker/cli-plugins/
        curl -SL https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m) -o ~/.docker/cli-plugins/docker-compose
        chmod +x ~/.docker/cli-plugins/docker-compose
        export PATH="$HOME/.docker/cli-plugins:$PATH"
        if ! docker compose version &> /dev/null; then
          echo -e "${RED}Automatic Docker Compose installation failed. Please install manually.${NC}"
          exit 1
        fi
      else
        read -p "Docker Compose is not installed. Install now? (y/n): " REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          DOCKER_COMPOSE_VERSION="v2.29.2"
          mkdir -p ~/.docker/cli-plugins/
          curl -SL https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m) -o ~/.docker/cli-plugins/docker-compose
          chmod +x ~/.docker/cli-plugins/docker-compose
          export PATH="$HOME/.docker/cli-plugins:$PATH"
          if ! docker compose version &> /dev/null; then
            echo -e "${RED}Automatic Docker Compose installation failed. Please install manually.${NC}"
            exit 1
          fi
        else
          echo -e "${RED}Docker Compose installation required. Exiting.${NC}"
          exit 1
        fi
      fi
    fi
    # Determine Docker Compose command
    if command -v docker-compose &> /dev/null; then
      DOCKER_COMPOSE="docker-compose"
    else
      DOCKER_COMPOSE="docker compose"
    fi
    # Create installation directory
    INSTALL_DIR="meowcoin-platform"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    echo -e "${YELLOW}Cloning MeowCoin Platform repository...${NC}"
    if [ -d ".git" ]; then
      git pull
    else
      git clone https://github.com/ColterD/meowcoin-docker.git .
    fi
    if [ $? -ne 0 ]; then
      echo -e "${RED}Failed to clone repository. Please check your internet connection.${NC}"
      exit 1
    fi
    # Automated .env setup
    if [ ! -f .env ]; then
      if [ -f .env.example ]; then
        if [[ $YES -eq 1 || $SILENT -eq 1 ]]; then
          cp .env.example .env
          echo -e "${GREEN}.env file created from .env.example.${NC}"
        else
          read -p ".env file not found. Copy .env.example to .env? (y/n): " REPLY
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            cp .env.example .env
            echo -e "${GREEN}.env file created from .env.example.${NC}"
          else
            echo -e "${RED}.env file is required. Exiting.${NC}"
            exit 1
          fi
        fi
      else
        echo -e "${RED}.env.example not found. Please provide a .env file.${NC}"
        exit 1
      fi
    fi
    # Automated secret generation and Docker Compose secrets integration
    mkdir -p secrets
    # DB password
    if [ ! -f secrets/db_password.txt ]; then
      DB_PASSWORD=$(openssl rand -hex 32)
      echo "$DB_PASSWORD" > secrets/db_password.txt
      echo -e "${YELLOW}Generated DB password: $DB_PASSWORD${NC}"
      echo -e "${RED}Write this down and store it securely!${NC}"
    fi
    # JWT secret
    if [ ! -f secrets/jwt_secret.txt ]; then
      JWT_SECRET=$(openssl rand -hex 32)
      echo "$JWT_SECRET" > secrets/jwt_secret.txt
      echo -e "${YELLOW}Generated JWT secret: $JWT_SECRET${NC}"
      echo -e "${RED}Write this down and store it securely!${NC}"
    fi
    echo -e "${GREEN}Repository cloned successfully.${NC}"
    # Build Docker images (including real MeowCoin node)
    echo -e "${YELLOW}Building Docker images...${NC}"
    $DOCKER_COMPOSE build
    echo -e "${GREEN}Docker images built successfully.${NC}"
    echo -e "${YELLOW}Starting MeowCoin Platform...${NC}"
    $DOCKER_COMPOSE down
    $DOCKER_COMPOSE up -d
    echo -e "${GREEN}MeowCoin Platform started successfully!${NC}"
    echo -e "${YELLOW}Access the dashboard at: http://localhost:3000${NC}"
    # Automated backup scheduling
    if [ -f scripts/backup.sh ]; then
      CRON_JOB="0 2 * * * cd $(pwd) && ./scripts/backup.sh >> ./backup.log 2>&1"
      (crontab -l 2>/dev/null | grep -F "$CRON_JOB") && CRON_EXISTS=1 || CRON_EXISTS=0
      if [ $CRON_EXISTS -eq 0 ]; then
        if [[ $YES -eq 1 || $SILENT -eq 1 ]]; then
          (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
          echo -e "${GREEN}Backup scheduled daily at 2am via cron.${NC}"
        else
          read -p "Would you like to schedule daily backups at 2am? (y/n): " REPLY
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
            echo -e "${GREEN}Backup scheduled daily at 2am via cron.${NC}"
          else
            echo -e "${YELLOW}Backup scheduling skipped. You can add it manually later.${NC}"
          fi
        fi
      else
        echo -e "${YELLOW}Backup cron job already exists. Skipping scheduling.${NC}"
      fi
    else
      echo -e "${YELLOW}scripts/backup.sh not found. Skipping backup scheduling.${NC}"
    fi
    # TUI secret management and vault selection
    if [[ $TUI -eq 1 ]]; then
      echo -e "${BLUE}Secret Management Options:${NC}"
      echo "1) Local secret generation/storage (default, recommended for most users)"
      echo "2) Lightweight integrated vault (e.g., Vaultwarden, HashiCorp Vault dev mode)"
      echo "3) Third-party vault/service (AWS, Azure, HashiCorp Vault, etc.)"
      read -p "Choose secret management option [1-3]: " SECRET_OPTION
      SECRET_OPTION=${SECRET_OPTION:-1}
      case $SECRET_OPTION in
        1)
          echo -e "${YELLOW}Using local secret generation/storage...${NC}"
          # Proceed with local secret generation (existing logic)
          ;;
        2)
          echo -e "${YELLOW}Lightweight vault integration selected. Enabling Vaultwarden service...${NC}"
          # Install Bitwarden CLI if not present
          if ! command -v bws &> /dev/null; then
            echo -e "${YELLOW}Installing Bitwarden Secrets Manager CLI (bws)...${NC}"
            npm install -g @bitwarden/cli
          fi
          # Prompt for Vaultwarden URL and admin token if not set
          VAULT_URL=${VAULT_URL:-"http://localhost:8222"}
          VAULT_ADMIN_TOKEN=${VAULT_ADMIN_TOKEN:-""}
          if [ -z "$VAULT_ADMIN_TOKEN" ]; then
            read -p "Enter Vaultwarden admin token: " VAULT_ADMIN_TOKEN
          fi
          # Authenticate to Vaultwarden (stub, user must log in via web UI for now)
          echo -e "${YELLOW}Please log in to Vaultwarden via the web UI at $VAULT_URL and create required secrets (DB password, JWT secret, etc.).${NC}"
          echo -e "${YELLOW}Fetching secrets from Vaultwarden using bws...${NC}"
          # Example: Fetch DB password (stub, replace with real logic)
          # bws secret get <db_password_id> --output env > secrets/db_password.txt
          # bws secret get <jwt_secret_id> --output env > secrets/jwt_secret.txt
          echo -e "${RED}TODO: Implement automated secret fetch from Vaultwarden via bws CLI.${NC}"
          ;;
        3)
          echo -e "${YELLOW}Third-party vault integration selected. (TODO: Implement third-party vault integration prompts and config)${NC}"
          # TODO: Add logic to prompt for third-party vault config and inject secrets from external vault
          ;;
        *)
          echo -e "${YELLOW}Invalid option. Defaulting to local secret generation/storage...${NC}"
          ;;
      esac
    fi
    # Placeholder: TUI/web wizard integration
    # Config validation after .env setup
    REQUIRED_VARS=(MEOWCOIN_RPC_USER MEOWCOIN_RPC_PASSWORD DB_PASSWORD JWT_SECRET)
    MISSING_VARS=()
    for VAR in "${REQUIRED_VARS[@]}"; do
      if ! grep -q "^$VAR=" .env 2>/dev/null; then
        MISSING_VARS+=("$VAR")
      fi
    done
    if [ ${#MISSING_VARS[@]} -ne 0 ]; then
      echo -e "${RED}Missing required config values in .env: ${MISSING_VARS[*]}${NC}"
      if [[ $YES -eq 1 || $SILENT -eq 1 ]]; then
        echo -e "${YELLOW}Cannot continue without required config. Exiting.${NC}"
        exit 1
      else
        read -p "Attempt to auto-generate missing values? [y/N]: " REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          for VAR in "${MISSING_VARS[@]}"; do
            VAL=$(openssl rand -hex 32)
            echo "$VAR=$VAL" >> .env
            echo -e "${YELLOW}Generated $VAR and added to .env${NC}"
          done
        else
          echo -e "${RED}Please edit .env and add missing values. Exiting.${NC}"
          exit 1
        fi
      fi
    fi
    # Download and extract latest MeowCoin binary
    OS_TYPE="$(uname | tr '[:upper:]' '[:lower:]')"
    ASSET_URL=$(get_latest_meowcoin_url "$OS_TYPE")
    if [[ -z "$ASSET_URL" ]]; then
      echo -e "${RED}Could not find a suitable MeowCoin binary for $OS_TYPE.${NC}"
      exit 1
    fi
    curl -L -o meowcoin-latest.tar.gz "$ASSET_URL"
    tar -xzf meowcoin-latest.tar.gz
    rm meowcoin-latest.tar.gz
    ;;
  start)
    echo -e "${YELLOW}Starting MeowCoin Platform...${NC}"
    # Determine Docker Compose command
    if command -v docker-compose &> /dev/null; then
      DOCKER_COMPOSE="docker-compose"
    else
      DOCKER_COMPOSE="docker compose"
    fi
    $DOCKER_COMPOSE up -d
    echo -e "${GREEN}MeowCoin Platform started successfully!${NC}"
    echo -e "${YELLOW}Access the dashboard at: http://localhost:3000${NC}"
    # Placeholder: TUI/web wizard integration
    ;;
  stop)
    echo -e "${YELLOW}Stopping MeowCoin Platform...${NC}"
    if command -v docker-compose &> /dev/null; then
      DOCKER_COMPOSE="docker-compose"
    else
      DOCKER_COMPOSE="docker compose"
    fi
    $DOCKER_COMPOSE down
    echo -e "${GREEN}MeowCoin Platform stopped successfully!${NC}"
    ;;
  update)
    echo -e "${YELLOW}Updating MeowCoin Platform...${NC}"
    if command -v docker-compose &> /dev/null; then
      DOCKER_COMPOSE="docker-compose"
    else
      DOCKER_COMPOSE="docker compose"
    fi
    git pull
    $DOCKER_COMPOSE down
    $DOCKER_COMPOSE up -d
    echo -e "${GREEN}MeowCoin Platform updated and restarted successfully!${NC}"
    ;;
  status)
    echo -e "${YELLOW}Checking MeowCoin Platform status...${NC}"
    if command -v docker-compose &> /dev/null; then
      DOCKER_COMPOSE="docker-compose"
    else
      DOCKER_COMPOSE="docker compose"
    fi
    $DOCKER_COMPOSE ps
    ;;
  uninstall)
    echo -e "${YELLOW}Uninstalling MeowCoin Platform...${NC}"
    if [[ $YES -eq 1 || $SILENT -eq 1 ]]; then
      CONFIRM="y"
    else
      read -p "Are you sure you want to uninstall MeowCoin Platform and remove all data? (y/N): " CONFIRM
    fi
    if [[ $CONFIRM =~ ^[Yy]$ ]]; then
      if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE="docker-compose"
      else
        DOCKER_COMPOSE="docker compose"
      fi
      $DOCKER_COMPOSE down -v
      echo -e "${GREEN}MeowCoin Platform uninstalled and all data removed.${NC}"
    else
      echo -e "${YELLOW}Uninstall cancelled.${NC}"
    fi
    ;;
  help)
    show_help
    ;;
  *)
    show_help
    exit 1
    ;;
esac

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}   MeowCoin Platform Installer        ${NC}"
echo -e "${BLUE}   Version: ${SCRIPT_VERSION}         ${NC}"
echo -e "${BLUE}=======================================${NC}"

# Display welcome message
cat << "EOF"
  __  __                 _____      _       _____  _       _    __                     
 |  \/  |               / ____|    (_)     |  __ \| |     | |  / _|                    
 | \  / | ___  _____  _| |     ___  _ _ __ | |__) | | __ _| |_| |_ ___  _ __ _ __ ___  
 | |\/| |/ _ \/ _ \ \/ / |    / _ \| | '_ \|  ___/| |/ _` | __|  _/ _ \| '__| '_ ` _ \ 
 | |  | |  __/ (_) >  <| |___| (_) | | | | | |    | | (_| | |_| || (_) | |  | | | | |
 |_|  |_|\___|\___/_/\_\\_____\___/|_|_| |_|_|    |_|\__,_|\__|_| \___/|_|  |_| |_| |_|
                                                                                       
EOF

echo -e "${GREEN}Thank you for using MeowCoin Platform!${NC}"
echo -e "${YELLOW}Open your browser and navigate to http://localhost:3000 to complete setup.${NC}"

get_latest_meowcoin_url() {
  local os="$1"
  local pattern
  if [[ "$os" == "linux" ]]; then
    pattern="x86_64-linux-gnu.tar.gz"
  elif [[ "$os" == "darwin" ]]; then
    pattern="osx64.tar.gz"
  else
    echo "Unsupported OS: $os"
    return 1
  fi
  local api_url="https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/latest"
  curl -s "$api_url" | jq -r ".assets[] | select(.name | test(\"$pattern\")) | .browser_download_url"
}
