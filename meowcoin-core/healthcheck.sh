#!/bin/bash
set -euo pipefail

# Simple healthcheck script for Meowcoin Core
# This script checks if the node is responsive by querying blockchain info

MEOWCOIN_DATA_DIR="/home/meowcoin/.meowcoin"

# Execute getblockchaininfo command
if gosu meowcoin meowcoin-cli -datadir="${MEOWCOIN_DATA_DIR}" getblockchaininfo > /dev/null 2>&1; then
    echo "Meowcoin node is healthy"
    exit 0
else
    echo "Meowcoin node is not responding"
    exit 1
fi