#!/bin/bash
set -euo pipefail

# Simple logging functions
log_info() {
    echo "[INFO] $*"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" >> /tmp/meowcoin-monitor.log
}

log_success() {
    echo "[SUCCESS] $*"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $*" >> /tmp/meowcoin-monitor.log
}

log_warning() {
    echo "[WARNING] $*" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $*" >> /tmp/meowcoin-monitor.log
}

log_error() {
    echo "[ERROR] $*" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" >> /tmp/meowcoin-monitor.log
}

# Start with a clear log file
echo "=== Meowcoin Monitor Log Started at $(date) ===" > /tmp/meowcoin-monitor.log

# Function to check if RPC server is available
check_rpc_available() {
    # Try multiple ways to connect to the RPC server
    
    # 1. Try service name
    if nc -z meowcoin-core "${MEOWCOIN_RPC_PORT}" -w 5; then
        echo "Connected via service name: meowcoin-core"
        export RPC_HOST="meowcoin-core"
        return 0
    fi
    
    # 2. Try container name
    if nc -z meowcoin-node "${MEOWCOIN_RPC_PORT}" -w 5; then
        echo "Connected via container name: meowcoin-node"
        export RPC_HOST="meowcoin-node"
        return 0
    fi
    
    # 3. Try localhost (in case they're on the same network namespace)
    if nc -z localhost "${MEOWCOIN_RPC_PORT}" -w 5; then
        echo "Connected via localhost"
        export RPC_HOST="localhost"
        return 0
    fi
    
    # 4. Try 127.0.0.1 (in case they're on the same network namespace)
    if nc -z 127.0.0.1 "${MEOWCOIN_RPC_PORT}" -w 5; then
        echo "Connected via 127.0.0.1"
        export RPC_HOST="127.0.0.1"
        return 0
    fi
    
    # 5. Try to find the IP address of the meowcoin-core container
    local core_ip
    core_ip=$(getent hosts meowcoin-core | awk '{ print $1 }')
    if [ -n "$core_ip" ] && nc -z "$core_ip" "${MEOWCOIN_RPC_PORT}" -w 5; then
        echo "Connected via resolved IP: $core_ip"
        export RPC_HOST="$core_ip"
        return 0
    fi
    
    # 6. Try to find the IP address of the meowcoin-node container
    local node_ip
    node_ip=$(getent hosts meowcoin-node | awk '{ print $1 }')
    if [ -n "$node_ip" ] && nc -z "$node_ip" "${MEOWCOIN_RPC_PORT}" -w 5; then
        echo "Connected via resolved IP: $node_ip"
        export RPC_HOST="$node_ip"
        return 0
    fi
    
    # If all attempts fail, return failure
    return 1
}

log_info "Meowcoin Monitor Starting..."
log_info "Monitor container started successfully"

# Wait for core service to be ready
log_info "Waiting for core service to initialize..."
sleep 30

# --- Configuration ---
MEOWCOIN_RPC_PORT=${MEOWCOIN_RPC_PORT:-9766}
MONITOR_INTERVAL=${MONITOR_INTERVAL:-60}
CREDENTIALS_FILE="/data/.credentials"
DEBUG=${DEBUG:-0}

# Print network debug information if DEBUG is enabled
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

# The 'depends_on' in docker-compose handles waiting for the meowcoin-core service
# to be healthy before this container starts.

while true; do
    # Create a status file that can be accessed from outside
    STATUS_FILE="/tmp/meowcoin-status.txt"
    
    # Start with a clean status file
    echo "===================="  > "$STATUS_FILE"
    echo "📊 Meowcoin Status"   >> "$STATUS_FILE"
    echo "⏰ $(date)"           >> "$STATUS_FILE"
    echo "====================" >> "$STATUS_FILE"
    
    # Also output to console
    echo ""
    echo "===================="
    echo "📊 Meowcoin Status"
    echo "⏰ $(date)"
    echo "===================="
    
    # Check if RPC server is available
    if check_rpc_available; then
        echo "RPC server available at ${RPC_HOST}:${MEOWCOIN_RPC_PORT}" >> "$STATUS_FILE"
        if [ -f "$CREDENTIALS_FILE" ]; then
            echo "Credentials file found" >> "$STATUS_FILE"
            # Load credentials securely without executing the file
            RPC_USER=$(grep '^RPC_USER=' "$CREDENTIALS_FILE" | cut -d'=' -f2-)
            RPC_PASSWORD=$(grep '^RPC_PASSWORD=' "$CREDENTIALS_FILE" | cut -d'=' -f2-)
            
            # Perform a full, authenticated health check
            JSON_RPC='{"jsonrpc":"1.0","id":"monitor","method":"getblockchaininfo","params":[]}'
            
            # Use the RPC_HOST variable set by check_rpc_available
            RESPONSE=$(curl -s --fail --user "${RPC_USER}:${RPC_PASSWORD}" --data-binary "${JSON_RPC}" "http://${RPC_HOST}:${MEOWCOIN_RPC_PORT}" 2>/dev/null)

            if [ $? -eq 0 ] && echo "${RESPONSE}" | jq -e '.error == null' >/dev/null; then
                BLOCKS=$(echo "${RESPONSE}" | jq '.result.blocks')
                HEADERS=$(echo "${RESPONSE}" | jq '.result.headers')
                DIFFICULTY=$(echo "${RESPONSE}" | jq '.result.difficulty')
                SYNC_PROGRESS=$(echo "${RESPONSE}" | jq '.result.verificationprogress')
                SYNC_PERCENT=$(echo "${SYNC_PROGRESS} * 100" | bc -l | awk '{printf "%.2f", $0}')
                
                # Get network info for connections
                NETWORK_JSON_RPC='{"jsonrpc":"1.0","id":"monitor","method":"getnetworkinfo","params":[]}'
                
                # Use the RPC_HOST variable set by check_rpc_available
                NETWORK_RESPONSE=$(curl -s --fail --user "${RPC_USER}:${RPC_PASSWORD}" --data-binary "${NETWORK_JSON_RPC}" "http://${RPC_HOST}:${MEOWCOIN_RPC_PORT}" 2>/dev/null)
                
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
                
                # Also write to status file
                echo "RPC Server:   ONLINE" >> "$STATUS_FILE"
                echo "Version:      $(cat /data/VERSION 2>/dev/null || echo "Unknown")" >> "$STATUS_FILE"
                echo "Blocks:       ${BLOCKS}" >> "$STATUS_FILE"
                echo "Headers:      ${HEADERS}" >> "$STATUS_FILE"
                echo "Sync:         ${SYNC_PERCENT}%" >> "$STATUS_FILE"
                echo "Connections:  ${CONNECTIONS}" >> "$STATUS_FILE"
                echo "Difficulty:   ${DIFFICULTY}" >> "$STATUS_FILE"
                
                # Get mempool info
                MEMPOOL_JSON_RPC='{"jsonrpc":"1.0","id":"monitor","method":"getmempoolinfo","params":[]}'
                
                # Use the RPC_HOST variable set by check_rpc_available
                MEMPOOL_RESPONSE=$(curl -s --fail --user "${RPC_USER}:${RPC_PASSWORD}" --data-binary "${MEMPOOL_JSON_RPC}" "http://${RPC_HOST}:${MEOWCOIN_RPC_PORT}" 2>/dev/null)
                
                if [ $? -eq 0 ] && echo "${MEMPOOL_RESPONSE}" | jq -e '.error == null' >/dev/null; then
                    MEMPOOL_SIZE=$(echo "${MEMPOOL_RESPONSE}" | jq '.result.size')
                    MEMPOOL_BYTES=$(echo "${MEMPOOL_RESPONSE}" | jq '.result.bytes')
                    MEMPOOL_MB=$(echo "${MEMPOOL_BYTES} / 1048576" | bc -l | awk '{printf "%.2f", $0}')
                    
                    echo "📝 Mempool:      ${MEMPOOL_SIZE} txs (${MEMPOOL_MB} MB)"
                    echo "Mempool:      ${MEMPOOL_SIZE} txs (${MEMPOOL_MB} MB)" >> "$STATUS_FILE"
                fi
            else
                ERROR_MSG=$(echo "${RESPONSE}" | jq -r '.error.message // "Request failed or node is not ready"')
                log_warning "RPC Status: UNHEALTHY or STARTING - ${ERROR_MSG}"
                echo "RPC Status: UNHEALTHY or STARTING - ${ERROR_MSG}" >> "$STATUS_FILE"
            fi
        else
            log_warning "Credentials not found. Waiting for node to generate them..."
            echo "Credentials not found. Waiting for node to generate them..." >> "$STATUS_FILE"
        fi
    else
        log_warning "RPC Server: OFFLINE or UNREACHABLE"
        echo "RPC Server: OFFLINE or UNREACHABLE" >> "$STATUS_FILE"
    fi
    
    # Show disk usage of the data directory
    if [ -d /data ]; then
        SIZE=$(du -sh /data 2>/dev/null | cut -f1)
        echo "💾 Data Size:    ${SIZE}"
        echo "Data Size:    ${SIZE}" >> "$STATUS_FILE"
        
        # Show file count in the data directory
        FILES=$(find /data -type f 2>/dev/null | wc -l)
        echo "📁 Files:        ${FILES}"
        echo "Files:        ${FILES}" >> "$STATUS_FILE"
    fi
    
    echo "====================" 
    echo "====================" >> "$STATUS_FILE"
    
    # Add timestamp to status file
    echo "Status updated at: $(date)" >> "$STATUS_FILE"
    sleep "${MONITOR_INTERVAL}"
done
