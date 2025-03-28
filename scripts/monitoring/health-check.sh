# scripts/monitoring/health-check.sh
#!/bin/bash
set -e

# Configuration
CONFIG_FILE="/home/meowcoin/.meowcoin/meowcoin.conf"
THRESHOLD_FILE="/etc/meowcoin/health/thresholds.conf"
STATUS_FILE="/tmp/meowcoin_health_status.json"
LOG_FILE="/var/log/meowcoin/health-check.log"

# Load thresholds
if [ -f "$THRESHOLD_FILE" ]; then
  source "$THRESHOLD_FILE"
else
  # Default thresholds
  MAX_BLOCKS_BEHIND=6
  MIN_PEERS=3
  MAX_MEMPOOL_SIZE=300
  HEALTH_CHECK_INTERVAL=300
  ALERT_ON_SYNC_STALLED=true
  CHECK_DISK_SPACE=true
  MIN_FREE_SPACE_GB=5
fi

# Create log entry
echo "[$(date -Iseconds)] Running health check" >> $LOG_FILE

# Helper function to get RPC credentials
get_rpc_auth() {
  USER=$(grep -m 1 "rpcuser=" "$CONFIG_FILE" | cut -d= -f2)
  PASS=$(grep -m 1 "rpcpassword=" "$CONFIG_FILE" | cut -d= -f2)
  
  # Support for JWT authentication
  if grep -q "rpcauth=jwtsecret" "$CONFIG_FILE"; then
    JWT_SECRET_FILE="/home/meowcoin/.meowcoin/.jwtsecret"
    if [ -f "$JWT_SECRET_FILE" ]; then
      JWT_TOKEN=$(cat "$JWT_SECRET_FILE" | xxd -p -c 1000)
      echo "-rpcauth=$JWT_TOKEN"
      return 0
    fi
  fi
  
  echo "-rpcuser=$USER -rpcpassword=$PASS"
}

# Check if node is running
if ! pgrep -x "meowcoind" > /dev/null; then
  echo "ERROR: Meowcoin daemon is not running" | tee -a $LOG_FILE
  
  # Write status file
  cat > "$STATUS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "status": "offline",
  "error": "Daemon not running"
}
EOF
  
  exit 1
fi

# Get RPC auth
RPC_AUTH=$(get_rpc_auth)

# Check blockchain info
BLOCKCHAIN_INFO=$(meowcoin-cli $RPC_AUTH getblockchaininfo 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "ERROR: Cannot get blockchain info from node" | tee -a $LOG_FILE
  
  # Write status file
  cat > "$STATUS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "status": "error",
  "error": "Cannot connect to RPC"
}
EOF
  
  exit 1
fi

# Check network info
NETWORK_INFO=$(meowcoin-cli $RPC_AUTH getnetworkinfo 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "ERROR: Cannot get network info from node" | tee -a $LOG_FILE
  exit 1
fi

# Check mempool info
MEMPOOL_INFO=$(meowcoin-cli $RPC_AUTH getmempoolinfo 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "ERROR: Cannot get mempool info from node" | tee -a $LOG_FILE
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

# Check disk space if enabled
DISK_SPACE_WARNING=false
if [ "$CHECK_DISK_SPACE" = "true" ]; then
  AVAILABLE_SPACE_KB=$(df -k /home/meowcoin/.meowcoin | tail -1 | awk '{print $4}')
  AVAILABLE_SPACE_GB=$((AVAILABLE_SPACE_KB / 1024 / 1024))
  
  if [ $AVAILABLE_SPACE_GB -lt $MIN_FREE_SPACE_GB ]; then
    DISK_SPACE_WARNING=true
    echo "WARNING: Low disk space: ${AVAILABLE_SPACE_GB}GB available (minimum: ${MIN_FREE_SPACE_GB}GB)" | tee -a $LOG_FILE
  fi
fi

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
  "disk_space_gb": $AVAILABLE_SPACE_GB,
  "disk_space_warning": $DISK_SPACE_WARNING,
  "status": "unknown"
}
EOF

# Evaluate health
HEALTH_ISSUES=0

# Check if node is in sync
if [ $BLOCKS_BEHIND -gt $MAX_BLOCKS_BEHIND ]; then
  echo "WARNING: Node is $BLOCKS_BEHIND blocks behind headers" | tee -a $LOG_FILE
  HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
  sed -i 's/"status": "unknown"/"status": "syncing"/' "$STATUS_FILE"
fi

# Check peer connections
if [ $CONNECTIONS -lt $MIN_PEERS ]; then
  echo "WARNING: Only $CONNECTIONS peer connections (minimum: $MIN_PEERS)" | tee -a $LOG_FILE
  HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
  sed -i 's/"status": "unknown"/"status": "low_peers"/' "$STATUS_FILE"
fi

# Check mempool size
if [ $MEMPOOL_SIZE -gt $MAX_MEMPOOL_SIZE ]; then
  echo "WARNING: Mempool has $MEMPOOL_SIZE transactions (maximum: $MAX_MEMPOOL_SIZE)" | tee -a $LOG_FILE
  HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
  sed -i 's/"status": "unknown"/"status": "high_mempool"/' "$STATUS_FILE"
fi

# Check disk space
if [ "$DISK_SPACE_WARNING" = "true" ]; then
  HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
  sed -i 's/"status": "unknown"/"status": "low_disk_space"/' "$STATUS_FILE"
fi

# Check for stalled sync if enabled
if [ "$ALERT_ON_SYNC_STALLED" = "true" ] && [ $BLOCKS_BEHIND -gt 0 ]; then
  if [ -f "/tmp/meowcoin_last_block" ]; then
    LAST_BLOCK=$(cat /tmp/meowcoin_last_block)
    if [ "$LAST_BLOCK" = "$BLOCKS" ]; then
      echo "WARNING: Sync appears stalled - block height hasn't changed since last check" | tee -a $LOG_FILE
      HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
      sed -i 's/"status": "unknown"/"status": "sync_stalled"/' "$STATUS_FILE"
    fi
  fi
  echo "$BLOCKS" > /tmp/meowcoin_last_block
fi

# Final health determination
if [ $HEALTH_ISSUES -eq 0 ]; then
  # Node is healthy
  sed -i 's/"status": "unknown"/"status": "healthy"/' "$STATUS_FILE"
  echo "Node is healthy: $BLOCKS blocks, $CONNECTIONS peers, $MEMPOOL_SIZE mempool transactions" | tee -a $LOG_FILE
  exit 0
else
  # Node has issues
  echo "Node has $HEALTH_ISSUES health issues" | tee -a $LOG_FILE
  exit 1
fi