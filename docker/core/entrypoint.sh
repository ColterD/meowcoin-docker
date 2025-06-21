#!/bin/bash
set -euo pipefail

# Source common functions
source /usr/local/bin/common.sh

# Constants
MEOWCOIN_HOME="/home/meowcoin"
MEOWCOIN_DATA_DIR="${MEOWCOIN_HOME}/.meowcoin"
CREDENTIALS_FILE="${MEOWCOIN_DATA_DIR}/.credentials"
CONFIG_FILE="${MEOWCOIN_DATA_DIR}/meowcoin.conf"
CONFIG_TEMPLATE="/etc/meowcoin/meowcoin.conf.template"

# Function to generate secure credentials
generate_credentials() {
    log_info "Generating new random RPC credentials..."
    
    # Generate secure random credentials
    local rpc_user="meow-$(generate_random_string 8)"
    local rpc_password=$(generate_random_string 32)
    
    # Save credentials to file with secure permissions
    echo "RPC_USER=${rpc_user}" > "$CREDENTIALS_FILE"
    echo "RPC_PASSWORD=${rpc_password}" >> "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE"
    
    log_success "Credentials generated and secured."
}

# Function to create default configuration
create_default_config() {
    log_info "Generating default configuration..."
    
    # Load credentials
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CREDENTIALS_FILE"
    else
        log_error "Credentials file not found. This should not happen."
        exit 1
    fi
    
    # Calculate optimal settings based on system resources
    local optimal_dbcache=$(calculate_optimal_dbcache)
    local optimal_maxmempool=$(calculate_optimal_maxmempool)
    local optimal_maxconnections=$(calculate_optimal_maxconnections)
    
    # Set environment variables with defaults for template
    export MEOWCOIN_RPC_USER="${RPC_USER}"
    export MEOWCOIN_RPC_PASSWORD="${RPC_PASSWORD}"
    export MEOWCOIN_RPC_PORT="${MEOWCOIN_RPC_PORT:-9766}"
    export MEOWCOIN_P2P_PORT="${MEOWCOIN_P2P_PORT:-8788}"
    export MEOWCOIN_MAX_CONNECTIONS="${MEOWCOIN_MAX_CONNECTIONS:-$optimal_maxconnections}"
    export MEOWCOIN_DB_CACHE="${MEOWCOIN_DB_CACHE:-$optimal_dbcache}"
    export MEOWCOIN_MAX_MEMPOOL="${MEOWCOIN_MAX_MEMPOOL:-$optimal_maxmempool}"
    export MEOWCOIN_TXINDEX="${MEOWCOIN_TXINDEX:-1}"
    export MEOWCOIN_MEOWPOW="${MEOWCOIN_MEOWPOW:-1}"
    export MEOWCOIN_BANTIME="${MEOWCOIN_BANTIME:-86400}"
    
    # Process template
    envsubst < "$CONFIG_TEMPLATE" > "$CONFIG_FILE"
    
    # Set secure permissions
    chmod 600 "$CONFIG_FILE"
    
    log_success "Configuration generated."
}

# Function to ensure correct permissions
ensure_permissions() {
    # Create data directory if it doesn't exist
    mkdir -p "${MEOWCOIN_DATA_DIR}"
    
    # Check if ownership is correct
    if [[ "$(stat -c '%u:%g' "${MEOWCOIN_DATA_DIR}")" != "$(id -u meowcoin):$(id -g meowcoin)" ]]; then
        log_info "Fixing permissions on data directory..."
        chown -R meowcoin:meowcoin "${MEOWCOIN_HOME}"
    fi
}

# Function to write version file
write_version_file() {
    if [[ ! -f "${MEOWCOIN_DATA_DIR}/VERSION" ]]; then
        local installed_version
        installed_version=$(meowcoind --version | head -n1)
        echo "${installed_version}" > "${MEOWCOIN_DATA_DIR}/VERSION"
        log_info "Version: ${installed_version}"
    fi
}

# Main entrypoint logic
main() {
    # Ensure we're running as root initially for setup
    if [[ "$(id -u)" != "0" ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    # Initial setup
    ensure_permissions
    
    # Generate credentials if they don't exist
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        generate_credentials
    fi
    
    # Create default config if it doesn't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        create_default_config
    else
        log_info "Custom meowcoin.conf found. Skipping generation."
    fi
    
    # Write version file
    write_version_file
    
    # If the first argument is not 'meowcoind', assume it's a meowcoin-cli command
    if [[ "$1" != "meowcoind" ]]; then
        log_info "Running command: $*"
        exec gosu meowcoin meowcoin-cli -datadir="${MEOWCOIN_DATA_DIR}" "$@"
    else
        log_info "Starting Meowcoin daemon..."
        # Start the daemon as the non-root user
        exec gosu meowcoin "$@"
    fi
}

# Run the main function
main "$@"