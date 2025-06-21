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
MEOWCOIN_RPC_PORT=${MEOWCOIN_RPC_PORT:-9766}
MONITOR_INTERVAL=${MONITOR_INTERVAL:-60}
CREDENTIALS_FILE="/data/.credentials"
DEBUG=${DEBUG:-1}

# Print debug information
if [ "$DEBUG" = "1" ]; then
    log_info "Network debug information:"
    echo "Hostname: $(hostname)"
    echo "IP addresses:"
    ip addr show
    echo "Hosts file:"
    cat /etc/hosts
    echo "DNS resolution:"
    cat /etc/resolv.conf
    echo "Trying to resolve meowcoin-core:"
    getent hosts meowcoin-core || echo "Failed to resolve meowcoin-core"
    echo "Trying to resolve meowcoin-node:"
    getent hosts meowcoin-node || echo "Failed to resolve meowcoin-node"
    echo "Trying to ping meowcoin-core:"
    ping -c 2 meowcoin-core || echo "Failed to ping meowcoin-core"
    echo "Trying to ping meowcoin-node:"
    ping -c 2 meowcoin-node || echo "Failed to ping meowcoin-node"
fi

log_info "Meowcoin Monitor Starting..."

# Main monitoring loop
while true; do
    echo ""
    echo "===================="
    echo "📊 Meowcoin Status"
    echo "⏰ $(date)"
    echo "===================="
    
    # Try to connect to the RPC server
    if nc -z meowcoin-core "${MEOWCOIN_RPC_PORT}" -w 5 || nc -z meowcoin-node "${MEOWCOIN_RPC_PORT}" -w 5 || nc -z localhost "${MEOWCOIN_RPC_PORT}" -w 5 || nc -z 127.0.0.1 "${MEOWCOIN_RPC_PORT}" -w 5; then
        log_success "RPC Server: ONLINE (port is open)"
    else
        log_warning "RPC Server: OFFLINE or UNREACHABLE"
    fi
    
    # Show disk usage of the data directory
    if [ -d /data ]; then
        SIZE=$(du -sh /data 2>/dev/null | cut -f1)
        echo "💾 Data Size:    ${SIZE}"
        
        # Show file count in the data directory
        FILES=$(find /data -type f 2>/dev/null | wc -l)
        echo "📁 Files:        ${FILES}"
    fi
    
    echo "===================="
    sleep "${MONITOR_INTERVAL}"
done