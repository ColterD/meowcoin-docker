#!/bin/bash
set -euo pipefail

# Source common functions
source /usr/local/bin/common.sh

# Constants
MEOWCOIN_DATA_DIR="/home/meowcoin/.meowcoin"
CREDENTIALS_FILE="${MEOWCOIN_DATA_DIR}/.credentials"
MAX_BLOCKS_BEHIND=100

# Function to check if RPC server is responsive
check_rpc_server() {
    # Load credentials
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        log_error "Credentials file not found"
        return 1
    fi
    
    # shellcheck source=/dev/null
    source "$CREDENTIALS_FILE"
    
    # Prepare JSON-RPC request
    local json_rpc='{"jsonrpc":"1.0","id":"healthcheck","method":"getblockchaininfo","params":[]}'
    
    # Make RPC call
    local response
    response=$(curl -s --fail --user "${RPC_USER}:${RPC_PASSWORD}" \
               --data-binary "${json_rpc}" \
               "http://127.0.0.1:${MEOWCOIN_RPC_PORT:-9766}" 2>/dev/null)
    
    # Check if response is valid
    if [[ $? -eq 0 ]] && echo "${response}" | jq -e '.error == null' >/dev/null; then
        return 0
    else
        local error_msg
        error_msg=$(echo "${response}" | jq -r '.error.message // "Request failed or node is not ready"')
        log_error "RPC check failed: ${error_msg}"
        return 1
    fi
}

# Function to check if node is syncing properly
check_sync_status() {
    # Load credentials
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        log_error "Credentials file not found"
        return 1
    fi
    
    # shellcheck source=/dev/null
    source "$CREDENTIALS_FILE"
    
    # Prepare JSON-RPC request
    local json_rpc='{"jsonrpc":"1.0","id":"healthcheck","method":"getblockchaininfo","params":[]}'
    
    # Make RPC call
    local response
    response=$(curl -s --fail --user "${RPC_USER}:${RPC_PASSWORD}" \
               --data-binary "${json_rpc}" \
               "http://127.0.0.1:${MEOWCOIN_RPC_PORT:-9766}" 2>/dev/null)
    
    # Check if response is valid
    if [[ $? -eq 0 ]] && echo "${response}" | jq -e '.error == null' >/dev/null; then
        local blocks
        local headers
        blocks=$(echo "${response}" | jq '.result.blocks')
        headers=$(echo "${response}" | jq '.result.headers')
        
        # Check if blocks are too far behind headers
        if (( headers - blocks > MAX_BLOCKS_BEHIND )); then
            log_error "Node is too far behind: ${blocks}/${headers} blocks"
            return 1
        fi
        
        return 0
    else
        local error_msg
        error_msg=$(echo "${response}" | jq -r '.error.message // "Request failed or node is not ready"')
        log_error "Sync check failed: ${error_msg}"
        return 1
    fi
}

# Function to check if node has peers
check_peers() {
    # Load credentials
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        log_error "Credentials file not found"
        return 1
    fi
    
    # shellcheck source=/dev/null
    source "$CREDENTIALS_FILE"
    
    # Prepare JSON-RPC request
    local json_rpc='{"jsonrpc":"1.0","id":"healthcheck","method":"getnetworkinfo","params":[]}'
    
    # Make RPC call
    local response
    response=$(curl -s --fail --user "${RPC_USER}:${RPC_PASSWORD}" \
               --data-binary "${json_rpc}" \
               "http://127.0.0.1:${MEOWCOIN_RPC_PORT:-9766}" 2>/dev/null)
    
    # Check if response is valid
    if [[ $? -eq 0 ]] && echo "${response}" | jq -e '.error == null' >/dev/null; then
        local connections
        connections=$(echo "${response}" | jq '.result.connections')
        
        # Check if node has at least one peer
        if (( connections < 1 )); then
            log_error "Node has no peers"
            return 1
        fi
        
        return 0
    else
        local error_msg
        error_msg=$(echo "${response}" | jq -r '.error.message // "Request failed or node is not ready"')
        log_error "Peer check failed: ${error_msg}"
        return 1
    fi
}

# Main healthcheck logic
main() {
    # Check if RPC server is responsive
    if ! check_rpc_server; then
        exit 1
    fi
    
    # Check if node is syncing properly
    if ! check_sync_status; then
        exit 1
    fi
    
    # Check if node has peers (only if we're not in regtest mode)
    if [[ "${MEOWCOIN_REGTEST:-0}" != "1" ]]; then
        if ! check_peers; then
            exit 1
        fi
    fi
    
    # All checks passed
    log_success "Node is healthy"
    exit 0
}

# Run the main function
main