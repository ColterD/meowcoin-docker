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
CONNECTIVITY_TEST_HOSTS=("1.1.1.1" "8.8.8.8")
ALERT_COOLDOWN=3600  # Don't send duplicate alerts within this time period (seconds)
ANOMALY_DETECTION_ENABLED=true
RESOURCE_CHECK_ENABLED=true

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
echo "[$(date -Iseconds)] Running health check" > $LOG_FILE

# Function to record metrics
record_metric() {
  local METRIC_NAME="$1"
  local METRIC_VALUE="$2"
  local TIMESTAMP=$(date +%s)
  
  # Save current metric
  echo "$TIMESTAMP $METRIC_VALUE" >> "$METRICS_DIR/${METRIC_NAME}.current"
  
  # Store in historical data with retention
  echo "$TIMESTAMP $METRIC_VALUE" >> "$HISTORICAL_DATA/${METRIC_NAME}.data"
  
  # Keep only last 1000 data points to prevent unbounded growth
  tail -n 1000 "$HISTORICAL_DATA/${METRIC_NAME}.data" > "$HISTORICAL_DATA/${METRIC_NAME}.data.tmp"
  mv "$HISTORICAL_DATA/${METRIC_NAME}.data.tmp" "$HISTORICAL_DATA/${METRIC_NAME}.data"
}

# Function to detect anomalies using historical data
detect_anomaly() {
  local METRIC_NAME="$1"
  local CURRENT_VALUE="$2"
  local THRESHOLD="$3"
  local HISTORY_FILE="$HISTORICAL_DATA/${METRIC_NAME}.data"
  
  # Need at least 10 data points for anomaly detection
  if [ ! -f "$HISTORY_FILE" ] || [ $(wc -l < "$HISTORY_FILE") -lt 10 ]; then
    return 1  # Not enough data
  fi
  
  # Calculate mean and standard deviation
  local MEAN=$(awk '{sum+=$2} END {print sum/NR}' "$HISTORY_FILE")
  local STDDEV=$(awk -v mean=$MEAN '{sum+=($2-mean)^2} END {print sqrt(sum/NR)}' "$HISTORY_FILE")
  
  # Calculate z-score (number of std devs from mean)
  local ZSCORE=$(echo "scale=2; ($CURRENT_VALUE - $MEAN) / $STDDEV" | bc)
  
  # Record the z-score
  record_metric "${METRIC_NAME}_zscore" "$ZSCORE"
  
  # Check if value is anomalous (beyond threshold standard deviations)
  if (( $(echo "$ZSCORE > $THRESHOLD" | bc -l) )) || (( $(echo "$ZSCORE < -$THRESHOLD" | bc -l) )); then
    echo "[$(date -Iseconds)] ANOMALY DETECTED: $METRIC_NAME current=$CURRENT_VALUE mean=$MEAN stddev=$STDDEV zscore=$ZSCORE" >> $LOG_FILE
    return 0  # Anomaly detected
  fi
  
  return 1  # No anomaly
}

# Function to send alerts
send_alert() {
  local ALERT_TYPE="$1"
  local MESSAGE="$2"
  local SEVERITY="${3:-warning}"
  
  # Check if alerts are enabled
  if [ "${ENABLE_ALERTS:-true}" != "true" ]; then
    return
  fi
  
  # Check for alert cooldown
  if [ -f "$ALERT_HISTORY" ]; then
    local LAST_ALERT_TIME=$(jq -r ".[\"$ALERT_TYPE\"].timestamp // 0" "$ALERT_HISTORY")
    local CURRENT_TIME=$(date +%s)
    
    if [ $((CURRENT_TIME - LAST_ALERT_TIME)) -lt $ALERT_COOLDOWN ]; then
      echo "[$(date -Iseconds)] Alert suppressed (cooldown): $MESSAGE" >> $LOG_FILE
      return
    fi
  fi
  
  echo "[$(date -Iseconds)] ALERT [$SEVERITY]: $MESSAGE" >> $LOG_FILE
  
  # Record this alert
  if [ ! -f "$ALERT_HISTORY" ]; then
    echo "{}" > "$ALERT_HISTORY"
  fi
  
  # Update alert history
  local TIMESTAMP=$(date +%s)
  local TEMP_FILE=$(mktemp)
  jq --arg type "$ALERT_TYPE" --arg timestamp "$TIMESTAMP" --arg message "$MESSAGE" --arg severity "$SEVERITY" \
     '.[$type] = {"timestamp": $timestamp|tonumber, "message": $message, "severity": $severity}' \
     "$ALERT_HISTORY" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$ALERT_HISTORY"
  
  # Send via configured method
  case "${ALERT_METHOD:-log}" in
    "webhook")
      if [ ! -z "${ALERT_WEBHOOK_URL}" ]; then
        curl -s -X POST -H "Content-Type: application/json" \
             -d "{\"type\":\"$ALERT_TYPE\",\"message\":\"$MESSAGE\",\"severity\":\"$SEVERITY\",\"timestamp\":\"$(date -Iseconds)\"}" \
             "${ALERT_WEBHOOK_URL}" >> $LOG_FILE 2>&1
      fi
      ;;
    "email")
      if [ ! -z "${ALERT_EMAIL}" ] && command -v mail >/dev/null 2>&1; then
        echo "$MESSAGE" | mail -s "Meowcoin Node Alert: $ALERT_TYPE [$SEVERITY]" "${ALERT_EMAIL}"
      fi
      ;;
    *)
      # Default is log only, already done
      ;;
  esac
}

# Helper function to get RPC credentials with improved JWT support
get_rpc_auth() {
  # Support for JWT authentication
  if grep -q "jwt=1" "$CONFIG_FILE" || grep -q "rpcauth=jwtsecret" "$CONFIG_FILE"; then
    JWT_SECRET_FILE="/home/meowcoin/.meowcoin/.jwtsecret"
    if [ -f "$JWT_SECRET_FILE" ]; then
      # Get public key if available
      JWT_PUB_FILE="${JWT_SECRET_FILE}.pub"
      if [ -f "$JWT_PUB_FILE" ]; then
        JWT_TOKEN=$(xxd -p -c 1000 "$JWT_PUB_FILE")
      else
        JWT_TOKEN=$(xxd -p -c 1000 "$JWT_SECRET_FILE")
      fi
      echo "-rpcauth=$JWT_TOKEN"
      return 0
    fi
  fi
  
  # Default to username/password auth
  USER=$(grep -m 1 "rpcuser=" "$CONFIG_FILE" | cut -d= -f2)
  PASS=$(grep -m 1 "rpcpassword=" "$CONFIG_FILE" | cut -d= -f2)
  
  echo "-rpcuser=$USER -rpcpassword=$PASS"
}

# Check if node is running with improved detection
if ! pgrep -x "meowcoind" > /dev/null; then
  echo "ERROR: Meowcoin daemon is not running" | tee -a $LOG_FILE
  
  # Check for crash logs
  CRASH_LOG=$(find /home/meowcoin/.meowcoin -name "core.*" -o -name "crash_*" | head -1)
  if [ ! -z "$CRASH_LOG" ]; then
    echo "Found potential crash evidence: $CRASH_LOG" | tee -a $LOG_FILE
    # Extract crash info if core dump tools available
    if command -v gdb >/dev/null 2>&1; then
      echo "Crash analysis:" | tee -a $LOG_FILE
      gdb -batch -ex "thread apply all bt" /usr/bin/meowcoind "$CRASH_LOG" 2>/dev/null | head -20 | tee -a $LOG_FILE
    fi
  fi
  
  # Write status file
  cat > "$STATUS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "status": "offline",
  "error": "Daemon not running",
  "check_time": $(date +%s)
}
EOF
  
  # Send alert
  send_alert "node_offline" "Meowcoin daemon is not running" "critical"
  
  exit 1
fi

# Check network connectivity to important resources
NETWORK_OK=true
for HOST in "${CONNECTIVITY_TEST_HOSTS[@]}"; do
  if ! ping -c 1 -W 5 "$HOST" >/dev/null 2>&1; then
    echo "WARNING: Network connectivity issue detected - cannot reach $HOST" | tee -a $LOG_FILE
    NETWORK_OK=false
  fi
done

# Get RPC auth
RPC_AUTH=$(get_rpc_auth)

# Check blockchain info
BLOCKCHAIN_INFO=$(timeout $RPC_TIMEOUT_SECONDS meowcoin-cli $RPC_AUTH getblockchaininfo 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "ERROR: Cannot get blockchain info from node" | tee -a $LOG_FILE
  
  # Check for specific RPC issues
  if meowcoin-cli $RPC_AUTH -getinfo 2>&1 | grep -q "Connection refused"; then
    echo "RPC connection refused - check if RPC server is running and accessible" | tee -a $LOG_FILE
    send_alert "rpc_connection" "RPC connection refused" "critical"
  elif meowcoin-cli $RPC_AUTH -getinfo 2>&1 | grep -q "incorrect password"; then
    echo "RPC authentication failed - check credentials" | tee -a $LOG_FILE
    send_alert "rpc_auth" "RPC authentication failed" "critical"
  else
    echo "Unknown RPC error, node may be starting or under heavy load" | tee -a $LOG_FILE
    send_alert "rpc_error" "Cannot connect to RPC API" "critical"
  fi
  
  # Write status file
  cat > "$STATUS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "status": "error",
  "error": "Cannot connect to RPC",
  "check_time": $(date +%s)
}
EOF
  
  exit 1
fi

# Check network info
NETWORK_INFO=$(timeout $RPC_TIMEOUT_SECONDS meowcoin-cli $RPC_AUTH getnetworkinfo 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "ERROR: Cannot get network info from node" | tee -a $LOG_FILE
  
  # Write status file
  cat > "$STATUS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "status": "error",
  "error": "Cannot get network info",
  "check_time": $(date +%s)
}
EOF
  
  send_alert "network_info_error" "Cannot retrieve network information" "warning"
  exit 1
fi

# Check mempool info
MEMPOOL_INFO=$(timeout $RPC_TIMEOUT_SECONDS meowcoin-cli $RPC_AUTH getmempoolinfo 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "ERROR: Cannot get mempool info from node" | tee -a $LOG_FILE
  
  # Write status file
  cat > "$STATUS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "status": "error",
  "error": "Cannot get mempool info",
  "check_time": $(date +%s)
}
EOF
  
  send_alert "mempool_info_error" "Cannot retrieve mempool information" "warning"
  exit 1
fi

# Extract values with improved error handling
extract_json_value() {
  local JSON="$1"
  local KEY="$2"
  local DEFAULT="$3"
  
  # Use 'jq' if available for more reliable JSON parsing
  if command -v jq >/dev/null 2>&1; then
    local VALUE=$(echo "$JSON" | jq -r ".$KEY // \"$DEFAULT\"" 2>/dev/null)
    if [ $? -ne 0 ] || [ "$VALUE" = "null" ] || [ -z "$VALUE" ]; then
      echo "$DEFAULT"
    else
      echo "$VALUE"
    fi
  else
    # Fallback to grep for simple cases
    local VALUE=$(echo "$JSON" | grep -m 1 "\"$KEY\"" | sed -E "s/.*\"$KEY\"[^0-9]*([0-9]+).*/\1/")
    if [ -z "$VALUE" ]; then
      echo "$DEFAULT"
    else
      echo "$VALUE"
    fi
  fi
}

# Extract blockchain data
BLOCKS=$(extract_json_value "$BLOCKCHAIN_INFO" "blocks" "0")
HEADERS=$(extract_json_value "$BLOCKCHAIN_INFO" "headers" "0")
VERIFICATION_PROGRESS=$(extract_json_value "$BLOCKCHAIN_INFO" "verificationprogress" "0")
CHAIN=$(extract_json_value "$BLOCKCHAIN_INFO" "chain" "unknown")

# Extract network data
CONNECTIONS=$(extract_json_value "$NETWORK_INFO" "connections" "0")
VERSION=$(extract_json_value "$NETWORK_INFO" "version" "0")
SUBVERSION=$(extract_json_value "$NETWORK_INFO" "subversion" "unknown")
PROTOCOL_VERSION=$(extract_json_value "$NETWORK_INFO" "protocolversion" "0")

# Extract mempool data
MEMPOOL_SIZE=$(extract_json_value "$MEMPOOL_INFO" "size" "0")
MEMPOOL_BYTES=$(extract_json_value "$MEMPOOL_INFO" "bytes" "0")
MEMPOOL_USAGE=$(extract_json_value "$MEMPOOL_INFO" "usage" "0")
MEMPOOL_MAX_MEM=$(extract_json_value "$MEMPOOL_INFO" "maxmempool" "300000000")

# Calculate blocks behind
BLOCKS_BEHIND=$((HEADERS - BLOCKS))

# Check disk space
DISK_SPACE_WARNING=false
DISK_USAGE_PCT=0
if [ "$CHECK_DISK_SPACE" = "true" ]; then
  AVAILABLE_SPACE_KB=$(df -k /home/meowcoin/.meowcoin | tail -1 | awk '{print $4}')
  AVAILABLE_SPACE_GB=$((AVAILABLE_SPACE_KB / 1024 / 1024))
  TOTAL_SPACE_KB=$(df -k /home/meowcoin/.meowcoin | tail -1 | awk '{print $2}')
  TOTAL_SPACE_GB=$((TOTAL_SPACE_KB / 1024 / 1024))
  USED_SPACE_KB=$((TOTAL_SPACE_KB - AVAILABLE_SPACE_KB))
  DISK_USAGE_PCT=$((USED_SPACE_KB * 100 / TOTAL_SPACE_KB))
  
  if [ $AVAILABLE_SPACE_GB -lt $MIN_FREE_SPACE_GB ]; then
    DISK_SPACE_WARNING=true
    echo "WARNING: Low disk space: ${AVAILABLE_SPACE_GB}GB available (minimum: ${MIN_FREE_SPACE_GB}GB)" | tee -a $LOG_FILE
    send_alert "low_disk_space" "Low disk space: ${AVAILABLE_SPACE_GB}GB available (minimum: ${MIN_FREE_SPACE_GB}GB)" "warning"
  fi
  
  # Check inode usage too (can be a hidden problem)
  INODE_USAGE_PCT=$(df -i /home/meowcoin/.meowcoin | tail -1 | awk '{print $5}' | tr -d '%')
  if [ $INODE_USAGE_PCT -gt 90 ]; then
    echo "WARNING: High inode usage: ${INODE_USAGE_PCT}% (can prevent new file creation)" | tee -a $LOG_FILE
    send_alert "high_inode_usage" "High inode usage: ${INODE_USAGE_PCT}% (can prevent new file creation)" "warning"
  fi
}

# Check system resources if enabled
if [ "$RESOURCE_CHECK_ENABLED" = "true" ]; then
  # Check CPU usage
  if command -v top >/dev/null 2>&1; then
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    record_metric "cpu_usage" "$CPU_USAGE"
    
    if [ $(echo "$CPU_USAGE > $MAX_CPU_USAGE" | bc -l) -eq 1 ]; then
      echo "WARNING: High CPU usage: ${CPU_USAGE}% (threshold: ${MAX_CPU_USAGE}%)" | tee -a $LOG_FILE
      send_alert "high_cpu" "High CPU usage: ${CPU_USAGE}% (threshold: ${MAX_CPU_USAGE}%)" "warning"
    fi
    
    # Check for CPU anomalies
    if [ "$ANOMALY_DETECTION_ENABLED" = "true" ]; then
      if detect_anomaly "cpu_usage" "$CPU_USAGE" "2.5"; then
        send_alert "cpu_anomaly" "Unusual CPU usage pattern detected: ${CPU_USAGE}%" "warning"
      fi
    fi
  fi
  
  # Check memory usage
  if command -v free >/dev/null 2>&1; then
    MEMORY_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    record_metric "memory_usage" "$MEMORY_USAGE"
    
    if [ $(echo "$MEMORY_USAGE > $MAX_MEMORY_USAGE" | bc -l) -eq 1 ]; then
      echo "WARNING: High memory usage: ${MEMORY_USAGE}% (threshold: ${MAX_MEMORY_USAGE}%)" | tee -a $LOG_FILE
      send_alert "high_memory" "High memory usage: ${MEMORY_USAGE}% (threshold: ${MAX_MEMORY_USAGE}%)" "warning"
    fi
    
    # Check for memory anomalies
    if [ "$ANOMALY_DETECTION_ENABLED" = "true" ]; then
      if detect_anomaly "memory_usage" "$MEMORY_USAGE" "2.5"; then
        send_alert "memory_anomaly" "Unusual memory usage pattern detected: ${MEMORY_USAGE}%" "warning"
      fi
    fi
  fi
  
  # Check disk I/O
  if command -v iostat >/dev/null 2>&1; then
    DISK_IO=$(iostat -x | grep -A 1 "avg-cpu" | tail -1 | awk '{print $14}')
    record_metric "disk_io" "$DISK_IO"
    
    if [ $(echo "$DISK_IO > $DISK_IO_THRESHOLD" | bc -l) -eq 1 ]; then
      echo "WARNING: High disk I/O utilization: ${DISK_IO}% (threshold: ${DISK_IO_THRESHOLD}%)" | tee -a $LOG_FILE
      send_alert "high_disk_io" "High disk I/O: ${DISK_IO}% (threshold: ${DISK_IO_THRESHOLD}%)" "warning"
    fi
  fi
fi

# Record all core metrics
record_metric "blocks" "$BLOCKS"
record_metric "headers" "$HEADERS"
record_metric "blocks_behind" "$BLOCKS_BEHIND"
record_metric "connections" "$CONNECTIONS"
record_metric "mempool_size" "$MEMPOOL_SIZE"
record_metric "mempool_bytes" "$MEMPOOL_BYTES"
record_metric "disk_usage" "$DISK_USAGE_PCT"
record_metric "verification_progress" "$VERIFICATION_PROGRESS"
record_metric "mempool_usage" "$MEMPOOL_USAGE"

# Analyze connected peers
if [ $CONNECTIONS -gt 0 ]; then
  # Get detailed peer info
  PEER_INFO=$(timeout $RPC_TIMEOUT_SECONDS meowcoin-cli $RPC_AUTH getpeerinfo 2>/dev/null)
  if [ $? -eq 0 ]; then
    # Count inbound vs outbound connections
    if command -v jq >/dev/null 2>&1; then
      INBOUND=$(echo "$PEER_INFO" | jq '[.[] | select(.inbound == true)] | length')
      OUTBOUND=$(echo "$PEER_INFO" | jq '[.[] | select(.inbound == false)] | length')
      
      # Check connection distribution
      record_metric "inbound_connections" "$INBOUND"
      record_metric "outbound_connections" "$OUTBOUND"
      
      if [ $INBOUND -eq 0 ]; then
        echo "WARNING: No inbound connections - check port forwarding" | tee -a $LOG_FILE
        send_alert "no_inbound" "No inbound connections - check port forwarding" "warning"
      fi
      
      if [ $OUTBOUND -eq 0 ]; then
        echo "WARNING: No outbound connections - check firewall/network" | tee -a $LOG_FILE
        send_alert "no_outbound" "No outbound connections - check firewall/network" "warning"
      fi
      
      # Check for banned peers
      BANNED_INFO=$(timeout $RPC_TIMEOUT_SECONDS meowcoin-cli $RPC_AUTH listbanned 2>/dev/null)
      if [ $? -eq 0 ]; then
        BANNED_COUNT=$(echo "$BANNED_INFO" | jq '. | length')
        record_metric "banned_peers" "$BANNED_COUNT"
        
        if [ $BANNED_COUNT -gt 10 ]; then
          echo "WARNING: High number of banned peers: $BANNED_COUNT" | tee -a $LOG_FILE
          send_alert "high_banned" "High number of banned peers: $BANNED_COUNT" "warning"
        fi
      fi
    fi
  fi
fi

# Get uptime information
UPTIME_INFO=$(timeout $RPC_TIMEOUT_SECONDS meowcoin-cli $RPC_AUTH uptime 2>/dev/null)
if [ $? -eq 0 ]; then
  record_metric "node_uptime" "$UPTIME_INFO"
fi

# Store status in JSON format with improved content
cat > "$STATUS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "check_time": $(date +%s),
  "blockchain": {
    "blocks": $BLOCKS,
    "headers": $HEADERS,
    "blocks_behind": $BLOCKS_BEHIND,
    "verification_progress": $VERIFICATION_PROGRESS,
    "chain": "$CHAIN"
  },
  "network": {
    "connections": $CONNECTIONS,
    "network_ok": $NETWORK_OK,
    "version": $VERSION,
    "subversion": "$SUBVERSION",
    "protocol_version": $PROTOCOL_VERSION
  },
  "mempool": {
    "transactions": $MEMPOOL_SIZE,
    "bytes": $MEMPOOL_BYTES,
    "usage": $MEMPOOL_USAGE,
    "max_mem": $MEMPOOL_MAX_MEM
  },
  "system": {
    "disk_space_gb": $AVAILABLE_SPACE_GB,
    "total_space_gb": $TOTAL_SPACE_GB,
    "disk_usage_pct": $DISK_USAGE_PCT,
    "disk_space_warning": $DISK_SPACE_WARNING
  },
  "status": "unknown"
}
EOF

# Evaluate health with improved detection
HEALTH_ISSUES=0
ALERT_SEVERITY="info"

# Check if node is in sync
if [ $BLOCKS_BEHIND -gt $MAX_BLOCKS_BEHIND ]; then
  echo "WARNING: Node is $BLOCKS_BEHIND blocks behind headers" | tee -a $LOG_FILE
  HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
  ALERT_SEVERITY="warning"
  
  # Check sync progress
  if (( $(echo "$VERIFICATION_PROGRESS < 0.999" | bc -l) )); then
    sed -i 's/"status": "unknown"/"status": "syncing"/' "$STATUS_FILE"
    SYNC_PERCENT=$(echo "$VERIFICATION_PROGRESS * 100" | bc -l | xargs printf "%.2f")
    echo "Node is syncing, $SYNC_PERCENT% complete" | tee -a $LOG_FILE
  else
    sed -i 's/"status": "unknown"/"status": "behind"/' "$STATUS_FILE"
  fi
  
  send_alert "node_behind" "Node is $BLOCKS_BEHIND blocks behind headers" "warning"
fi

# Check peer connections
if [ $CONNECTIONS -lt $MIN_PEERS ]; then
  echo "WARNING: Only $CONNECTIONS peer connections (minimum: $MIN_PEERS)" | tee -a $LOG_FILE
  HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
  ALERT_SEVERITY="warning"
  sed -i 's/"status": "unknown"/"status": "low_peers"/' "$STATUS_FILE"
  send_alert "low_peers" "Only $CONNECTIONS peer connections (minimum: $MIN_PEERS)" "warning"
fi

# Check mempool size
if [ $MEMPOOL_SIZE -gt $MAX_MEMPOOL_SIZE ]; then
  echo "WARNING: Mempool has $MEMPOOL_SIZE transactions (maximum: $MAX_MEMPOOL_SIZE)" | tee -a $LOG_FILE
  HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
  sed -i 's/"status": "unknown"/"status": "high_mempool"/' "$STATUS_FILE"
  send_alert "high_mempool" "Mempool has $MEMPOOL_SIZE transactions (maximum: $MAX_MEMPOOL_SIZE)" "warning"
fi

# Check mempool memory usage
MEMPOOL_USAGE_PCT=$(echo "scale=2; $MEMPOOL_USAGE * 100 / $MEMPOOL_MAX_MEM" | bc)
if (( $(echo "$MEMPOOL_USAGE_PCT > 90" | bc -l) )); then
  echo "WARNING: High mempool memory usage: ${MEMPOOL_USAGE_PCT}% of maximum" | tee -a $LOG_FILE
  HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
  send_alert "high_mempool_mem" "High mempool memory usage: ${MEMPOOL_USAGE_PCT}% of maximum" "warning"
fi

# Check disk space
if [ "$DISK_SPACE_WARNING" = "true" ]; then
  HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
  ALERT_SEVERITY="warning"
  sed -i 's/"status": "unknown"/"status": "low_disk_space"/' "$STATUS_FILE"
fi

# Check for stalled sync if enabled
if [ "$ALERT_ON_SYNC_STALLED" = "true" ] && [ $BLOCKS_BEHIND -gt 0 ]; then
  if [ -f "/tmp/meowcoin_last_block" ]; then
    LAST_BLOCK=$(cat /tmp/meowcoin_last_block)
    LAST_CHECK_TIME=$(cat /tmp/meowcoin_last_check_time 2>/dev/null || echo "0")
    CURRENT_TIME=$(date +%s)
    
    # Only check for stall if enough time has passed
    if [ $((CURRENT_TIME - LAST_CHECK_TIME)) -gt 300 ]; then
      if [ "$LAST_BLOCK" = "$BLOCKS" ]; then
        echo "WARNING: Sync appears stalled - block height hasn't changed since last check" | tee -a $LOG_FILE
        HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
        ALERT_SEVERITY="warning"
        sed -i 's/"status": "unknown"/"status": "sync_stalled"/' "$STATUS_FILE"
        send_alert "sync_stalled" "Sync appears stalled - block height hasn't changed since last check" "warning"
      fi
      
      # Update last check time
      echo "$CURRENT_TIME" > /tmp/meowcoin_last_check_time
    fi
  fi
  
  # Update last block
  echo "$BLOCKS" > /tmp/meowcoin_last_block
fi

# Check for unusual changes in metrics if anomaly detection enabled
if [ "$ANOMALY_DETECTION_ENABLED" = "true" ]; then
  # Check for unusual drop in peer count
  if detect_anomaly "connections" "$CONNECTIONS" "3.0"; then
    echo "WARNING: Unusual change in peer connections detected" | tee -a $LOG_FILE
    HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
    send_alert "peer_anomaly" "Unusual change in peer connections detected: $CONNECTIONS" "warning"
  fi
  
  # Check for unusual mempool growth
  if detect_anomaly "mempool_size" "$MEMPOOL_SIZE" "3.0"; then
    echo "WARNING: Unusual mempool growth detected" | tee -a $LOG_FILE
    HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
    send_alert "mempool_anomaly" "Unusual mempool growth detected: $MEMPOOL_SIZE transactions" "warning"
  fi
  
  # Check for unusual disk usage growth
  if detect_anomaly "disk_usage" "$DISK_USAGE_PCT" "2.0"; then
    echo "WARNING: Unusual disk usage growth detected" | tee -a $LOG_FILE
    HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
    send_alert "disk_anomaly" "Unusual disk usage growth detected: ${DISK_USAGE_PCT}%" "warning"
  fi
fi

# Check log file for error patterns
if [ -f "/home/meowcoin/.meowcoin/debug.log" ]; then
  # Check last 100 lines for critical errors
  ERROR_COUNT=$(tail -n 100 "/home/meowcoin/.meowcoin/debug.log" | grep -c -E "ERROR:|EXCEPTION:|core dumped|segmentation fault|fatal error")
  if [ $ERROR_COUNT -gt 0 ]; then
    echo "WARNING: Found $ERROR_COUNT error(s) in recent log entries" | tee -a $LOG_FILE
    HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
    ALERT_SEVERITY="warning"
    
    # Extract last error for alert
    LAST_ERROR=$(tail -n 100 "/home/meowcoin/.meowcoin/debug.log" | grep -E "ERROR:|EXCEPTION:|core dumped|segmentation fault|fatal error" | tail -1)
    send_alert "log_errors" "Found errors in logs: $LAST_ERROR" "warning"
  fi
fi

# Final health determination
if [ $HEALTH_ISSUES -eq 0 ]; then
  # Node is healthy
  sed -i 's/"status": "unknown"/"status": "healthy"/' "$STATUS_FILE"
  echo "Node is healthy: $BLOCKS blocks, $CONNECTIONS peers, $MEMPOOL_SIZE mempool transactions" | tee -a $LOG_FILE
  
  # Send periodic health status (if alerting enabled and not sent recently)
  if [ "${ENABLE_ALERTS:-true}" = "true" ] && [ "${PERIODIC_HEALTH_ALERTS:-true}" = "true" ]; then
    LAST_HEALTHY_ALERT=0
    if [ -f "$ALERT_HISTORY" ]; then
      LAST_HEALTHY_ALERT=$(jq -r '.healthy.timestamp // 0' "$ALERT_HISTORY")
    fi
    
    CURRENT_TIME=$(date +%s)
    if [ $((CURRENT_TIME - LAST_HEALTHY_ALERT)) -gt $((3600 * 24)) ]; then  # Once per day
      send_alert "healthy" "Node is healthy: $BLOCKS blocks, $CONNECTIONS peers, $MEMPOOL_SIZE mempool transactions" "info"
    fi
  fi
  
  exit 0
else
  # Node has issues
  echo "Node has $HEALTH_ISSUES health issues" | tee -a $LOG_FILE
  
  # If status is still unknown, set it based on severity
  if grep -q '"status": "unknown"' "$STATUS_FILE"; then
    if [ "$ALERT_SEVERITY" = "critical" ]; then
      sed -i 's/"status": "unknown"/"status": "critical"/' "$STATUS_FILE"
    else
      sed -i 's/"status": "unknown"/"status": "warning"/' "$STATUS_FILE"
    fi
  fi
  
  # Update status file with issue count
  sed -i "s/\"check_time\": \([0-9]*\)/\"check_time\": \1, \"issues\": $HEALTH_ISSUES/" "$STATUS_FILE"
  
  exit 1
fi