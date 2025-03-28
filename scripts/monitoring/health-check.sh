# scripts/monitoring/health-check.sh
#!/bin/bash
set -e

# Configuration
CONFIG_FILE="/home/meowcoin/.meowcoin/meowcoin.conf"
THRESHOLD_FILE="/etc/meowcoin/health/thresholds.conf"
STATUS_FILE="/tmp/meowcoin_health_status.json"

# Load thresholds
if [ -f "$THRESHOLD_FILE" ]; then
  source "$THRESHOLD_FILE"
else
  # Default thresholds
  MAX_BLOCKS_BEHIND=6
  MIN_PEERS=3
  MAX_MEMPOOL_SIZE=300
fi

# Helper function to get RPC credentials
get_rpc_auth() {
  USER=$(grep -m 1 "rpcuser=" "$CONFIG_FILE" | cut -d= -f2)
  PASS=$(grep -m 1 "rpcpassword=" "$CONFIG_FILE" | cut -d= -f2)
  echo "-rpcuser=$USER -rpcpassword=$PASS"
}

# Check if node is running
if ! pgrep -x "meowcoind" > /dev/null; then
  echo "ERROR: Meowcoin daemon is not running"
  exit 1
fi

# Get RPC auth
RPC_AUTH=$(get_rpc_auth)

# Check blockchain info
BLOCKCHAIN_INFO=$(meowcoin-cli $RPC_AUTH getblockchaininfo 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "ERROR: Cannot get blockchain info from node"
  exit 1
fi

# Check network info
NETWORK_INFO=$(meowcoin-cli $RPC_AUTH getnetworkinfo 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "ERROR: Cannot get network info from node"
  exit 1
fi

# Check mempool info
MEMPOOL_INFO=$(meowcoin-cli $RPC_AUTH getmempoolinfo 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "ERROR: Cannot get mempool info from node"
  exit 1
fi

# Extract values
BLOCKS=$(echo "$BLOCKCHAIN_INFO" | grep -m 1 "blocks" | grep -o '[0-9]\+')
HEADERS=$(echo "$BLOCKCHAIN_INFO" | grep -m 1 "headers" | grep -o '[0-9]\+')
CONNECTIONS=$(echo "$NETWORK_INFO" | grep -m 1 "connections" | grep -o '[0-9]\+')
MEMPOOL_SIZE=$(echo "$MEMPOOL_INFO" | grep -m 1 "size" | grep -o '[0-9]\+')
MEMPOOL_BYTES=$(echo "$MEMPOOL_INFO" | grep -m 1 "bytes" | grep -o '[0-9]\+')

# Calculate blocks behind
BLOCKS_BEHIND=$((HEADERS - BLOCKS))

# Store status in JSON format
cat > "$STATUS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "blocks": $BLOCKS,
  "headers": $HEADERS,
  "blocks_behind": $BLOCKS_BEHIND,
  "connections": $CONNECTIONS,
  "mempool_transactions": $MEMPOOL_SIZE,
  "mempool_bytes": $MEMPOOL_BYTES,
  "status": "unknown"
}
EOF

# Evaluate health
HEALTH_ISSUES=0

# Check if node is in sync
if [ $BLOCKS_BEHIND -gt $MAX_BLOCKS_BEHIND ]; then
  echo "WARNING: Node is $BLOCKS_BEHIND blocks behind headers"
  HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
  sed -i 's/"status": "unknown"/"status": "syncing"/' "$STATUS_FILE"
fi

# Check peer connections
if [ $CONNECTIONS -lt $MIN_PEERS ]; then
  echo "WARNING: Only $CONNECTIONS peer connections (minimum: $MIN_PEERS)"
  HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
  sed -i 's/"status": "unknown"/"status": "low_peers"/' "$STATUS_FILE"
fi

# Check mempool size
if [ $MEMPOOL_SIZE -gt $MAX_MEMPOOL_SIZE ]; then
  echo "WARNING: Mempool has $MEMPOOL_SIZE transactions (maximum: $MAX_MEMPOOL_SIZE)"
  HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
  sed -i 's/"status": "unknown"/"status": "high_mempool"/' "$STATUS_FILE"
fi

# Final health determination
if [ $HEALTH_ISSUES -eq 0 ]; then
  # Node is healthy
  sed -i 's/"status": "unknown"/"status": "healthy"/' "$STATUS_FILE"
  echo "Node is healthy: $BLOCKS blocks, $CONNECTIONS peers, $MEMPOOL_SIZE mempool transactions"
  exit 0
else
  # Node has issues
  echo "Node has $HEALTH_ISSUES health issues"
  exit 1
fi