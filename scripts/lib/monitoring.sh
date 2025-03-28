#!/bin/bash
# Monitoring utilities for Meowcoin Docker
# Standardizes health checks, metrics collection, and alerting

# Source common utilities
source /usr/local/bin/lib/utils.sh

# Default paths
METRICS_DIR="${METRICS_DIR:-/var/lib/meowcoin/metrics}"
HISTORICAL_DATA="${HISTORICAL_DATA:-/var/lib/meowcoin/historical_data}"
STATUS_FILE="${STATUS_FILE:-/tmp/meowcoin_health_status.json}"
ALERT_HISTORY="${ALERT_HISTORY:-/var/lib/meowcoin/alert_history.json}"

# Initialize monitoring system
function init_monitoring() {
  # Create necessary directories
  mkdir -p "$METRICS_DIR"
  mkdir -p "$HISTORICAL_DATA"
  mkdir -p "$(dirname $STATUS_FILE)"
  mkdir -p "$(dirname $ALERT_HISTORY)"
  
  # Set correct permissions
  chmod 750 "$METRICS_DIR"
  chmod 750 "$HISTORICAL_DATA"
  
  log "Monitoring system initialized" "INFO"
}

# Check if node is running
function check_node_running() {
  # Check both meowcoind and meowcoin-qt (in case of GUI node)
  if ! pgrep -x "meowcoind" > /dev/null && ! pgrep -x "meowcoin-qt" > /dev/null; then
    log "Meowcoin daemon is not running" "ERROR"
    
    # Check for crash logs
    local CRASH_LOG=$(find /home/meowcoin/.meowcoin -name "core.*" -o -name "crash_*" -o -name "*.core" -o -name "*.dump" | sort -r | head -1)
    if [ ! -z "$CRASH_LOG" ]; then
      log "Found potential crash evidence: $CRASH_LOG" "ERROR"
      # Extract crash info if core dump tools available
      if command -v gdb >/dev/null 2>&1; then
        log "Crash analysis:" "ERROR"
        gdb -batch -ex "thread apply all bt" /usr/bin/meowcoind "$CRASH_LOG" 2>/dev/null | head -20 >> $LOG_FILE
      fi
    fi
    
    # Check recent logs for error patterns
    if [ -f "/home/meowcoin/.meowcoin/debug.log" ]; then
      log "Last 10 log entries before crash:" "ERROR"
      tail -n 10 "/home/meowcoin/.meowcoin/debug.log" >> $LOG_FILE
    fi
    
    # Write status file
    update_health_status "offline" "Daemon not running"
    
    # Send alert
    send_alert "node_offline" "Meowcoin daemon is not running" "critical"
    
    return 1
  fi
  
  return 0
}

# Check blockchain status
function check_blockchain_status() {
  # Execute RPC command
  local BLOCKCHAIN_INFO=$(execute_rpc "getblockchaininfo")
  if [ $? -ne 0 ]; then
    log "Cannot get blockchain info from node" "ERROR"
    update_health_status "error" "Cannot get blockchain info"
    send_alert "rpc_error" "Cannot connect to RPC API" "critical"
    return 1
  fi
  
  # Extract blockchain data
  local BLOCKS=$(extract_json_value "$BLOCKCHAIN_INFO" "blocks" "0")
  local HEADERS=$(extract_json_value "$BLOCKCHAIN_INFO" "headers" "0")
  local VERIFICATION_PROGRESS=$(extract_json_value "$BLOCKCHAIN_INFO" "verificationprogress" "0")
  local CHAIN=$(extract_json_value "$BLOCKCHAIN_INFO" "chain" "unknown")
  
  # Calculate blocks behind
  local BLOCKS_BEHIND=$((HEADERS - BLOCKS))
  
  # Record metrics
  record_metric "blocks" "$BLOCKS"
  record_metric "headers" "$HEADERS"
  record_metric "blocks_behind" "$BLOCKS_BEHIND"
  record_metric "verification_progress" "$VERIFICATION_PROGRESS"
  
  # Set global variables for other functions
  export BLOCKS="$BLOCKS"
  export HEADERS="$HEADERS"
  export BLOCKS_BEHIND="$BLOCKS_BEHIND"
  export VERIFICATION_PROGRESS="$VERIFICATION_PROGRESS"
  export CHAIN="$CHAIN"
  
  # Check for sync stalls
  if [ -f "/tmp/meowcoin_last_block" ]; then
    local LAST_BLOCK=$(cat /tmp/meowcoin_last_block)
    local CURRENT_TIME=$(date +%s)
    
    if [ "$BLOCKS" = "$LAST_BLOCK" ] && [ $BLOCKS_BEHIND -gt 1 ]; then
      # Check if we have a last check time
      if [ -f "/tmp/meowcoin_last_check_time" ]; then
        local LAST_CHECK_TIME=$(cat /tmp/meowcoin_last_check_time)
        local STALL_TIME=$((CURRENT_TIME - LAST_CHECK_TIME))
        
        # If stalled for more than 30 minutes
        if [ $STALL_TIME -gt 1800 ]; then
          log "Blockchain appears stalled at block $BLOCKS for $STALL_TIME seconds" "WARNING"
          send_alert "sync_stalled" "Blockchain sync stalled for $(($STALL_TIME / 60)) minutes" "warning"
          
          # Check for stalled sync validation
          if [ -f "/tmp/meowcoin_last_verification" ]; then
            local LAST_VERIFICATION=$(cat /tmp/meowcoin_last_verification)
            if (( $(echo "$VERIFICATION_PROGRESS - $LAST_VERIFICATION < 0.0001" | bc -l) )); then
              log "Verification progress also stalled" "WARNING"
              send_alert "sync_frozen" "Blockchain verification appears frozen" "critical"
            fi
          fi
        fi
      fi
    }
    
    # Update last check time and values
    echo "$CURRENT_TIME" > /tmp/meowcoin_last_check_time
    echo "$VERIFICATION_PROGRESS" > /tmp/meowcoin_last_verification
  fi
  
  # Update last block
  echo "$BLOCKS" > /tmp/meowcoin_last_block
  
  return 0
}

# Check network status
function check_network_status() {
  # Check network info
  local NETWORK_INFO=$(execute_rpc getnetworkinfo)
  if [ $? -ne 0 ]; then
    log "Cannot get network info from node" "ERROR"
    update_health_status "error" "Cannot get network info"
    send_alert "network_info_error" "Cannot retrieve network information" "warning"
    return 1
  fi
  
  # Extract network data
  local CONNECTIONS=$(extract_json_value "$NETWORK_INFO" "connections" "0")
  local VERSION=$(extract_json_value "$NETWORK_INFO" "version" "0")
  local SUBVERSION=$(extract_json_value "$NETWORK_INFO" "subversion" "unknown")
  local PROTOCOL_VERSION=$(extract_json_value "$NETWORK_INFO" "protocolversion" "0")
  
  # Record network metrics
  record_metric "connections" "$CONNECTIONS"
  
  # Set global variables for other functions
  export CONNECTIONS="$CONNECTIONS"
  export VERSION="$VERSION"
  export SUBVERSION="$SUBVERSION"
  export PROTOCOL_VERSION="$PROTOCOL_VERSION"
  
  # Get uptime information
  local UPTIME_INFO=$(execute_rpc uptime)
  if [ $? -eq 0 ]; then
    record_metric "node_uptime" "$UPTIME_INFO"
  fi
  
  # Analyze connected peers
  if [ $CONNECTIONS -gt 0 ]; then
    # Get detailed peer info
    local PEER_INFO=$(execute_rpc getpeerinfo)
    if [ $? -eq 0 ]; then
      # Count inbound vs outbound connections
      if command -v jq >/dev/null 2>&1; then
        local INBOUND=$(echo "$PEER_INFO" | jq '[.[] | select(.inbound == true)] | length')
        local OUTBOUND=$(echo "$PEER_INFO" | jq '[.[] | select(.inbound == false)] | length')
        
        # Check connection distribution
        record_metric "inbound_connections" "$INBOUND"
        record_metric "outbound_connections" "$OUTBOUND"
        
        if [ $INBOUND -eq 0 ]; then
          log "No inbound connections - check port forwarding" "WARNING"
          send_alert "no_inbound" "No inbound connections - check port forwarding" "warning"
        fi
        
        if [ $OUTBOUND -eq 0 ]; then
          log "No outbound connections - check firewall/network" "WARNING"
          send_alert "no_outbound" "No outbound connections - check firewall/network" "warning"
        fi
        
        # Check for banned peers
        local BANNED_INFO=$(execute_rpc listbanned)
        if [ $? -eq 0 ]; then
          local BANNED_COUNT=$(echo "$BANNED_INFO" | jq '. | length')
          record_metric "banned_peers" "$BANNED_COUNT"
          
          if [ $BANNED_COUNT -gt 10 ]; then
            log "High number of banned peers: $BANNED_COUNT" "WARNING"
            send_alert "high_banned" "High number of banned peers: $BANNED_COUNT" "warning"
          fi
        fi
      fi
    fi
  fi
  
  return 0
}

# Check mempool status
function check_mempool_status() {
  # Check mempool info
  local MEMPOOL_INFO=$(execute_rpc getmempoolinfo)
  if [ $? -ne 0 ]; then
    log "Cannot get mempool info from node" "ERROR"
    update_health_status "error" "Cannot get mempool info"
    send_alert "mempool_info_error" "Cannot retrieve mempool information" "warning"
    return 1
  fi
  
  # Extract mempool data
  local MEMPOOL_SIZE=$(extract_json_value "$MEMPOOL_INFO" "size" "0")
  local MEMPOOL_BYTES=$(extract_json_value "$MEMPOOL_INFO" "bytes" "0")
  local MEMPOOL_USAGE=$(extract_json_value "$MEMPOOL_INFO" "usage" "0")
  local MEMPOOL_MAX_MEM=$(extract_json_value "$MEMPOOL_INFO" "maxmempool" "300000000")
  
  # Record metrics
  record_metric "mempool_size" "$MEMPOOL_SIZE"
  record_metric "mempool_bytes" "$MEMPOOL_BYTES"
  record_metric "mempool_usage" "$MEMPOOL_USAGE"
  
  # Set global variables for other functions
  export MEMPOOL_SIZE="$MEMPOOL_SIZE"
  export MEMPOOL_BYTES="$MEMPOOL_BYTES"
  export MEMPOOL_USAGE="$MEMPOOL_USAGE"
  export MEMPOOL_MAX_MEM="$MEMPOOL_MAX_MEM"
  
  return 0
}

# Check system resources
function check_system_resources() {
  # Check disk space
  if [ "${CHECK_DISK_SPACE:-true}" = "true" ]; then
    local AVAILABLE_SPACE_KB=$(df -k /home/meowcoin/.meowcoin | tail -1 | awk '{print $4}')
    local AVAILABLE_SPACE_GB=$((AVAILABLE_SPACE_KB / 1024 / 1024))
    local TOTAL_SPACE_KB=$(df -k /home/meowcoin/.meowcoin | tail -1 | awk '{print $2}')
    local TOTAL_SPACE_GB=$((TOTAL_SPACE_KB / 1024 / 1024))
    local USED_SPACE_KB=$((TOTAL_SPACE_KB - AVAILABLE_SPACE_KB))
    local DISK_USAGE_PCT=$((USED_SPACE_KB * 100 / TOTAL_SPACE_KB))
    
    # Record metrics
    record_metric "disk_usage" "$DISK_USAGE_PCT"
    record_metric "disk_available_gb" "$AVAILABLE_SPACE_GB"
    record_metric "disk_total_gb" "$TOTAL_SPACE_GB"
    
    # Set global variables for other functions
    export AVAILABLE_SPACE_GB="$AVAILABLE_SPACE_GB"
    export TOTAL_SPACE_GB="$TOTAL_SPACE_GB"
    export DISK_USAGE_PCT="$DISK_USAGE_PCT"
    
    local MIN_FREE_SPACE_GB="${MIN_FREE_SPACE_GB:-5}"
    if [ $AVAILABLE_SPACE_GB -lt $MIN_FREE_SPACE_GB ]; then
      log "Low disk space: ${AVAILABLE_SPACE_GB}GB available (minimum: ${MIN_FREE_SPACE_GB}GB)" "WARNING"
      send_alert "low_disk_space" "Low disk space: ${AVAILABLE_SPACE_GB}GB available (minimum: ${MIN_FREE_SPACE_GB}GB)" "warning"
    fi
    
    # Check inode usage too (can be a hidden problem)
    local INODE_USAGE_PCT=$(df -i /home/meowcoin/.meowcoin | tail -1 | awk '{print $5}' | tr -d '%')
    record_metric "inode_usage" "$INODE_USAGE_PCT"
    
    if [ $INODE_USAGE_PCT -gt 90 ]; then
      log "High inode usage: ${INODE_USAGE_PCT}% (can prevent new file creation)" "WARNING"
      send_alert "high_inode_usage" "High inode usage: ${INODE_USAGE_PCT}% (can prevent new file creation)" "warning"
    fi
  fi
  
  # Check CPU usage
  if command -v top >/dev/null 2>&1; then
    local CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    record_metric "cpu_usage" "$CPU_USAGE"
    
    # Set global variables for other functions
    export CPU_USAGE="$CPU_USAGE"
    
    local MAX_CPU_USAGE="${MAX_CPU_USAGE:-90}"
    if [ $(echo "$CPU_USAGE > $MAX_CPU_USAGE" | bc -l) -eq 1 ]; then
      log "High CPU usage: ${CPU_USAGE}% (threshold: ${MAX_CPU_USAGE}%)" "WARNING"
      send_alert "high_cpu" "High CPU usage: ${CPU_USAGE}% (threshold: ${MAX_CPU_USAGE}%)" "warning"
    fi
  fi
  
  # Check memory usage
  if command -v free >/dev/null 2>&1; then
    local MEMORY_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    record_metric "memory_usage" "$MEMORY_USAGE"
    
    # Set global variables for other functions
    export MEMORY_USAGE="$MEMORY_USAGE"
    
    local MAX_MEMORY_USAGE="${MAX_MEMORY_USAGE:-90}"
    if [ $(echo "$MEMORY_USAGE > $MAX_MEMORY_USAGE" | bc -l) -eq 1 ]; then
      log "High memory usage: ${MEMORY_USAGE}% (threshold: ${MAX_MEMORY_USAGE}%)" "WARNING"
      send_alert "high_memory" "High memory usage: ${MEMORY_USAGE}% (threshold: ${MAX_MEMORY_USAGE}%)" "warning"
    fi
  fi
  
  return 0
}

# Detect anomalies in metrics
function detect_anomalies() {
  # Skip if anomaly detection is not enabled
  if [ "${ANOMALY_DETECTION_ENABLED:-false}" != "true" ]; then
    return 0
  fi
  
  log "Running anomaly detection" "INFO"
  
  # Check for unusual peer count change
  detect_metric_anomaly "connections" "$CONNECTIONS" "3.0" "peer_anomaly" "Unusual change in peer connections detected: $CONNECTIONS"
  
  # Check for unusual mempool growth
  detect_metric_anomaly "mempool_size" "$MEMPOOL_SIZE" "3.0" "mempool_anomaly" "Unusual mempool growth detected: $MEMPOOL_SIZE transactions"
  
  # Check for unusual disk usage growth
  detect_metric_anomaly "disk_usage" "$DISK_USAGE_PCT" "2.0" "disk_anomaly" "Unusual disk usage growth detected: ${DISK_USAGE_PCT}%"
  
  # Check for CPU anomalies
  detect_metric_anomaly "cpu_usage" "$CPU_USAGE" "2.5" "cpu_anomaly" "Unusual CPU usage pattern detected: ${CPU_USAGE}%"
  
  # Check for memory anomalies
  detect_metric_anomaly "memory_usage" "$MEMORY_USAGE" "2.5" "memory_anomaly" "Unusual memory usage pattern detected: ${MEMORY_USAGE}%"
  
  # Look for trend anomalies
  detect_trend_anomaly "disk_usage" "disk_trend" "Disk usage showing significant trend"
  detect_trend_anomaly "cpu_usage" "cpu_trend" "CPU usage showing significant trend"
  
  return 0
}

# Detect anomaly in a specific metric
function detect_metric_anomaly() {
  local METRIC_NAME="$1"
  local CURRENT_VALUE="$2"
  local THRESHOLD="$3"
  local ALERT_TYPE="$4"
  local ALERT_MESSAGE="$5"
  local HISTORY_FILE="$HISTORICAL_DATA/${METRIC_NAME}.data"
  
  # Need at least 10 data points for anomaly detection
  if [ ! -f "$HISTORY_FILE" ] || [ $(wc -l < "$HISTORY_FILE") -lt 10 ]; then
    return 1  # Not enough data
  fi
  
  # Calculate mean and standard deviation
  local MEAN=$(awk '{sum+=$2} END {print sum/NR}' "$HISTORY_FILE")
  local STDDEV=$(awk -v mean=$MEAN '{sum+=($2-mean)^2} END {print sqrt(sum/NR)}' "$HISTORY_FILE")
  
  # Check for division by zero or very small stddev
  if [ $(echo "$STDDEV < 0.0001" | bc -l) -eq 1 ]; then
    return 1  # Can't reliably detect anomalies with near-zero variance
  fi
  
  # Calculate z-score (number of std devs from mean)
  local ZSCORE=$(echo "scale=2; ($CURRENT_VALUE - $MEAN) / $STDDEV" | bc -l)
  
  # Record the z-score
  record_metric "${METRIC_NAME}_zscore" "$ZSCORE" "gauge"
  
  # Check if value is anomalous (beyond threshold standard deviations)
  if (( $(echo "sqrt($ZSCORE * $ZSCORE) > $THRESHOLD" | bc -l) )); then
    log "ANOMALY DETECTED: $METRIC_NAME current=$CURRENT_VALUE mean=$MEAN stddev=$STDDEV zscore=$ZSCORE" "WARNING"
    send_alert "$ALERT_TYPE" "$ALERT_MESSAGE" "warning"
    return 0  # Anomaly detected
  fi
  
  return 1  # No anomaly
}

# Detect trend anomaly
function detect_trend_anomaly() {
  local METRIC_NAME="$1"
  local ALERT_TYPE="$2"
  local ALERT_MESSAGE="$3"
  local HISTORY_FILE="$HISTORICAL_DATA/${METRIC_NAME}.data"
  
  # Need at least 10 data points
  if [ ! -f "$HISTORY_FILE" ] || [ $(wc -l < "$HISTORY_FILE") -lt 10 ]; then
    return 1
  fi
  
  # Get last 10 measurements
  local RECENT_DATA=$(tail -n 10 "$HISTORY_FILE")
  
  # Calculate trend using linear regression slope
  local SLOPE=$(echo "$RECENT_DATA" | awk '
    BEGIN { x_sum=0; y_sum=0; xy_sum=0; x2_sum=0; n=0; }
    { 
      x[n] = n+1; 
      y[n] = $2; 
      x_sum += x[n]; 
      y_sum += y[n]; 
      xy_sum += x[n]*y[n]; 
      x2_sum += x[n]*x[n];
      n++;
    } 
    END {
      slope = (n*xy_sum - x_sum*y_sum) / (n*x2_sum - x_sum*x_sum);
      print slope;
    }')
  
  # Normalize slope based on mean value to get percent change
  local MEAN=$(echo "$RECENT_DATA" | awk '{sum+=$2} END {print sum/NR}')
  local PERCENT_CHANGE=$(echo "scale=2; $SLOPE * 10 / $MEAN * 100" | bc -l)
  
  # Record the trend data
  record_metric "${METRIC_NAME}_trend" "$PERCENT_CHANGE" "gauge"
  
  # Detect significant trends (configurable thresholds)
  local TREND_THRESHOLD="${TREND_THRESHOLD:-5}"  # Default 5% change over 10 points
  
  if (( $(echo "sqrt($PERCENT_CHANGE * $PERCENT_CHANGE) > $TREND_THRESHOLD" | bc -l) )); then
    local DIRECTION=$([ $(echo "$PERCENT_CHANGE > 0" | bc -l) -eq 1 ] && echo "increasing" || echo "decreasing")
    log "TREND ANOMALY: $METRIC_NAME showing significant $DIRECTION trend ($PERCENT_CHANGE% per 10 points)" "WARNING"
    send_alert "$ALERT_TYPE" "$ALERT_MESSAGE" "warning"
    return 0  # Trend anomaly detected
  fi
  
  return 1  # No trend anomaly
}

# Send alert with tracing and deduplication
function send_alert() {
  local ALERT_TYPE="$1"
  local MESSAGE="$2"
  local SEVERITY="${3:-warning}"
  
  # Check if alerts are enabled
  if [ "${ENABLE_ALERTS:-true}" != "true" ]; then
    log "Alert suppressed (alerts disabled): $ALERT_TYPE - $MESSAGE" "DEBUG"
    return
  fi
  
  # Check for alert cooldown
  if [ -f "$ALERT_HISTORY" ]; then
    local LAST_ALERT_TIME=$(jq -r ".[\"$ALERT_TYPE\"].timestamp // 0" "$ALERT_HISTORY")
    local CURRENT_TIME=$(date +%s)
    
    if [ $((CURRENT_TIME - LAST_ALERT_TIME)) -lt ${ALERT_COOLDOWN:-3600} ]; then
      log "Alert suppressed (cooldown): $ALERT_TYPE - $MESSAGE" "DEBUG"
      return
    fi
  fi
  
  log "ALERT [$SEVERITY]: $MESSAGE" "WARNING"
  
  # Record this alert
  mkdir -p "$(dirname "$ALERT_HISTORY")"
  if [ ! -f "$ALERT_HISTORY" ]; then
    echo "{}" > "$ALERT_HISTORY"
  fi
  
  # Update alert history
  local TIMESTAMP=$(date +%s)
  local TEMP_FILE=$(mktemp)
  jq --arg type "$ALERT_TYPE" \
     --arg timestamp "$TIMESTAMP" \
     --arg message "$MESSAGE" \
     --arg severity "$SEVERITY" \
     --arg trace_id "$TRACE_ID" \
     '.[$type] = {"timestamp": $timestamp|tonumber, "message": $message, "severity": $severity, "trace_id": $trace_id}' \
     "$ALERT_HISTORY" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$ALERT_HISTORY"
  
  # Send via configured alert method (check if send-alert.sh exists)
  if [ -x /usr/local/bin/monitoring/send-alert.sh ]; then
    /usr/local/bin/monitoring/send-alert.sh "$MESSAGE" "$ALERT_TYPE" "$SEVERITY"
  fi
  
  # Record alert in metrics
  record_metric "alerts_total" "1" "counter"
  record_metric "alert_${SEVERITY}_total" "1" "counter"
  record_metric "alert_${ALERT_TYPE}_total" "1" "counter"
  
  return 0
}

# Update health status file
function update_health_status() {
  local STATUS="$1"
  local ERROR_MESSAGE="$2"
  
  # Create a well-structured JSON status file
  cat > "$STATUS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "trace_id": "$TRACE_ID",
  "check_time": $(date +%s),
  "status": "$STATUS",
  $([ ! -z "$ERROR_MESSAGE" ] && echo "\"error\": \"$ERROR_MESSAGE\",")
  "blockchain": {
    "blocks": ${BLOCKS:-0},
    "headers": ${HEADERS:-0},
    "blocks_behind": ${BLOCKS_BEHIND:-0},
    "verification_progress": ${VERIFICATION_PROGRESS:-0},
    "chain": "${CHAIN:-unknown}"
  },
  "network": {
    "connections": ${CONNECTIONS:-0},
    "version": ${VERSION:-0},
    "subversion": "${SUBVERSION:-unknown}",
    "protocol_version": ${PROTOCOL_VERSION:-0}
  },
  "mempool": {
    "transactions": ${MEMPOOL_SIZE:-0},
    "bytes": ${MEMPOOL_BYTES:-0},
    "usage": ${MEMPOOL_USAGE:-0},
    "max_mem": ${MEMPOOL_MAX_MEM:-0}
  },
  "system": {
    "disk_space_gb": ${AVAILABLE_SPACE_GB:-0},
    "total_space_gb": ${TOTAL_SPACE_GB:-0},
    "disk_usage_pct": ${DISK_USAGE_PCT:-0},
    "cpu_usage_pct": ${CPU_USAGE:-0},
    "memory_usage_pct": ${MEMORY_USAGE:-0}
  }
}
EOF
}

# Function to execute RPC commands with retry and timeout
function execute_rpc() {
  local CMD="$1"
  shift
  local MAX_ATTEMPTS=3
  local ATTEMPT=1
  local AUTH=$(get_rpc_auth)
  
  while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    # Execute with timeout (separately capture stdout and stderr)
    local TEMP_OUT=$(mktemp)
    local TEMP_ERR=$(mktemp)
    
    if timeout ${RPC_TIMEOUT_SECONDS:-5} meowcoin-cli $AUTH $CMD "$@" > "$TEMP_OUT" 2> "$TEMP_ERR"; then
      local RESULT=$(cat "$TEMP_OUT")
      rm -f "$TEMP_OUT" "$TEMP_ERR"
      echo "$RESULT"
      return 0
    else
      local EXIT_CODE=$?
      local ERROR=$(cat "$TEMP_ERR")
      rm -f "$TEMP_OUT" "$TEMP_ERR"
      
      # Check for specific error types
      if [[ "$ERROR" == *"Connection refused"* ]]; then
        log "RPC connection refused (attempt $ATTEMPT/$MAX_ATTEMPTS)" "WARNING"
      elif [[ "$ERROR" == *"Timeout"* || $EXIT_CODE -eq 124 ]]; then
        log "RPC command timed out (attempt $ATTEMPT/$MAX_ATTEMPTS)" "WARNING"
      elif [[ "$ERROR" == *"incorrect password"* || "$ERROR" == *"unauthorized"* ]]; then
        log "RPC authentication failed" "ERROR"
        send_alert "rpc_auth" "RPC authentication failed" "critical"
        return 1
      else
        log "RPC command failed: $CMD (attempt $ATTEMPT/$MAX_ATTEMPTS): $ERROR" "WARNING"
      fi
      
      if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        log "All RPC attempts failed for command: $CMD" "ERROR"
        return $EXIT_CODE
      fi
      
      # Use exponential backoff
      local DELAY=$(( 2 ** (ATTEMPT - 1) ))
      log "Retrying in $DELAY seconds..." "DEBUG"
      sleep $DELAY
      ATTEMPT=$((ATTEMPT + 1))
    fi
  done
  
  return 1
}

# Helper function to get RPC credentials with JWT support
function get_rpc_auth() {
  local CONFIG_FILE="/home/meowcoin/.meowcoin/meowcoin.conf"
  
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
  
  if [ -z "$USER" ] || [ -z "$PASS" ]; then
    # Fallback to password file if config doesn't have credentials
    if [ -f "/home/meowcoin/.meowcoin/.rpcpassword" ]; then
      USER="meowcoin"
      PASS=$(cat "/home/meowcoin/.meowcoin/.rpcpassword")
    else
      log "Cannot find RPC credentials" "ERROR"
      send_alert "rpc_credentials" "RPC credentials not found" "critical"
      return 1
    fi
  fi
  
  echo "-rpcuser=$USER -rpcpassword=$PASS"
}

# Function to assess overall health status
function evaluate_health_status() {
  # Default thresholds
  local MAX_BLOCKS_BEHIND="${MAX_BLOCKS_BEHIND:-6}"
  local MIN_PEERS="${MIN_PEERS:-3}"
  local MAX_MEMPOOL_SIZE="${MAX_MEMPOOL_SIZE:-300}"
  local MIN_FREE_SPACE_GB="${MIN_FREE_SPACE_GB:-5}"
  
  # Count health issues
  local HEALTH_ISSUES=0
  local ALERT_SEVERITY="info"
  local STATUS="healthy"
  
  # Check if node is in sync
  if [ $BLOCKS_BEHIND -gt $MAX_BLOCKS_BEHIND ]; then
    log "Node is $BLOCKS_BEHIND blocks behind headers" "WARNING"
    HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
    ALERT_SEVERITY="warning"
    
    # Check sync progress
    if (( $(echo "$VERIFICATION_PROGRESS < 0.999" | bc -l) )); then
      STATUS="syncing"
      SYNC_PERCENT=$(echo "$VERIFICATION_PROGRESS * 100" | bc -l | xargs printf "%.2f")
      log "Node is syncing, $SYNC_PERCENT% complete" "INFO"
    else
      STATUS="behind"
    fi
    
    send_alert "node_behind" "Node is $BLOCKS_BEHIND blocks behind headers" "warning"
  fi
  
  # Check peer connections
  if [ $CONNECTIONS -lt $MIN_PEERS ]; then
    log "Only $CONNECTIONS peer connections (minimum: $MIN_PEERS)" "WARNING"
    HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
    ALERT_SEVERITY="warning"
    [ "$STATUS" = "healthy" ] && STATUS="low_peers"
    send_alert "low_peers" "Only $CONNECTIONS peer connections (minimum: $MIN_PEERS)" "warning"
  fi
  
  # Check mempool size
  if [ $MEMPOOL_SIZE -gt $MAX_MEMPOOL_SIZE ]; then
    log "Mempool has $MEMPOOL_SIZE transactions (maximum: $MAX_MEMPOOL_SIZE)" "WARNING"
    HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
    [ "$STATUS" = "healthy" ] && STATUS="high_mempool"
    send_alert "high_mempool" "Mempool has $MEMPOOL_SIZE transactions (maximum: $MAX_MEMPOOL_SIZE)" "warning"
  fi
  
  # Check mempool memory usage
  MEMPOOL_USAGE_PCT=$(echo "scale=2; $MEMPOOL_USAGE * 100 / $MEMPOOL_MAX_MEM" | bc)
  if (( $(echo "$MEMPOOL_USAGE_PCT > 90" | bc -l) )); then
    log "High mempool memory usage: ${MEMPOOL_USAGE_PCT}% of maximum" "WARNING"
    HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
    send_alert "high_mempool_mem" "High mempool memory usage: ${MEMPOOL_USAGE_PCT}% of maximum" "warning"
  fi
  
  # Check disk space
  if [ $AVAILABLE_SPACE_GB -lt $MIN_FREE_SPACE_GB ]; then
    log "Low disk space: $AVAILABLE_SPACE_GB GB available (minimum: $MIN_FREE_SPACE_GB GB)" "WARNING"
    HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
    ALERT_SEVERITY="warning"
    [ "$STATUS" = "healthy" ] && STATUS="low_disk"
  fi
  
  # Update status file with finalized health assessment
  update_health_status "$STATUS" ""
  
  # Add issue count to status file if unhealthy
  if [ $HEALTH_ISSUES -gt 0 ]; then
    jq --arg issues "$HEALTH_ISSUES" '.issues = ($issues|tonumber)' "$STATUS_FILE" > "${STATUS_FILE}.tmp"
    mv "${STATUS_FILE}.tmp" "$STATUS_FILE" 
  fi
  
  # Log final health assessment
  if [ $HEALTH_ISSUES -eq 0 ]; then
    log "Node is healthy: $BLOCKS blocks, $CONNECTIONS peers, $MEMPOOL_SIZE mempool transactions" "INFO"
  else
    log "Node has $HEALTH_ISSUES health issues" "WARNING"
  fi
  
  return $HEALTH_ISSUES
}

# Run a complete health check
function run_health_check() {
  log "Starting health check (trace ID: $TRACE_ID)" "INFO"
  
  # Initialize status variables
  BLOCKS=0
  HEADERS=0
  BLOCKS_BEHIND=0
  VERIFICATION_PROGRESS=0
  CHAIN="unknown"
  CONNECTIONS=0
  VERSION=0
  SUBVERSION="unknown"
  PROTOCOL_VERSION=0
  MEMPOOL_SIZE=0
  MEMPOOL_BYTES=0
  MEMPOOL_USAGE=0
  MEMPOOL_MAX_MEM=0
  AVAILABLE_SPACE_GB=0
  TOTAL_SPACE_GB=0
  DISK_USAGE_PCT=0
  CPU_USAGE=0
  MEMORY_USAGE=0
  
  # Make sure the node is running first
  if ! check_node_running; then
    return 1
  fi
  
  # Check blockchain status
  if ! check_blockchain_status; then
    log "Blockchain status check failed" "ERROR"
  fi
  
  # Check network status
  if ! check_network_status; then
    log "Network status check failed" "ERROR"
  fi
  
  # Check mempool status
  if ! check_mempool_status; then
    log "Mempool status check failed" "ERROR"
  fi
  
  # Check system resources
  if ! check_system_resources; then
    log "System resource check failed" "ERROR"
  fi
  
  # Run anomaly detection if enabled
  if [ "${ANOMALY_DETECTION_ENABLED:-true}" = "true" ]; then
    detect_anomalies
  fi
  
  # Evaluate final health status
  evaluate_health_status
  
  log "Health check completed" "INFO"
  return 0
}

# Export functions for use in other scripts
export -f init_monitoring
export -f check_node_running
export -f check_blockchain_status
export -f check_network_status
export -f check_mempool_status
export -f check_system_resources
export -f detect_anomalies
export -f detect_metric_anomaly
export -f detect_trend_anomaly
export -f send_alert
export -f update_health_status
export -f execute_rpc
export -f get_rpc_auth
export -f evaluate_health_status
export -f run_health_check