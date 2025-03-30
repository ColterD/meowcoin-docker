#!/bin/bash

# Load helper functions
source /scripts/functions.sh

# Set exit status
EXIT_STATUS=0

# Check if meowcoind process is running
if ! pgrep -x "meowcoind" > /dev/null; then
    log_error "Meowcoin daemon is not running"
    EXIT_STATUS=1
fi

# Check if the backend server is running
if ! pgrep -f "node.*dist/index.js" > /dev/null; then
    log_warn "Backend server is not running"
    # Don't fail health check for backend - it's not critical
fi

# Try to get blockchain info (if daemon is running)
if [ $EXIT_STATUS -eq 0 ]; then
    if ! gosu meowcoin meowcoin-cli -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" getblockchaininfo &>/dev/null; then
        log_error "Meowcoin RPC is not responding"
        EXIT_STATUS=1
    fi
fi

# Check system resources
# Basic disk space check
if [ -d "$MEOWCOIN_DATA" ]; then
    DISK_USAGE=$(df -h "$MEOWCOIN_DATA" | awk 'NR==2 {print $5}' | tr -d '%')
    if [ "$DISK_USAGE" -gt 90 ]; then
        log_warn "Disk usage is high: ${DISK_USAGE}%"
        # Don't fail health check for high disk usage - just warn
    fi
fi

# Basic memory check
MEM_USAGE=$(free -m | awk 'NR==2 {print int($3*100/$2)}')
if [ "$MEM_USAGE" -gt 95 ]; then
    log_warn "Memory usage is high: ${MEM_USAGE}%"
    # Don't fail health check for high memory usage - just warn
fi

# Return appropriate status
exit $EXIT_STATUS