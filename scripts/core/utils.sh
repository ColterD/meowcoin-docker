# scripts/core/utils.sh
#!/bin/bash
# Common utility library for Meowcoin Docker
# Centralizes shared functionality to reduce duplication

# Generate a unique trace ID if not provided
TRACE_ID="${TRACE_ID:-$(date +%s)-$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8)}"
LOG_TIMESTAMP_FORMAT="%Y-%m-%dT%H:%M:%S%z"

# Standard logging function with trace ID and timestamp
function log() {
  local MESSAGE="$1"
  local LEVEL="${2:-INFO}"
  local LOG_FILE="${LOG_FILE:-/var/log/meowcoin/system.log}"
  local TIMESTAMP=$(date +"$LOG_TIMESTAMP_FORMAT")
  
  # Create log directory if it doesn't exist
  mkdir -p "$(dirname "$LOG_FILE")"
  
  # Format log message
  echo "[$TRACE_ID][$TIMESTAMP][$LEVEL] $MESSAGE" | tee -a "$LOG_FILE"
  
  # Output to stderr for warning/error levels
  if [[ "$LEVEL" == "ERROR" || "$LEVEL" == "CRITICAL" || "$LEVEL" == "WARNING" ]]; then
    echo "[$TIMESTAMP][$LEVEL] $MESSAGE" >&2
  fi
}

# Standardized error handling
function handle_error() {
  local EXIT_CODE=$1
  local ERROR_MESSAGE=$2
  local ERROR_SOURCE=${3:-${BASH_SOURCE[1]##*/}}
  local ERROR_LEVEL=${4:-"ERROR"}
  local ALERT_TYPE=${5:-"system_error"}
  local ALERT_SEVERITY=${6:-"warning"}
  
  # Log the error
  log "$ERROR_MESSAGE" "$ERROR_LEVEL"
  
  # Send alert if monitoring is configured and alert script exists
  if [ -x /usr/local/bin/tools/send-alert.sh ]; then
    /usr/local/bin/tools/send-alert.sh "$ERROR_MESSAGE" "$ALERT_TYPE" "$ALERT_SEVERITY"
  fi
  
  # Exit if this is a critical error
  if [ $EXIT_CODE -gt 100 ]; then
    log "Critical error detected (code $EXIT_CODE). Exiting..." "CRITICAL"
    exit $EXIT_CODE
  fi
  
  return $EXIT_CODE
}

# Function to retry operations with exponential backoff
function retry_operation() {
  local CMD="$1"
  local MAX_ATTEMPTS="${2:-3}"
  local ATTEMPT=1
  local DELAY="${3:-5}"
  local TIMEOUT="${4:-60}"
  local OPERATION_NAME="${5:-operation}"
  
  while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    log "Executing $OPERATION_NAME (attempt $ATTEMPT/$MAX_ATTEMPTS)" "DEBUG"
    
    # Use timeout to prevent hanging commands
    if timeout $TIMEOUT bash -c "$CMD"; then
      log "$OPERATION_NAME succeeded on attempt $ATTEMPT" "DEBUG"
      return 0
    fi
    
    local EXIT_CODE=$?
    
    # Handle different error codes
    case $EXIT_CODE in
      124)
        log "$OPERATION_NAME timed out after $TIMEOUT seconds" "WARNING"
        ;;
      127)
        log "$OPERATION_NAME failed - command not found" "ERROR"
        if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
          return 127
        fi
        ;;
      *)
        log "$OPERATION_NAME failed with exit code $EXIT_CODE" "ERROR"
        ;;
    esac
    
    if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
      log "$OPERATION_NAME failed after $MAX_ATTEMPTS attempts" "ERROR"
      return $EXIT_CODE
    fi
    
    log "Retrying in $DELAY seconds..." "DEBUG"
    sleep $DELAY
    ATTEMPT=$((ATTEMPT + 1))
    DELAY=$((DELAY * 2))  # Exponential backoff
  done
  
  return 1
}

# Function to safely extract JSON values
function extract_json_value() {
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
    local VALUE=$(echo "$JSON" | grep -m 1 "\"$KEY\"" | sed -E "s/.*\"$KEY\"[^0-9]*([0-9]+\.?[0-9]*).*/\1/")
    if [ -z "$VALUE" ]; then
      echo "$DEFAULT"
    else
      echo "$VALUE"
    fi
  fi
}

# Function to validate IP address format
function is_valid_ip() {
  local IP="$1"
  if [[ $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    local IFS='.'
    local -a OCTETS=($IP)
    
    if [ ${OCTETS[0]} -le 255 ] && [ ${OCTETS[1]} -le 255 ] && [ ${OCTETS[2]} -le 255 ] && [ ${OCTETS[3]} -le 255 ]; then
      return 0  # Valid IP
    fi
  fi
  
  return 1  # Invalid IP
}

# Function to validate and normalize environment variables
function validate_env_variable() {
  local VAR_NAME="$1"
  local DEFAULT_VALUE="$2"
  local VALIDATION_REGEX="$3"
  local ERROR_MESSAGE="$4"
  
  # Get current value or set default
  local CURRENT_VALUE="${!VAR_NAME:-$DEFAULT_VALUE}"
  
  # Validate if regex provided
  if [ ! -z "$VALIDATION_REGEX" ] && [[ ! "$CURRENT_VALUE" =~ $VALIDATION_REGEX ]]; then
    log "$VAR_NAME=$CURRENT_VALUE is invalid: $ERROR_MESSAGE" "WARNING"
    log "Using default value: $DEFAULT_VALUE" "INFO"
    CURRENT_VALUE="$DEFAULT_VALUE"
  fi
  
  # Export the variable
  export $VAR_NAME="$CURRENT_VALUE"
  
  # Return the value (useful for capturing in assignments)
  echo "$CURRENT_VALUE"
}

# Function to generate secure random string
function generate_secure_random() {
  local LENGTH="${1:-32}"
  local TYPE="${2:-hex}"  # Options: hex, base64, alphanumeric, password
  
  case "$TYPE" in
    hex)
      # Generate hex string
      openssl rand -hex $((LENGTH / 2))
      ;;
    base64)
      # Generate base64 string
      openssl rand -base64 $((LENGTH * 3 / 4)) | tr -d '=+/' | head -c $LENGTH
      ;;
    alphanumeric)
      # Generate alphanumeric string
      cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c $LENGTH
      ;;
    password)
      # Generate secure password with special chars
      cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*()-_=+' | head -c $LENGTH
      ;;
    *)
      # Default to hex
      openssl rand -hex $((LENGTH / 2))
      ;;
  esac
}

# Function to check if a port is available
function is_port_available() {
  local PORT="$1"
  local HOST="${2:-127.0.0.1}"
  
  # Check if netstat or ss is available
  if command -v netstat >/dev/null 2>&1; then
    netstat -tuln | grep -q "$HOST:$PORT"
    # Return 0 if port is NOT in use (available)
    return $?
  elif command -v ss >/dev/null 2>&1; then
    ss -tuln | grep -q "$HOST:$PORT"
    # Return 0 if port is NOT in use (available)
    return $?
  else
    # If neither tool is available, check with a socket connection
    (echo > /dev/tcp/$HOST/$PORT) >/dev/null 2>&1
    # Return 0 if port is NOT in use (connection failed)
    if [ $? -ne 0 ]; then
      return 0
    else
      return 1
    fi
  fi
}

# Detect disk type (SSD vs HDD)
function detect_disk_type() {
  local DATA_DIR="/home/meowcoin/.meowcoin"
  local DISK_TYPE="unknown"
  
  if [ -x "$(command -v lsblk)" ]; then
    # Get device name for data directory
    local DEV_NAME=$(df -P "$DATA_DIR" | tail -1 | cut -d' ' -f1 | sed 's/.*\///')
    
    # Check if device is rotational (HDD) or not (SSD)
    if lsblk -d -o name,rota | grep "$DEV_NAME" | grep -q "0"; then
      DISK_TYPE="ssd"
    else
      DISK_TYPE="hdd"
    fi
  else
    # Fallback method using basic I/O test
    if [ -x "$(command -v dd)" ]; then
      # Create temp file
      local TEMP_FILE="$DATA_DIR/.disk_type_test"
      
      # Run random read test (better on SSDs)
      dd if=/dev/zero of="$TEMP_FILE" bs=1M count=100 conv=fdatasync >/dev/null 2>&1
      local START_TIME=$(date +%s.%N)
      dd if="$TEMP_FILE" of=/dev/null bs=4k count=25000 iflag=direct >/dev/null 2>&1
      local END_TIME=$(date +%s.%N)
      
      # Calculate time
      local ELAPSED_TIME=$(echo "$END_TIME - $START_TIME" | bc)
      
      # Clean up
      rm -f "$TEMP_FILE"
      
      # If read was fast, probably SSD
      if (( $(echo "$ELAPSED_TIME < 1.0" | bc -l) )); then
        DISK_TYPE="ssd"
      else
        DISK_TYPE="hdd"
      fi
    fi
  fi
  
  echo "$DISK_TYPE"
}

# Measure disk speed in MB/s
function measure_disk_speed() {
  local DATA_DIR="/home/meowcoin/.meowcoin"
  local DISK_SPEED=0
  
  if [ -x "$(command -v dd)" ]; then
    # Create temp file
    local TEMP_FILE="$DATA_DIR/.disk_speed_test"
    
    # Run write test
    local START_TIME=$(date +%s.%N)
    dd if=/dev/zero of="$TEMP_FILE" bs=1M count=100 conv=fdatasync >/dev/null 2>&1
    local END_TIME=$(date +%s.%N)
    
    # Calculate speed
    local ELAPSED_TIME=$(echo "$END_TIME - $START_TIME" | bc)
    DISK_SPEED=$(echo "100 / $ELAPSED_TIME" | bc)
    
    # Clean up
    rm -f "$TEMP_FILE"
  fi
  
  echo "$DISK_SPEED"
}

# Function to get memory info in MB
function get_memory_info() {
  local MEMORY_TYPE="${1:-total}"  # Options: total, free, available
  
  # Use cgroups detection for more accurate memory limits
  if [ -f /sys/fs/cgroup/memory.max ]; then
    # For cgroups v2
    local MEMORY_LIMIT=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo "max")
    if [ "$MEMORY_LIMIT" = "max" ]; then
      # No limit set, use total system memory
      MEMORY_LIMIT_MB=$(free -m | grep Mem | awk '{print $2}')
    else
      MEMORY_LIMIT_MB=$((MEMORY_LIMIT / 1024 / 1024))
    fi
  elif [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
    # For cgroups v1
    local MEMORY_LIMIT=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null)
    # Check if limit is not set (max uint64)
    if [ "$MEMORY_LIMIT" = "9223372036854771712" ] || [ "$MEMORY_LIMIT" = "9223372036854775807" ]; then
      MEMORY_LIMIT_MB=$(free -m | grep Mem | awk '{print $2}')
    else
      MEMORY_LIMIT_MB=$((MEMORY_LIMIT / 1024 / 1024))
    fi
  else
    # Fallback to total system memory
    MEMORY_LIMIT_MB=$(free -m | grep Mem | awk '{print $2}')
  fi
  
  # Get available or free memory based on request
  case "$MEMORY_TYPE" in
    total)
      echo "$MEMORY_LIMIT_MB"
      ;;
    free)
      FREE_MB=$(free -m | grep Mem | awk '{print $4}')
      echo "$FREE_MB"
      ;;
    available)
      AVAILABLE_MB=$(free -m | grep Mem | awk '{print $7}')
      echo "$AVAILABLE_MB"
      ;;
    *)
      # Default to total
      echo "$MEMORY_LIMIT_MB"
      ;;
  esac
}

# Function to execute a hook
function execute_hook() {
  local HOOK_NAME="$1"
  shift
  export HOOK_ARGS="$@"
  
  if [ -d "/usr/local/bin/hooks" ]; then
    # Check if hook exists
    if [ -x "/usr/local/bin/hooks/${HOOK_NAME}.sh" ]; then
      log "Executing hook: $HOOK_NAME" "INFO"
      "/usr/local/bin/hooks/${HOOK_NAME}.sh" "$@" || log "Hook execution failed: $HOOK_NAME" "WARNING"
    fi
  fi
  
  # Execute plugin hooks if plugin system enabled
  if [ "${ENABLE_PLUGINS:-false}" = "true" ] && [ -x /usr/local/bin/plugins/hooks.sh ]; then
    /usr/local/bin/plugins/hooks.sh "$HOOK_NAME" "$@"
  fi
}

# Function to record metrics
function record_metric() {
  local METRIC_NAME="$1"
  local METRIC_VALUE="$2"
  local TIMESTAMP=$(date +%s)
  local METRIC_TYPE="${3:-gauge}"
  local METRICS_DIR="${METRICS_DIR:-/var/lib/meowcoin/metrics}"
  
  # Create metrics directory if it doesn't exist
  mkdir -p "$METRICS_DIR"
  
  # Sanitize metric name
  if [[ ! "$METRIC_NAME" =~ ^[a-zA-Z0-9_\.]+$ ]]; then
    log "Invalid metric name: $METRIC_NAME" "WARNING"
    return 1
  fi
  
  # Validate metric value (should be numeric)
  if [[ ! "$METRIC_VALUE" =~ ^[-]?[0-9]+\.?[0-9]*$ ]]; then
    log "Non-numeric metric value for $METRIC_NAME: $METRIC_VALUE" "WARNING"
    return 1
  fi
  
  # Save current metric
  echo "$TIMESTAMP $METRIC_VALUE" >> "$METRICS_DIR/${METRIC_NAME}.current"
  
  # Keep metrics file from growing too large
  if [ -f "$METRICS_DIR/${METRIC_NAME}.current" ] && [ $(wc -l < "$METRICS_DIR/${METRIC_NAME}.current") -gt 1000 ]; then
    tail -n 1000 "$METRICS_DIR/${METRIC_NAME}.current" > "$METRICS_DIR/${METRIC_NAME}.current.tmp"
    mv "$METRICS_DIR/${METRIC_NAME}.current.tmp" "$METRICS_DIR/${METRIC_NAME}.current"
  fi
  
  return 0
}

# Export functions
export -f log
export -f handle_error
export -f retry_operation
export -f extract_json_value
export -f is_valid_ip
export -f validate_env_variable
export -f generate_secure_random
export -f is_port_available
export -f get_memory_info
export -f record_metric
export -f detect_disk_type
export -f measure_disk_speed
export -f execute_hook