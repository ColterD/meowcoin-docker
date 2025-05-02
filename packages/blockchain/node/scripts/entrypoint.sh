#!/bin/bash
set -e

# Create meowcoin.conf if it doesn't exist
if [ ! -f "${MEOWCOIN_CONFIG}/meowcoin.conf" ]; then
  echo "Creating default meowcoin.conf..."
  cat > ${MEOWCOIN_CONFIG}/meowcoin.conf << EOF
# MeowCoin Configuration File

# Network
server=1
listen=1
port=9333
rpcport=9332

# RPC Settings
rpcuser=${MEOWCOIN_RPC_USER:-meowcoinuser}
rpcpassword=${MEOWCOIN_RPC_PASSWORD:-$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 32)}
rpcallowip=0.0.0.0/0
rpcbind=0.0.0.0

# Performance
dbcache=512
maxmempool=300
maxconnections=125
maxuploadtarget=1000

# Indexes
txindex=1
addressindex=1

# Logging
debug=0
printtoconsole=1
logtimestamps=1

# Misc
daemon=0
disablewallet=0
zmqpubhashblock=tcp://0.0.0.0:28332
zmqpubhashtx=tcp://0.0.0.0:28333
EOF
fi

# Make sure permissions are correct
chmod 600 ${MEOWCOIN_CONFIG}/meowcoin.conf
chown -R root:root ${MEOWCOIN_DATA}
chown -R root:root ${MEOWCOIN_CONFIG}

# Print startup message
echo "Starting MeowCoin Node..."
echo "Version: $(meowcoind --version | head -n 1)"
echo "Configuration: ${MEOWCOIN_CONFIG}/meowcoin.conf"
echo "Data directory: ${MEOWCOIN_DATA}"

# Execute command
exec "$@"