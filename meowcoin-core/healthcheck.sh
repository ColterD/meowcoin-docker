#!/bin/bash
# Health check script for meowcoin-core
# Progressive health check: process -> port -> RPC (if credentials exist)

# Check if meowcoind process is running
if ! pgrep meowcoind > /dev/null 2>&1; then
    echo "meowcoind process not running"
    exit 1
fi

# Check if RPC port is listening
if ! nc -z localhost 9766 2>/dev/null; then
    echo "RPC port not listening"
    exit 1
fi

# If credentials exist, try RPC call, otherwise just pass
CREDENTIALS_FILE="/home/meowcoin/.meowcoin/.credentials"
if [ -f "$CREDENTIALS_FILE" ]; then
    # Try using the entrypoint script which handles auth automatically
    if ! timeout 10 /entrypoint.sh getblockcount > /dev/null 2>&1; then
        echo "RPC not responding to requests"
        exit 1
    fi
fi

echo "Health check passed"
exit 0