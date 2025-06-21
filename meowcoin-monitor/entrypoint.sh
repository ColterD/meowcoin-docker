#!/bin/bash
set -euo pipefail

# Function to log messages with colors
log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $*"
}

log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $*"
}

log_warning() {
    echo -e "\033[0;33m[WARNING]\033[0m $*" >&2
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $*" >&2
}

# Function to check if RPC server is available
check_rpc_available() {
    # Try both service name and container name
    if nc -z meowcoin-core "${MEOWCOIN_RPC_PORT}" -w 5; then
        return 0
    elif nc -z meowcoin-node "${MEOWCOIN_RPC_PORT}" -w 5; then
        return 0
    else
        return 1
    fi
}

log_info "Meowcoin Monitor Starting..."

# --- Configuration ---
MEOWCOIN_RPC_PORT=${MEOWCOIN_RPC_PORT:-9766}
MONITOR_INTERVAL=${MONITOR_INTERVAL:-60}
CREDENTIALS_FILE="/data/.credentials"

# The 'depends_on' in docker-compose handles waiting for the meowcoin-core service
# to be healthy before this container starts.

while true; do
    echo ""
    echo "===================="
    echo "📊 Meowcoin Status"
    echo "⏰ $(date)"
    echo "===================="
    
    # Check if RPC server is available
    if check_rpc_available; then
        if [ -f "$CREDENTIALS_FILE" ]; then
            # Load credentials securely without executing the file
            RPC_USER=$(grep '^RPC_USER=' "$CREDENTIALS_FILE" | cut -d'=' -f2-)
            RPC_PASSWORD=$(grep '^RPC_PASSWORD=' "$CREDENTIALS_FILE" | cut -d'=' -f2-)
            
            # Perform a full, authenticated health check
            JSON_RPC='{"jsonrpc":"1.0","id":"monitor","method":"getblockchaininfo","params":[]}'
            
            # Try both service name and container name
            RESPONSE=$(curl -s --fail --user "${RPC_USER}:${RPC_PASSWORD}" --data-binary "${JSON_RPC}" "http://meowcoin-core:${MEOWCOIN_RPC_PORT}" 2>/dev/null)
            
            if [ $? -ne 0 ]; then
                # Try with container name if service name fails
                RESPONSE=$(curl -s --fail --user "${RPC_USER}:${RPC_PASSWORD}" --data-binary "${JSON_RPC}" "http://meowcoin-node:${MEOWCOIN_RPC_PORT}" 2>/dev/null)
            fi

            if [ $? -eq 0 ] && echo "${RESPONSE}" | jq -e '.error == null' >/dev/null; then
                BLOCKS=$(echo "${RESPONSE}" | jq '.result.blocks')
                HEADERS=$(echo "${RESPONSE}" | jq '.result.headers')
                DIFFICULTY=$(echo "${RESPONSE}" | jq '.result.difficulty')
                SYNC_PROGRESS=$(echo "${RESPONSE}" | jq '.result.verificationprogress')
                SYNC_PERCENT=$(echo "${SYNC_PROGRESS} * 100" | bc -l | awk '{printf "%.2f", $0}')
                
                # Get network info for connections
                NETWORK_JSON_RPC='{"jsonrpc":"1.0","id":"monitor","method":"getnetworkinfo","params":[]}'
                
                # Try both service name and container name
                NETWORK_RESPONSE=$(curl -s --fail --user "${RPC_USER}:${RPC_PASSWORD}" --data-binary "${NETWORK_JSON_RPC}" "http://meowcoin-core:${MEOWCOIN_RPC_PORT}" 2>/dev/null)
                
                if [ $? -ne 0 ]; then
                    # Try with container name if service name fails
                    NETWORK_RESPONSE=$(curl -s --fail --user "${RPC_USER}:${RPC_PASSWORD}" --data-binary "${NETWORK_JSON_RPC}" "http://meowcoin-node:${MEOWCOIN_RPC_PORT}" 2>/dev/null)
                fi
                
                if [ $? -eq 0 ] && echo "${NETWORK_RESPONSE}" | jq -e '.error == null' >/dev/null; then
                    CONNECTIONS=$(echo "${NETWORK_RESPONSE}" | jq '.result.connections')
                else
                    CONNECTIONS="N/A"
                fi
                
                log_success "RPC Server:   ONLINE"
                echo "📦 Version:      $(cat /data/VERSION 2>/dev/null || echo "Unknown")"
                echo "🔗 Blocks:       ${BLOCKS}"
                echo "📋 Headers:      ${HEADERS}"
                echo "🔄 Sync:         ${SYNC_PERCENT}%"
                echo "🌐 Connections:  ${CONNECTIONS}"
                echo "💪 Difficulty:   ${DIFFICULTY}"
                
                # Get mempool info
                MEMPOOL_JSON_RPC='{"jsonrpc":"1.0","id":"monitor","method":"getmempoolinfo","params":[]}'
                
                # Try both service name and container name
                MEMPOOL_RESPONSE=$(curl -s --fail --user "${RPC_USER}:${RPC_PASSWORD}" --data-binary "${MEMPOOL_JSON_RPC}" "http://meowcoin-core:${MEOWCOIN_RPC_PORT}" 2>/dev/null)
                
                if [ $? -ne 0 ]; then
                    # Try with container name if service name fails
                    MEMPOOL_RESPONSE=$(curl -s --fail --user "${RPC_USER}:${RPC_PASSWORD}" --data-binary "${MEMPOOL_JSON_RPC}" "http://meowcoin-node:${MEOWCOIN_RPC_PORT}" 2>/dev/null)
                fi
                
                if [ $? -eq 0 ] && echo "${MEMPOOL_RESPONSE}" | jq -e '.error == null' >/dev/null; then
                    MEMPOOL_SIZE=$(echo "${MEMPOOL_RESPONSE}" | jq '.result.size')
                    MEMPOOL_BYTES=$(echo "${MEMPOOL_RESPONSE}" | jq '.result.bytes')
                    MEMPOOL_MB=$(echo "${MEMPOOL_BYTES} / 1048576" | bc -l | awk '{printf "%.2f", $0}')
                    
                    echo "📝 Mempool:      ${MEMPOOL_SIZE} txs (${MEMPOOL_MB} MB)"
                fi
            else
                ERROR_MSG=$(echo "${RESPONSE}" | jq -r '.error.message // "Request failed or node is not ready"')
                log_warning "RPC Status: UNHEALTHY or STARTING - ${ERROR_MSG}"
            fi
        else
            log_warning "Credentials not found. Waiting for node to generate them..."
        fi
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
