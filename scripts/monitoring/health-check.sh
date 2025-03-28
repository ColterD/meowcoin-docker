#!/bin/bash
set -e

# Configuration
CONFIG_FILE="/home/meowcoin/.meowcoin/meowcoin.conf"
THRESHOLD_FILE="/etc/meowcoin/health/thresholds.conf"
STATUS_FILE="/tmp/meowcoin_health_status.json"
LOG_FILE="/var/log/meowcoin/health-check.log"
METRICS_DIR="/var/lib/meowcoin/metrics"
ALERT_HISTORY="/var/lib/meowcoin/alert_history.json"
HISTORICAL_DATA="/var/lib/meowcoin/historical_data"
DISTRIBUTED_TRACE_ID="${TRACE_ID:-$(date +%s)-$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8)}"

# Import health check modules
MODULES_DIR="/usr/local/lib/health-checks"
mkdir -p "$MODULES_DIR"

# Load health check modules
source "$MODULES_DIR/common.sh"
source "$MODULES_DIR/blockchain.sh"
source "$MODULES_DIR/network.sh"
source "$MODULES_DIR/system.sh"
source "$MODULES_DIR/anomaly.sh"
source "$MODULES_DIR/alert.sh"

# Ensure directories exist
mkdir -p "$(dirname $STATUS_FILE)" "$(dirname $LOG_FILE)" "$METRICS_DIR" "$(dirname $ALERT_HISTORY)" "$HISTORICAL_DATA"

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
  MAX_CPU_USAGE=90
  MAX_MEMORY_USAGE=90
  MIN_NETWORK_PEERS=3
  RPC_TIMEOUT_SECONDS=5
  DISK_IO_THRESHOLD=90
  ENABLE_ALERTS=true
  ALERT_METHOD="log"  # Options: log, webhook, email
  ALERT_WEBHOOK_URL=""
  ALERT_EMAIL=""
fi

# Create log entry
echo "[$DISTRIBUTED_TRACE_ID][$(date -Iseconds)] Running health check" > $LOG_FILE

# Main health check function
function run_health_check() {
  log "Starting health check (trace ID: $DISTRIBUTED_TRACE_ID)"
  
  # Make sure the node is running first
  if ! check_node_running; then
    return 1
  fi
  
  # Check network connectivity
  NETWORK_OK=true
  if ! check_network_connectivity; then
    NETWORK_OK=false
    log "Network connectivity issues detected"
  fi
  
  # Get RPC auth
  RPC_AUTH=$(get_rpc_auth)
  if [ $? -ne 0 ]; then
    log "Failed to get RPC authentication"
    return 1
  fi
  
  # Check blockchain status
  if ! check_blockchain_status; then
    log "Blockchain status check failed"
    return 1
  fi
  
  # Check network status
  if ! check_network_status; then
    log "Network status check failed"
    return 1
  }
  
  # Check system resources
  if [ "$RESOURCE_CHECK_ENABLED" = "true" ]; then
    if ! check_system_resources; then
      log "System resource check failed"
      return 1
    fi
  fi
  
  # Run anomaly detection if enabled
  if [ "$ANOMALY_DETECTION_ENABLED" = "true" ]; then
    run_anomaly_detection
  fi
  
  # Evaluate final health status
  evaluate_health_status
  
  log "Health check completed"
  return 0
}

# Run the health check
run_health_check
exit $?