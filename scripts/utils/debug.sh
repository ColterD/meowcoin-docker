#!/bin/bash
# scripts/utils/debug.sh
# Debug utilities for Meowcoin Docker

# Source utilities
source /usr/local/bin/core/utils.sh
source /usr/local/bin/core/logging.sh

# Usage function
function usage() {
    echo "Usage: $0 {enable|disable|status|dump}"
    exit 1
}

# Parse arguments
if [ $# -lt 1 ]; then
    usage
fi

# Handle commands
case "$1" in
    enable)
        toggle_debug_mode
        echo "Debug mode enabled"
        ;;
    disable)
        export DEBUG_MODE=false
        echo "Debug mode disabled"
        ;;
    status)
        if [ "$(get_debug_status)" = "true" ]; then
            echo "Debug mode is currently ENABLED"
        else
            echo "Debug mode is currently DISABLED"
        fi
        ;;
    dump)
        echo "Generating debug dump..."
        DUMP_DIR="/tmp/meowcoin-debug-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$DUMP_DIR"
        
        # System info
        echo "Collecting system information..."
        uname -a > "$DUMP_DIR/system-info.txt"
        free -m > "$DUMP_DIR/memory-info.txt"
        df -h > "$DUMP_DIR/disk-info.txt"
        ps aux > "$DUMP_DIR/processes.txt"
        
        # Meowcoin specific info
        echo "Collecting Meowcoin information..."
        if pgrep -x "meowcoind" > /dev/null; then
            meowcoin-cli getnetworkinfo > "$DUMP_DIR/network-info.json" 2>/dev/null || echo "Failed to get network info" > "$DUMP_DIR/network-info.error"
            meowcoin-cli getblockchaininfo > "$DUMP_DIR/blockchain-info.json" 2>/dev/null || echo "Failed to get blockchain info" > "$DUMP_DIR/blockchain-info.error"
            meowcoin-cli getmempoolinfo > "$DUMP_DIR/mempool-info.json" 2>/dev/null || echo "Failed to get mempool info" > "$DUMP_DIR/mempool-info.error"
        else
            echo "Meowcoin daemon is not running" > "$DUMP_DIR/daemon-status.txt"
        fi
        
        # Configuration files
        echo "Collecting configuration files..."
        cp /home/meowcoin/.meowcoin/meowcoin.conf "$DUMP_DIR/meowcoin.conf" 2>/dev/null || echo "Failed to copy meowcoin.conf" > "$DUMP_DIR/config-files.error"
        
        # Log files
        echo "Collecting log files..."
        cp /var/log/meowcoin/meowcoin.log "$DUMP_DIR/meowcoin.log" 2>/dev/null || echo "Failed to copy meowcoin.log" > "$DUMP_DIR/log-files.error"
        
        # Compress dump
        DUMP_FILE="$DUMP_DIR.tar.gz"
        tar -czf "$DUMP_FILE" -C "$(dirname "$DUMP_DIR")" "$(basename "$DUMP_DIR")"
        rm -rf "$DUMP_DIR"
        
        echo "Debug dump created: $DUMP_FILE"
        ;;
    *)
        usage
        ;;
esac

exit 0