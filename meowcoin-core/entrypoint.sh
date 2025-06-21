#!/bin/bash
set -euo pipefail

# Signal handling for graceful shutdown
cleanup() {
    log_info "Received shutdown signal, stopping Meowcoin daemon gracefully..."
    if [ -n "${MEOWCOIN_PID:-}" ]; then
        kill -TERM "$MEOWCOIN_PID" 2>/dev/null || true
        wait "$MEOWCOIN_PID" 2>/dev/null || true
    fi
    log_info "Shutdown complete"
    exit 0
}

trap cleanup SIGTERM SIGINT

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

# Simple logging functions that output to both console and file
log_info() {
    echo "[INFO] $*"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" >> /tmp/meowcoin-core.log
}

log_success() {
    echo "[SUCCESS] $*"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $*" >> /tmp/meowcoin-core.log
}

log_warning() {
    echo "[WARNING] $*" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $*" >> /tmp/meowcoin-core.log
}

log_error() {
    echo "[ERROR] $*" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" >> /tmp/meowcoin-core.log
}

# Start with a clear log file
echo "=== Meowcoin Core Log Started at $(date) ===" > /tmp/meowcoin-core.log

log_info "Meowcoin Core container starting..."
log_info "Arguments: $*"

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

# Validate that required binaries exist and are executable
validate_binaries() {
    local binaries=("meowcoind" "meowcoin-cli")
    for binary in "${binaries[@]}"; do
        if ! command -v "$binary" >/dev/null 2>&1; then
            log_error "Required binary '$binary' not found in PATH"
            return 1
        fi
        if ! [ -x "$(command -v "$binary")" ]; then
            log_error "Binary '$binary' is not executable"
            return 1
        fi
    done
    log_success "All required binaries are present and executable"
    return 0
}

# If the first argument is not 'meowcoind', assume it's a meowcoin-cli command
if [ "$1" != "meowcoind" ]; then
    log_info "Running CLI command: $*"
    # Validate binaries before attempting to run CLI commands
    if ! validate_binaries; then
        log_error "Binary validation failed, cannot execute command"
        exit 1
    fi
    log_info "Executing: gosu meowcoin meowcoin-cli -datadir=${MEOWCOIN_DATA_DIR} $*"
    exec gosu meowcoin meowcoin-cli -datadir="${MEOWCOIN_DATA_DIR}" "$@"
fi

log_info "Starting meowcoin daemon setup..."

# --- Initial Setup ---
log_info "Creating data directory: ${MEOWCOIN_DATA_DIR}"
# Create the data directory
if mkdir -p "${MEOWCOIN_DATA_DIR}"; then
    log_info "Data directory created successfully"
else
    log_warning "Could not create data directory. If using a read-only filesystem, this is expected."
fi

# Check if we're in a read-only filesystem
log_info "Checking filesystem permissions..."
if touch "${MEOWCOIN_HOME}/.test_write" 2>/dev/null; then
    rm -f "${MEOWCOIN_HOME}/.test_write"
    log_info "Filesystem is writable, checking ownership..."
    
    # Get current ownership info safely
    if CURRENT_UID=$(stat -c '%u' "${MEOWCOIN_DATA_DIR}" 2>/dev/null) && MEOWCOIN_UID=$(id -u meowcoin 2>/dev/null); then
        log_info "Current directory owner UID: $CURRENT_UID, meowcoin UID: $MEOWCOIN_UID"
        if [ "$CURRENT_UID" != "$MEOWCOIN_UID" ]; then
            log_info "Fixing ownership of data directory..."
            if chown -R meowcoin:meowcoin "${MEOWCOIN_HOME}"; then
                log_info "Ownership fixed successfully"
            else
                log_warning "Could not change ownership. Continuing anyway."
            fi
        else
            log_info "Ownership is already correct"
        fi
    else
        log_warning "Could not check ownership (stat or id command failed). Continuing anyway."
    fi
    log_info "Ownership check completed"
else
    log_info "Read-only filesystem detected, skipping ownership check"
fi

# --- Credential Management ---
log_info "Managing RPC credentials..."
# Generate RPC credentials only if they don't exist
if [ ! -f "$CREDENTIALS_FILE" ]; then
    log_info "First run: Generating new random RPC credentials..."
    RPC_USER="meow-$(generate_random 8)"
    RPC_PASSWORD=$(generate_random 32)
    
    echo "RPC_USER=${RPC_USER}" > "$CREDENTIALS_FILE"
    echo "RPC_PASSWORD=${RPC_PASSWORD}" >> "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE"
    log_success "Credentials generated and secured."
else
    log_info "Using existing RPC credentials"
fi

# Load credentials securely from the file without executing it
log_info "Loading RPC credentials..."
RPC_USER=$(grep '^RPC_USER=' "$CREDENTIALS_FILE" | cut -d'=' -f2-)
RPC_PASSWORD=$(grep '^RPC_PASSWORD=' "$CREDENTIALS_FILE" | cut -d'=' -f2-)

# Validate that credentials were loaded properly
if [ -z "$RPC_USER" ] || [ -z "$RPC_PASSWORD" ]; then
    log_error "Failed to load RPC credentials from $CREDENTIALS_FILE"
    log_error "RPC_USER: '${RPC_USER:-empty}', RPC_PASSWORD: '${RPC_PASSWORD:+[set]}${RPC_PASSWORD:-empty}'"
    exit 1
else
    log_info "Credentials loaded successfully (user: $RPC_USER)"
fi

# --- Configuration File Generation ---
log_info "Checking configuration file..."
if [ ! -f "${CONFIG_FILE}" ]; then
    log_info "No custom meowcoin.conf found. Generating a default one..."

    # Calculate optimal settings based on system resources
    log_info "Calculating optimal settings..."
    eval "$(calculate_optimal_settings)"
    log_info "Optimal settings calculated"
    
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
# Bind to all interfaces for P2P, but RPC is restricted by rpcallowip
bind=0.0.0.0
# Only bind RPC to localhost and Docker networks for security
rpcbind=127.0.0.1
rpcbind=0.0.0.0
dnsseed=1
upnp=0

# Logging settings
logtimestamps=1
logips=1
shrinkdebugfile=1
EOF
    fi

    # Set secure permissions for the config file
    if chmod 600 "${CONFIG_FILE}"; then
        log_success "Configuration file generated with optimized settings."
    else
        log_error "Failed to set permissions on configuration file"
        exit 1
    fi
else
    log_info "Custom meowcoin.conf found. Using existing configuration."
fi

# Write version file if it doesn't exist
if [ ! -f "${MEOWCOIN_DATA_DIR}/VERSION" ]; then
    log_info "Getting meowcoind version..."
    if INSTALLED_VERSION=$(meowcoind --version | head -n1); then
        echo "${INSTALLED_VERSION}" > "${MEOWCOIN_DATA_DIR}/VERSION"
        log_info "Version: ${INSTALLED_VERSION}"
    else
        log_error "Failed to get meowcoind version - binary may be corrupted"
        exit 1
    fi
fi

# Validate binaries before starting daemon
log_info "Validating meowcoin binaries..."
if ! validate_binaries; then
    log_error "Binary validation failed, cannot start daemon"
    exit 1
fi
log_info "Binary validation successful"

log_info "Starting Meowcoin daemon with command: $*"
log_info "Switching to meowcoin user and executing daemon..."

# Start the daemon as the non-root user
exec gosu meowcoin "$@"
