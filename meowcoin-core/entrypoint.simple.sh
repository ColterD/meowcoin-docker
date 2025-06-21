#!/bin/bash
set -e

# Function to log messages
log_info() {
    echo "[INFO] $*"
}

log_success() {
    echo "[SUCCESS] $*"
}

log_warning() {
    echo "[WARNING] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

# Configuration
MEOWCOIN_HOME="/home/meowcoin"
MEOWCOIN_DATA_DIR="${MEOWCOIN_HOME}/.meowcoin"
MEOWCOIN_CONFIG="${MEOWCOIN_DATA_DIR}/meowcoin.conf"
CREDENTIALS_FILE="${MEOWCOIN_DATA_DIR}/.credentials"

# Create the data directory
mkdir -p "${MEOWCOIN_DATA_DIR}"

# Generate RPC credentials if they don't exist
if [ ! -f "${CREDENTIALS_FILE}" ]; then
    log_info "Generating RPC credentials..."
    RPC_USER="meowcoinrpc"
    RPC_PASSWORD=$(openssl rand -hex 32)
    
    # Save credentials to file
    echo "RPC_USER=${RPC_USER}" > "${CREDENTIALS_FILE}"
    echo "RPC_PASSWORD=${RPC_PASSWORD}" >> "${CREDENTIALS_FILE}"
    
    # Make sure only meowcoin user can read the credentials
    chmod 600 "${CREDENTIALS_FILE}"
fi

# Load RPC credentials
source "${CREDENTIALS_FILE}"

# Create meowcoin.conf if it doesn't exist
if [ ! -f "${MEOWCOIN_CONFIG}" ]; then
    log_info "Creating meowcoin.conf..."
    
    # Basic configuration
    cat > "${MEOWCOIN_CONFIG}" << EOF
# Meowcoin Core configuration
rpcuser=${RPC_USER}
rpcpassword=${RPC_PASSWORD}
rpcport=${MEOWCOIN_RPC_PORT:-9766}
rpcbind=0.0.0.0
rpcallowip=0.0.0.0/0
server=1
daemon=0
txindex=${MEOWCOIN_TXINDEX:-1}
meowpow=${MEOWCOIN_MEOWPOW:-1}
maxconnections=${MEOWCOIN_MAX_CONNECTIONS:-100}
dbcache=${MEOWCOIN_DB_CACHE:-1024}
maxmempool=${MEOWCOIN_MAX_MEMPOOL:-300}
bantime=${MEOWCOIN_BANTIME:-86400}
EOF
    
    # Make sure only meowcoin user can read the config
    chmod 600 "${MEOWCOIN_CONFIG}"
fi

# Fix ownership
chown -R meowcoin:meowcoin "${MEOWCOIN_DATA_DIR}" || log_warning "Could not change ownership. Continuing anyway."

# Handle command
if [ "$1" = "meowcoind" ]; then
    log_info "Starting Meowcoin Core..."
    exec gosu meowcoin meowcoind -datadir="${MEOWCOIN_DATA_DIR}"
elif [ "$1" = "getblockchaininfo" ]; then
    # For healthcheck
    exec gosu meowcoin meowcoin-cli -datadir="${MEOWCOIN_DATA_DIR}" getblockchaininfo
else
    # Pass other commands to meowcoin-cli
    exec gosu meowcoin meowcoin-cli -datadir="${MEOWCOIN_DATA_DIR}" "$@"
fi