#!/bin/bash
set -e

# Configuration file
CONFIG_FILE="/home/meowcoin/.meowcoin/meowcoin.conf"
TEMPLATE_FILE="/home/meowcoin/.meowcoin/meowcoin.conf.template"

# Generate random credentials if not provided
if [ -z "$RPC_USER" ]; then
  export RPC_USER="meowcoin"
  echo "Warning: No RPC user specified, using default: meowcoin"
fi

if [ -z "$RPC_PASSWORD" ]; then
  export RPC_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)
  echo "Generated RPC password: $RPC_PASSWORD"
  echo "WARNING: Store this password securely. It won't be displayed again."
fi

# Validate RPC settings
if [ "$RPC_BIND" = "0.0.0.0" ] && [ "$RPC_ALLOWIP" = "0.0.0.0/0" ]; then
  echo "WARNING: Your RPC is configured to accept connections from any IP."
  echo "This is a significant security risk for production environments."
fi

# Additional options
export CUSTOM_OPTS=${MEOWCOIN_OPTS:-""}

# Create config from template
envsubst < "$TEMPLATE_FILE" > "$CONFIG_FILE"
echo "Configuration generated in $CONFIG_FILE"

# First argument is command to run
if [ "${1:0:1}" = '-' ]; then
  # If first arg is a flag, prepend meowcoind
  set -- meowcoind "$@"
fi

echo "Starting Meowcoin node..."
# Execute command
exec "$@"