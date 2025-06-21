#!/bin/bash
set -e

# Default to UID 1000 if not set, allows for override via environment variables
MEOWCOIN_UID=${MEOWCOIN_UID:-1000}
MEOWCOIN_HOME="/home/meowcoin"
MEOWCOIN_DATA_DIR="${MEOWCOIN_HOME}/.meowcoin"
CREDENTIALS_FILE="${MEOWCOIN_DATA_DIR}/.credentials"
CONFIG_FILE="${MEOWCOIN_DATA_DIR}/meowcoin.conf"

# If the first argument is not 'meowcoind', assume it's a meowcoin-cli command
if [ "$1" != "meowcoind" ]; then
  # Ensure the user has access to the data dir for cli commands
  exec gosu meowcoin meowcoin-cli -datadir="${MEOWCOIN_DATA_DIR}" "$@"
fi

# --- Initial Setup ---
# Create the data directory and ensure permissions are correct on every start.
# This covers all necessary files and subdirectories.
mkdir -p "${MEOWCOIN_DATA_DIR}"
chown -R meowcoin:meowcoin "${MEOWCOIN_HOME}"

# --- Credential Management ---
# Generate RPC credentials only if they don't exist.
if [ ! -f "$CREDENTIALS_FILE" ]; then
  echo "🔑 First run: Generating new random RPC credentials..."
  RPC_USER="meow-$(openssl rand -hex 4)"
  RPC_PASSWORD=$(openssl rand -hex 32)
  
  echo "RPC_USER=${RPC_USER}" > "$CREDENTIALS_FILE"
  echo "RPC_PASSWORD=${RPC_PASSWORD}" >> "$CREDENTIALS_FILE"
  chmod 600 "$CREDENTIALS_FILE"
  echo "✅ Credentials generated and secured."
fi

# Load credentials from the file
source "$CREDENTIALS_FILE"

# --- Configuration File Generation ---
# Source the environment variables with defaults.
: "${MEOWCOIN_RPC_PORT:=9766}"
: "${MEOWCOIN_P2P_PORT:=8788}"
: "${MEOWCOIN_MAX_CONNECTIONS:=100}"
: "${MEOWCOIN_DB_CACHE:=1024}"
: "${MEOWCOIN_MAX_MEMPOOL:=300}"
: "${MEOWCOIN_TXINDEX:=1}"
: "${MEOWCOIN_MEOWPOW:=1}"
: "${MEOWCOIN_BANTIME:=86400}"

echo "⚙️  Generating meowcoin.conf..."

# Use a heredoc to create the config file cleanly.
# This is simpler and more readable than using sed/envsubst.
cat > "${CONFIG_FILE}" <<EOF
# RPC settings
rpcuser=${RPC_USER}
rpcpassword=${RPC_PASSWORD}
rpcallowip=::/0
rpcport=${MEOWCOIN_RPC_PORT}

# P2P settings
port=${MEOWCOIN_P2P_PORT}
maxconnections=${MEOWCOIN_MAX_CONNECTIONS}
bantime=${MEOWCOIN_BANTIME}

# Performance settings
dbcache=${MEOWCOIN_DB_CACHE}
maxmempool=${MEOWCOIN_MAX_MEMPOOL}

# Feature settings
txindex=${MEOWCOIN_TXINDEX}
meowpow=${MEOWCOIN_MEOWPOW}
EOF

# Set secure permissions for the config file
chmod 600 "${CONFIG_FILE}"

# Write version file if it doesn't exist
if [ ! -f "${MEOWCOIN_DATA_DIR}/VERSION" ]; then
  INSTALLED_VERSION=$(meowcoind --version | head -n1)
  echo "${INSTALLED_VERSION}" > "${MEOWCOIN_DATA_DIR}/VERSION"
  echo "📌 Version: ${INSTALLED_VERSION}"
fi

echo "🚀 Starting Meowcoin daemon..."

# Start the daemon as the non-root user
exec gosu meowcoin "$@"
