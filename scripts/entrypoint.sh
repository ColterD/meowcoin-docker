#!/bin/bash
set -e

# Configuration file
CONFIG_FILE="/home/meowcoin/.meowcoin/meowcoin.conf"
TEMPLATE_FILE="/home/meowcoin/.meowcoin/meowcoin.conf.template"

# Generate random credentials if not provided
if [ -z "$RPC_USER" ]; then
  export RPC_USER="meowcoin"
fi

if [ -z "$RPC_PASSWORD" ]; then
  export RPC_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)
  echo "Generated random RPC password: $RPC_PASSWORD"
fi

# Additional options
export CUSTOM_OPTS=${MEOWCOIN_OPTS:-""}

# Create config from template
envsubst < "$TEMPLATE_FILE" > "$CONFIG_FILE"

# First argument is command to run
if [ "${1:0:1}" = '-' ]; then
  # If first arg is a flag, prepend meowcoind
  set -- meowcoind "$@"
fi

# Execute command
exec "$@"