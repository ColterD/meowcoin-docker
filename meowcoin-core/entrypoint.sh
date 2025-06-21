#!/bin/bash
set -euo pipefail

# Constants
MEOWCOIN_HOME="/home/meowcoin"
MEOWCOIN_DATA_DIR="${MEOWCOIN_HOME}/.meowcoin"
CREDENTIALS_FILE="${MEOWCOIN_DATA_DIR}/.credentials"
CONFIG_FILE="${MEOWCOIN_DATA_DIR}/meowcoin.conf"

# Function to generate secure random string
generate_random() {
    local length=$1
    openssl rand -hex $((length/2))
}

# Function to log messages with colors
log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $*"
}

log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $*"
}

log_warning() {
    echo -e "\033[0;33m[WARNING]\033[0m $*" >&2
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $*" >&2
}

# Function to calculate optimal settings based on system resources
calculate_optimal_settings() {
    # Get available memory in MB
    local mem_total
    if [ -f /proc/meminfo ]; then
        mem_total=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
    else
        # Default to 4GB if we can't determine
        mem_total=4096
    fi
    
    # Get number of CPU cores
    local cpu_cores
    if [ -f /proc/cpuinfo ]; then
        cpu_cores=$(grep -c ^processor /proc/cpuinfo)
    else
        # Default to 2 if we can't determine
        cpu_cores=2
    fi
    
    # Calculate optimal dbcache (25% of RAM, min 128MB, max 4GB)
    local dbcache=$((mem_total / 4))
    if [ $dbcache -lt 128 ]; then
        dbcache=128
    elif [ $dbcache -gt 4096 ]; then
        dbcache=4096
    fi
    
    # Calculate optimal maxmempool (10% of RAM, min 50MB, max 1GB)
    local maxmempool=$((mem_total / 10))
    if [ $maxmempool -lt 50 ]; then
        maxmempool=50
    elif [ $maxmempool -gt 1000 ]; then
        maxmempool=1000
    fi
    
    # Calculate optimal maxconnections (based on CPU cores and RAM)
    local maxconnections=$((cpu_cores * 10))
    if [ $mem_total -lt 1024 ]; then
        # Less than 1GB RAM
        maxconnections=$((maxconnections / 2))
    elif [ $mem_total -gt 8192 ]; then
        # More than 8GB RAM
        maxconnections=$((maxconnections * 2))
    fi
    
    # Minimum 10, maximum 125
    if [ $maxconnections -lt 10 ]; then
        maxconnections=10
    elif [ $maxconnections -gt 125 ]; then
        maxconnections=125
    fi
    
    # Return calculated values
    echo "OPTIMAL_DBCACHE=$dbcache"
    echo "OPTIMAL_MAXMEMPOOL=$maxmempool"
    echo "OPTIMAL_MAXCONNECTIONS=$maxconnections"
}

# If the first argument is not 'meowcoind', assume it's a meowcoin-cli command
if [ "$1" != "meowcoind" ]; then
    log_info "Running command: $*"
    exec gosu meowcoin meowcoin-cli -datadir="${MEOWCOIN_DATA_DIR}" "$@"
fi

# --- Initial Setup ---
# Create the data directory
mkdir -p "${MEOWCOIN_DATA_DIR}" || log_warning "Could not create data directory. If using a read-only filesystem, this is expected."

# Check if we're in a read-only filesystem
touch "${MEOWCOIN_HOME}/.test_write" 2>/dev/null
if [ $? -ne 0 ]; then
    log_info "Read-only filesystem detected, skipping ownership check"
else
    rm -f "${MEOWCOIN_HOME}/.test_write"
    # Check if the data directory is owned by meowcoin, if not, chown it
    if [ "$(stat -c '%u' "${MEOWCOIN_DATA_DIR}")" != "$(id -u meowcoin)" ]; then
        log_info "Fixing ownership of data directory..."
        chown -R meowcoin:meowcoin "${MEOWCOIN_HOME}" || log_warning "Could not change ownership. Continuing anyway."
    fi
fi

# --- Credential Management ---
# Generate RPC credentials only if they don't exist
if [ ! -f "$CREDENTIALS_FILE" ]; then
    log_info "First run: Generating new random RPC credentials..."
    RPC_USER="meow-$(generate_random 8)"
    RPC_PASSWORD=$(generate_random 32)
    
    echo "RPC_USER=${RPC_USER}" > "$CREDENTIALS_FILE"
    echo "RPC_PASSWORD=${RPC_PASSWORD}" >> "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE"
    log_success "Credentials generated and secured."
fi

# Load credentials securely from the file without executing it
RPC_USER=$(grep '^RPC_USER=' "$CREDENTIALS_FILE" | cut -d'=' -f2-)
RPC_PASSWORD=$(grep '^RPC_PASSWORD=' "$CREDENTIALS_FILE" | cut -d'=' -f2-)

# --- Configuration File Generation ---
if [ ! -f "${CONFIG_FILE}" ]; then
    log_info "No custom meowcoin.conf found. Generating a default one..."

    # Calculate optimal settings based on system resources
    eval "$(calculate_optimal_settings)"
    
    # Source the environment variables with defaults
    : "${MEOWCOIN_RPC_PORT:=9766}"
    : "${MEOWCOIN_P2P_PORT:=8788}"
    : "${MEOWCOIN_MAX_CONNECTIONS:=$OPTIMAL_MAXCONNECTIONS}"
    : "${MEOWCOIN_DB_CACHE:=$OPTIMAL_DBCACHE}"
    : "${MEOWCOIN_MAX_MEMPOOL:=$OPTIMAL_MAXMEMPOOL}"
    : "${MEOWCOIN_TXINDEX:=1}"
    : "${MEOWCOIN_MEOWPOW:=1}"
    : "${MEOWCOIN_BANTIME:=86400}"

    log_info "Using optimized settings:"
    log_info "- Database Cache: ${MEOWCOIN_DB_CACHE} MB"
    log_info "- Max Mempool: ${MEOWCOIN_MAX_MEMPOOL} MB"
    log_info "- Max Connections: ${MEOWCOIN_MAX_CONNECTIONS}"

    # Create environment variables for the template
    export MEOWCOIN_RPC_USER="${RPC_USER}"
    export MEOWCOIN_RPC_PASSWORD="${RPC_PASSWORD}"
    
    # Check if template exists
    if [ -f "/etc/meowcoin/meowcoin.conf.template" ]; then
        log_info "Using configuration template from /etc/meowcoin/meowcoin.conf.template"
        # Use envsubst to replace variables in the template
        envsubst < "/etc/meowcoin/meowcoin.conf.template" > "${CONFIG_FILE}"
    else
        log_info "No template found, generating config file directly"
        # Create the config file
        cat > "${CONFIG_FILE}" <<EOF
# RPC settings
rpcuser=${RPC_USER}
rpcpassword=${RPC_PASSWORD}
rpcallowip=127.0.0.1
rpcallowip=172.16.0.0/12
rpcallowip=192.168.0.0/16
rpcport=${MEOWCOIN_RPC_PORT}
rpcthreads=8
rpcworkqueue=64

# P2P settings
port=${MEOWCOIN_P2P_PORT}
maxconnections=${MEOWCOIN_MAX_CONNECTIONS}
bantime=${MEOWCOIN_BANTIME}

# Performance settings
dbcache=${MEOWCOIN_DB_CACHE}
maxmempool=${MEOWCOIN_MAX_MEMPOOL}
par=2

# Feature settings
txindex=${MEOWCOIN_TXINDEX}
meowpow=${MEOWCOIN_MEOWPOW}

# Security settings
disablewallet=1
listen=1
bind=0.0.0.0
dnsseed=1
upnp=0

# Logging settings
logtimestamps=1
logips=1
shrinkdebugfile=1
EOF
    fi

    # Set secure permissions for the config file
    chmod 600 "${CONFIG_FILE}"
    log_success "Configuration file generated with optimized settings."
else
    log_success "Custom meowcoin.conf found. Using existing configuration."
fi

# Write version file if it doesn't exist
if [ ! -f "${MEOWCOIN_DATA_DIR}/VERSION" ]; then
    INSTALLED_VERSION=$(meowcoind --version | head -n1)
    echo "${INSTALLED_VERSION}" > "${MEOWCOIN_DATA_DIR}/VERSION"
    log_info "Version: ${INSTALLED_VERSION}"
fi

log_info "Starting Meowcoin daemon..."

# Start the daemon as the non-root user
exec gosu meowcoin "$@"
