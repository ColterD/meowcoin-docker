# scripts/core/monitor.sh
#!/bin/bash
# Unified monitoring system for Meowcoin Docker

# Source core utilities
source /usr/local/bin/core/utils.sh

# Global monitoring variables
METRICS_DIR="/var/lib/meowcoin/metrics"
HISTORICAL_DATA="/var/lib/meowcoin/historical_data"
STATUS_FILE="/tmp/meowcoin_health_status.json"
ALERT_HISTORY="/var/lib/meowcoin/alert_history.json"

# Initialize monitoring system
function init_monitoring() {
  mkdir -p "$METRICS_DIR" "$HISTORICAL_DATA" "$(dirname $STATUS_FILE)" "$(dirname $ALERT_HISTORY)"
  chmod 750 "$METRICS_DIR" "$HISTORICAL_DATA"
  chown meowcoin:meowcoin "$METRICS_DIR" "$HISTORICAL_DATA"
  
  log "Monitoring system initialized" "INFO"
  return 0
}

# Initialize status variables
function init_status_variables() {
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
  NETWORK_OK=true
}

# Comprehensive health check that integrates all previously fragmented checks
function run_health_check() {
  log "Starting health check (trace ID: $TRACE_ID)" "INFO"
  
  # Initialize status variables
  init_status_variables
  
  # Check daemon is running
  if ! check_node_running; then
    return 1
  fi
  
  # Run all checks in sequence
  check_blockchain_status
  check_network_status
  check_mempool_status
  check_system_resources
  
  if [ "${ANOMALY_DETECTION_ENABLED:-true}" = "true" ]; then
    detect_anomalies
  fi
  
  # Evaluate final health status
  evaluate_health_status
  
  log "Health check completed" "INFO"
  return 0
}

# Check if node is running with enhanced detection
function check_node_running() {
  # Process detection with multiple methods for reliability
  if ! pgrep -x "meowcoind" > /dev/null && ! pgrep -x "meowcoin-qt" > /dev/null && ! pidof meowcoind > /dev/null; then
    log "Meowcoin daemon is not running" "ERROR"
    handle_node_offline
    return 1
  fi
  return 0
}

# Handle offline node
function handle_node_offline() {
  # Check for crash logs
  local CRASH_LOG=$(find /home/meowcoin/.meowcoin -name "core.*" -o -name "crash_*" -o -name "*.core" -o -name "*.dump" | sort -r | head -1)
  if [ ! -z "$CRASH_LOG" ]; then
    log "Found potential crash evidence: $CRASH_LOG" "ERROR"
    # Extract crash info if core dump tools available
    if command -v gdb >/dev/null 2>&1; then
      log "Crash analysis:" "ERROR"
      gdb -batch -ex "thread apply all bt" /usr/bin/meowcoind "$CRASH_LOG" 2>/dev/null | head -20 | while read line; do
        log "  $line" "ERROR"
      done
    fi
  fi
  
  # Check recent logs for error patterns
  if [ -f "/home/meowcoin/.meowcoin/debug.log" ]; then
    log "Last 10 log entries before crash:" "ERROR"
    tail -n 10 "/home/meowcoin/.meowcoin/debug.log" | while read line; do
      log "  $line" "ERROR"
    done
  fi
  
  # Write status file
  update_health_status "offline" "Daemon not running"
  
  # Send alert
  send_alert "node_offline" "Meowcoin daemon is not running" "critical"
}

# Enhanced blockchain status check with stall detection
function check_blockchain_status() {
  # Comprehensive blockchain information check
  local BLOCKCHAIN_INFO=$(execute_rpc getblockchaininfo)
  if [ $? -ne 0 ]; then
    handle_rpc_error "Cannot get blockchain info"
    return 1
  fi
  
  # Extract and record key metrics
  extract_blockchain_metrics "$BLOCKCHAIN_INFO"
  
  # Perform stall detection with improved algorithm
  detect_blockchain_stalls
  
  return 0
}

# Handle RPC errors
function handle_rpc_error() {
  local ERROR_MSG="$1"
  
  log "$ERROR_MSG" "ERROR"
  
  # Check for specific RPC issues
  if execute_rpc -getinfo 2>&1 | grep -q "Connection refused"; then
    log "RPC connection refused - check if RPC server is running and accessible" "ERROR"
    send_alert "rpc_connection" "RPC connection refused" "critical"
  elif execute_rpc -getinfo 2>&1 | grep -q "incorrect password"; then
    log "RPC authentication failed - check credentials" "ERROR"
    send_alert "rpc_auth" "RPC authentication failed" "critical"
  else
    log "Unknown RPC error, node may be starting or under heavy load" "ERROR"
    send_alert "rpc_error" "Cannot connect to RPC API" "critical"
  fi
  
  # Write status file
  update_health_status "error" "$ERROR_MSG"
}

# Extract blockchain metrics from JSON response
function extract_blockchain_metrics() {
  local BLOCKCHAIN_INFO="$1"
  
  # Extract core blockchain data
  BLOCKS=$(extract_json_value "$BLOCKCHAIN_INFO" "blocks" "0")
  HEADERS=$(extract_json_value "$BLOCKCHAIN_INFO" "headers" "0")
  VERIFICATION_PROGRESS=$(extract_json_value "$BLOCKCHAIN_INFO" "verificationprogress" "0")
  CHAIN=$(extract_json_value "$BLOCKCHAIN_INFO" "chain" "unknown")
  
  # Calculate blocks behind
  BLOCKS_BEHIND=$((HEADERS - BLOCKS))
  
  # Record metrics
  record_metric "blocks" "$BLOCKS"
  record_metric "headers" "$HEADERS"
  record_metric "blocks_behind" "$BLOCKS_BEHIND"
  record_metric "verification_progress" "$VERIFICATION_PROGRESS"
  
  # Get difficulty metrics
  local DIFFICULTY=$(extract_json_value "$BLOCKCHAIN_INFO" "difficulty" "0")
  record_metric "difficulty" "$DIFFICULTY"
  
  # Get size metrics if available
  local SIZE_ON_DISK=$(extract_json_value "$BLOCKCHAIN_INFO" "size_on_disk" "0")
  if [ "$SIZE_ON_DISK" != "0" ]; then
    local SIZE_GB=$(echo "scale=2; $SIZE_ON_DISK / 1024 / 1024 / 1024" | bc)
    record_metric "blockchain_size_gb" "$SIZE_GB"
  fi
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
  
  # Update status file with final assessment
  update_health_status "$STATUS" ""
  
  # Add issue count to status file if unhealthy
  if [ $HEALTH_ISSUES -gt 0 ]; then
    # Update status file with issue count
    if command -v jq >/dev/null 2>&1; then
      local TEMP_FILE=$(mktemp)
      jq --argjson issues "$HEALTH_ISSUES" '.issues = $issues' "$STATUS_FILE" > "$TEMP_FILE"
      mv "$TEMP_FILE" "$STATUS_FILE"
    else
      # Simple sed-based approach if jq not available
      sed -i "s/\"check_time\": \([0-9]*\)/\"check_time\": \1, \"issues\": $HEALTH_ISSUES/" "$STATUS_FILE"
    fi
  }
  
  # Log final health assessment
  if [ $HEALTH_ISSUES -eq 0 ]; then
    log "Node is healthy: $BLOCKS blocks, $CONNECTIONS peers, $MEMPOOL_SIZE mempool transactions" "INFO"
    execute_hook "health_check" "healthy"
  else
    log "Node has $HEALTH_ISSUES health issues" "WARNING"
    execute_hook "health_check" "unhealthy" "$HEALTH_ISSUES"
  fi
  
  return $HEALTH_ISSUES
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
    "protocol_version": ${PROTOCOL_VERSION:-0},
    "network_ok": $([ "$NETWORK_OK" = "true" ] && echo "true" || echo "false")
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
  
  log "ALERT [$SEVERITY]: $MESSAGE" "WARNING"
  
  # Update alert history
  local TIMESTAMP=$(date +%s)
  if command -v jq >/dev/null 2>&1; then
    local TEMP_FILE=$(mktemp)
    jq --arg type "$ALERT_TYPE" \
       --arg timestamp "$TIMESTAMP" \
       --arg message "$MESSAGE" \
       --arg severity "$SEVERITY" \
       --arg trace_id "$TRACE_ID" \
       '.[$type] = {"timestamp": $timestamp|tonumber, "message": $message, "severity": $severity, "trace_id": $trace_id}' \
       "$ALERT_HISTORY" > "$TEMP_FILE" 2>/dev/null || echo "{}" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$ALERT_HISTORY"
  fi
  
  # Record alert in metrics
  record_metric "alerts_total" "1" "counter"
  record_metric "alert_${SEVERITY}_total" "1" "counter"
  record_metric "alert_${ALERT_TYPE}_total" "1" "counter"
}

# Initialize monitoring settings
function monitor_setup() {
    log_info "Setting up monitoring" "monitor"
    
    # Create Prometheus metrics exporter if enabled
    if [ "${ENABLE_METRICS:-false}" = "true" ]; then
        setup_prometheus_exporter
    fi
    
    # Configure Grafana dashboards if monitoring profile enabled
    if [ "${ENABLE_GRAFANA:-false}" = "true" ]; then
        setup_grafana_dashboards
    fi
    
    # Configure alerts if enabled
    if [ "${ENABLE_ALERTS:-true}" = "true" ]; then
        setup_alert_system
    fi
    
    log_info "Monitoring setup complete" "monitor"
    return 0
}

# Setup Prometheus metrics exporter
function setup_prometheus_exporter() {
    log_info "Setting up Prometheus metrics exporter" "monitor"
    
    # Ensure exporter script is executable
    if [ -f "/usr/local/bin/start-exporter.sh" ]; then
        chmod +x /usr/local/bin/start-exporter.sh
    else
        log_error "Prometheus exporter script not found" "monitor"
        return 1
    fi
    
    return 0
}

# Setup Grafana dashboards
function setup_grafana_dashboards() {
    log_info "Setting up Grafana dashboards" "monitor"
    
    # Ensure Grafana configuration directory exists
    if [ -d "/etc/grafana/provisioning/dashboards" ]; then
        cp -r /etc/meowcoin/grafana/dashboards/* /etc/grafana/provisioning/dashboards/ 2>/dev/null || true
        log_info "Grafana dashboards provisioned" "monitor"
    else
        log_warning "Grafana provisioning directory not found" "monitor"
    fi
    
    return 0
}

# Setup alert system
function setup_alert_system() {
    log_info "Setting up alert system" "monitor"
    
    # Configure alert methods based on environment
    local ALERT_METHOD="${ALERT_METHOD:-log}"
    case "$ALERT_METHOD" in
        log)
            log_info "Using log-based alerting" "monitor"
            ;;
        webhook)
            if [ -z "$WEBHOOK_URL" ]; then
                log_warning "Webhook URL not provided, falling back to log alerting" "monitor"
                export ALERT_METHOD="log"
            else
                log_info "Using webhook alerting: $WEBHOOK_URL" "monitor"
            fi
            ;;
        email)
            if [ -z "$EMAIL_TO" ]; then
                log_warning "Email recipient not provided, falling back to log alerting" "monitor"
                export ALERT_METHOD="log"
            else
                log_info "Using email alerting: $EMAIL_TO" "monitor"
            fi
            ;;
        *)
            log_warning "Unknown alert method: $ALERT_METHOD, falling back to log alerting" "monitor"
            export ALERT_METHOD="log"
            ;;
    esac
    
    return 0
}

# Add these export statements
export -f monitor_setup setup_prometheus_exporter setup_grafana_dashboards setup_alert_system

# Export functions
export -f init_monitoring
export -f run_health_check
export -f check_node_running
export -f check_blockchain_status
export -f extract_blockchain_metrics
export -f evaluate_health_status
export -f update_health_status
export -f send_alert