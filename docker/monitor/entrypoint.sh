#!/bin/bash
set -euo pipefail

# Source common functions
source /usr/local/bin/common.sh

# Configuration
MEOWCOIN_RPC_PORT=${MEOWCOIN_RPC_PORT:-9766}
MONITOR_INTERVAL=${MONITOR_INTERVAL:-180}
CREDENTIALS_FILE="/data/.credentials"
MEOWCOIN_HOST=${MEOWCOIN_HOST:-meowcoin-core}

# Function to check if RPC server is available
check_rpc_available() {
    nc -z "${MEOWCOIN_HOST}" "${MEOWCOIN_RPC_PORT}" -w 5
    return $?
}

# Function to get blockchain info
get_blockchain_info() {
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        log_warning "Credentials not found. Waiting for node to generate them..."
        return 1
    fi
    
    # Load credentials securely
    local rpc_user
    local rpc_password
    rpc_user=$(grep '^RPC_USER=' "$CREDENTIALS_FILE" | cut -d'=' -f2-)
    rpc_password=$(grep '^RPC_PASSWORD=' "$CREDENTIALS_FILE" | cut -d'=' -f2-)
    
    # Prepare JSON-RPC request
    local json_rpc='{"jsonrpc":"1.0","id":"monitor","method":"getblockchaininfo","params":[]}'
    
    # Make RPC call
    local response
    response=$(curl -s --fail --user "${rpc_user}:${rpc_password}" \
               --data-binary "${json_rpc}" \
               "http://${MEOWCOIN_HOST}:${MEOWCOIN_RPC_PORT}" 2>/dev/null)
    
    # Check if response is valid
    if [[ $? -eq 0 ]] && echo "${response}" | jq -e '.error == null' >/dev/null; then
        echo "${response}"
        return 0
    else
        local error_msg
        error_msg=$(echo "${response}" | jq -r '.error.message // "Request failed or node is not ready"')
        log_warning "RPC Status: UNHEALTHY or STARTING - ${error_msg}"
        return 1
    fi
}

# Function to display node status
display_status() {
    local blockchain_info=$1
    
    # Extract data
    local blocks
    local headers
    local difficulty
    local sync_progress
    local connections
    
    blocks=$(echo "${blockchain_info}" | jq '.result.blocks')
    headers=$(echo "${blockchain_info}" | jq '.result.headers')
    difficulty=$(echo "${blockchain_info}" | jq '.result.difficulty')
    sync_progress=$(echo "${blockchain_info}" | jq '.result.verificationprogress')
    
    # Get network info for connections
    local network_info
    network_info=$(curl -s --fail --user "${rpc_user}:${rpc_password}" \
                 --data-binary '{"jsonrpc":"1.0","id":"monitor","method":"getnetworkinfo","params":[]}' \
                 "http://${MEOWCOIN_HOST}:${MEOWCOIN_RPC_PORT}" 2>/dev/null)
    
    if [[ $? -eq 0 ]] && echo "${network_info}" | jq -e '.error == null' >/dev/null; then
        connections=$(echo "${network_info}" | jq '.result.connections')
    else
        connections="N/A"
    fi
    
    # Format sync progress as percentage
    sync_percent=$(echo "${sync_progress} * 100" | bc -l | awk '{printf "%.2f", $0}')
    
    # Display status
    echo "✅ RPC Server:   ONLINE"
    echo "📦 Version:      $(cat /data/VERSION 2>/dev/null || echo "Unknown")"
    echo "🔗 Blocks:       ${blocks}"
    echo "📋 Headers:      ${headers}"
    echo "🔄 Sync:         ${sync_percent}%"
    echo "🌐 Connections:  ${connections:-0}"
    echo "💪 Difficulty:   ${difficulty}"
    
    # Get mempool info
    local mempool_info
    mempool_info=$(curl -s --fail --user "${rpc_user}:${rpc_password}" \
                 --data-binary '{"jsonrpc":"1.0","id":"monitor","method":"getmempoolinfo","params":[]}' \
                 "http://${MEOWCOIN_HOST}:${MEOWCOIN_RPC_PORT}" 2>/dev/null)
    
    if [[ $? -eq 0 ]] && echo "${mempool_info}" | jq -e '.error == null' >/dev/null; then
        local mempool_size
        local mempool_bytes
        mempool_size=$(echo "${mempool_info}" | jq '.result.size')
        mempool_bytes=$(echo "${mempool_info}" | jq '.result.bytes')
        mempool_mb=$(echo "${mempool_bytes} / 1048576" | bc -l | awk '{printf "%.2f", $0}')
        
        echo "📝 Mempool:      ${mempool_size} txs (${mempool_mb} MB)"
    fi
}

# Function to display disk usage
display_disk_usage() {
    if [[ -d /data ]]; then
        local size
        local files
        
        size=$(du -sh /data 2>/dev/null | cut -f1)
        files=$(find /data -type f 2>/dev/null | wc -l)
        
        echo "💾 Data Size:    ${size}"
        echo "📁 Files:        ${files}"
    fi
}

# Main monitoring loop
main() {
    log_info "Meowcoin Monitor Starting..."
    
    while true; do
        echo ""
        echo "===================="
        echo "📊 Meowcoin Status"
        echo "⏰ $(date)"
        echo "===================="
        
        # Check if RPC server is available
        if check_rpc_available; then
            # Get blockchain info
            local blockchain_info
            if blockchain_info=$(get_blockchain_info); then
                display_status "${blockchain_info}"
            fi
        else
            log_warning "RPC Server: OFFLINE or UNREACHABLE"
        fi
        
        # Display disk usage
        display_disk_usage
        
        echo "===================="
        sleep "${MONITOR_INTERVAL}"
    done
}

# Run the main function
main