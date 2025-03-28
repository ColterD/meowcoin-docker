#!/bin/bash

# Constants
CONFIG_FILE="/home/meowcoin/.meowcoin/meowcoin.conf"
TEMPLATE_FILE="/etc/meowcoin/templates/meowcoin.conf.template"
PASSWORD_FILE="/home/meowcoin/.meowcoin/.rpcpassword"
LOG_FILE="/var/log/meowcoin/setup.log"
CONFIG_VERSION_FILE="/home/meowcoin/.meowcoin/.config_version"
TRACE_ID="${TRACE_ID:-$(date +%s)-$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8)}"

# Error handling function
function handle_error() {
  local EXIT_CODE=$1
  local ERROR_MESSAGE=$2
  local ERROR_SOURCE=${3:-"config.sh"}
  
  echo "[$TRACE_ID][$(date -Iseconds)] ERROR [$ERROR_SOURCE]: $ERROR_MESSAGE (exit code: $EXIT_CODE)" | tee -a $LOG_FILE
  
  # Send alert if monitoring is configured
  if [ -x /usr/local/bin/monitoring/send-alert.sh ]; then
    /usr/local/bin/monitoring/send-alert.sh "Configuration error: $ERROR_MESSAGE" "config_error" "error"
  fi
  
  # Exit if this is a critical error
  if [ $EXIT_CODE -gt 100 ]; then
    exit $EXIT_CODE
  fi
  
  return $EXIT_CODE
}

# Helper function for logging
function log() {
  echo "[$TRACE_ID][$(date -Iseconds)] $1" | tee -a "$LOG_FILE"
}

# Function to retry operations with exponential backoff
function retry_operation() {
  local CMD="$1"
  local MAX_ATTEMPTS="${2:-3}"
  local ATTEMPT=1
  local DELAY="${3:-5}"
  
  while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    log "Executing operation (attempt $ATTEMPT/$MAX_ATTEMPTS): $CMD"
    
    if bash -c "$CMD"; then
      return 0
    fi
    
    local EXIT_CODE=$?
    if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
      log "Operation failed after $MAX_ATTEMPTS attempts"
      return $EXIT_CODE
    fi
    
    log "Attempt $ATTEMPT failed (exit code: $EXIT_CODE), retrying in $DELAY seconds..."
    sleep $DELAY
    ATTEMPT=$((ATTEMPT + 1))
    DELAY=$((DELAY * 2))  # Exponential backoff
  done
  
  return 1
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
    log "WARNING: $VAR_NAME=$CURRENT_VALUE is invalid: $ERROR_MESSAGE"
    log "Using default value: $DEFAULT_VALUE"
    CURRENT_VALUE="$DEFAULT_VALUE"
  fi
  
  # Export the variable
  export $VAR_NAME="$CURRENT_VALUE"
  
  # Return the value (useful for capturing in assignments)
  echo "$CURRENT_VALUE"
}

# Dynamic resource allocation with improved detection
function calculate_resources() {
  # Get available memory more reliably
  log "Calculating optimal resource allocation"
  
  # Use cgroups detection for more accurate memory limits
  if [ -f /sys/fs/cgroup/memory.max ]; then
    # For cgroups v2
    local MEMORY_LIMIT=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo "max")
    if [ "$MEMORY_LIMIT" = "max" ]; then
      # No limit set, use total system memory
      MEMORY_LIMIT_MB=$(free -m | grep Mem | awk '{print $2}')
      log "Using system memory from free command: ${MEMORY_LIMIT_MB}MB"
    else
      MEMORY_LIMIT_MB=$((MEMORY_LIMIT / 1024 / 1024))
      log "Using cgroups v2 memory limit: ${MEMORY_LIMIT_MB}MB"
    fi
  elif [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
    # For cgroups v1
    local MEMORY_LIMIT=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null)
    # Check if limit is not set (max uint64)
    if [ "$MEMORY_LIMIT" = "9223372036854771712" ] || [ "$MEMORY_LIMIT" = "9223372036854775807" ]; then
      MEMORY_LIMIT_MB=$(free -m | grep Mem | awk '{print $2}')
      log "Using system memory (cgroups v1 limit not set): ${MEMORY_LIMIT_MB}MB"
    else
      MEMORY_LIMIT_MB=$((MEMORY_LIMIT / 1024 / 1024))
      log "Using cgroups v1 memory limit: ${MEMORY_LIMIT_MB}MB"
    fi
  else
    # Fallback to total system memory
    MEMORY_LIMIT_MB=$(free -m | grep Mem | awk '{print $2}')
    log "Using system memory (no cgroups found): ${MEMORY_LIMIT_MB}MB"
  fi
  
  # Get CPU count
  local CPU_COUNT=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "1")
  log "Detected CPU count: $CPU_COUNT"
  
  # Get disk type (SSD or HDD) for I/O optimization
  local DISK_TYPE="unknown"
  if [ -x "$(command -v lsblk)" ]; then
    # Try to detect if root filesystem is on SSD
    if lsblk -d -o name,rota | grep "$(df -P / | tail -1 | cut -d' ' -f1 | sed 's/.*\///')" | grep -q "0"; then
      DISK_TYPE="ssd"
    else
      DISK_TYPE="hdd"
    fi
  fi
  log "Detected disk type: $DISK_TYPE"
  
  # More nuanced calculation based on available memory and system type
  if [ $MEMORY_LIMIT_MB -lt 1024 ]; then
    # Low memory environment (<1GB)
    DBCACHE_MB=$((MEMORY_LIMIT_MB / 4))
    MAX_CONNECTIONS=12
    MEMPOOL_MB=$((MEMORY_LIMIT_MB / 8))
    RPC_THREADS=$((CPU_COUNT > 2 ? 2 : 1))
    log "Low memory profile selected"
  elif [ $MEMORY_LIMIT_MB -lt 4096 ]; then
    # Medium memory environment (1-4GB)
    DBCACHE_MB=$((MEMORY_LIMIT_MB / 3))
    MAX_CONNECTIONS=$((MEMORY_LIMIT_MB / 32))
    MEMPOOL_MB=$((MEMORY_LIMIT_MB / 6))
    RPC_THREADS=$((CPU_COUNT / 2 > 0 ? CPU_COUNT / 2 : 1))
    log "Medium memory profile selected"
  else
    # High memory environment (>4GB)
    DBCACHE_MB=$((MEMORY_LIMIT_MB / 2))
    [ $DBCACHE_MB -gt 4096 ] && DBCACHE_MB=4096
    MAX_CONNECTIONS=$((MEMORY_LIMIT_MB / 40))
    [ $MAX_CONNECTIONS -gt 125 ] && MAX_CONNECTIONS=125
    MEMPOOL_MB=$((MEMORY_LIMIT_MB / 4))
    [ $MEMPOOL_MB -gt 1024 ] && MEMPOOL_MB=1024
    RPC_THREADS=$CPU_COUNT
    log "High memory profile selected"
  fi
  
  # Disk-specific optimizations
  if [ "$DISK_TYPE" = "ssd" ]; then
    # SSD optimizations
    DBCACHE_MB=$((DBCACHE_MB * 120 / 100))  # Increase cache by 20% for SSDs
    log "Applied SSD optimizations (+20% dbcache)"
  elif [ "$DISK_TYPE" = "hdd" ]; then
    # HDD optimizations - lower concurrent I/O
    MAX_CONNECTIONS=$((MAX_CONNECTIONS * 80 / 100))  # Reduce connections by 20% for HDDs
    log "Applied HDD optimizations (-20% max connections)"
  fi
  
  # Export as environment variables for config template
  export DBCACHE=$DBCACHE_MB
  export MAX_CONNECTIONS=$MAX_CONNECTIONS
  export MAXMEMPOOL=$MEMPOOL_MB
  export RPC_THREADS=$RPC_THREADS
  
  log "Resource allocation: dbcache=${DBCACHE}MB, maxconnections=${MAX_CONNECTIONS}, maxmempool=${MAXMEMPOOL}MB, rpcthreads=${RPC_THREADS}"
}

# Generate a secure password with high entropy
function generate_secure_password() {
  # Generate password with higher entropy (64 bytes)
  local PASSWORD=$(openssl rand -hex 64)
  
  # Store with restrictive permissions
  echo "$PASSWORD" > "$PASSWORD_FILE"
  chmod 600 "$PASSWORD_FILE"
  chown meowcoin:meowcoin "$PASSWORD_FILE"
  
  log "Generated secure RPC password with high entropy (128 hex chars)"
  echo "$PASSWORD"
}

# Apply configuration template with validation
function apply_template() {
  local TEMPLATE_FILE="$1"
  local OUTPUT_FILE="$2"
  shift 2
  local REQUIRED_VARS=("$@")
  
  # Check if all required variables are set
  for VAR in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!VAR}" ]; then
      handle_error 102 "Required variable $VAR is not set" "apply_template"
      return 1
    fi
  done
  
  # Create backup if target file exists
  if [ -f "$OUTPUT_FILE" ]; then
    cp "$OUTPUT_FILE" "${OUTPUT_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
    log "Created backup of existing configuration file"
  fi
  
  # Apply template
  log "Applying template $TEMPLATE_FILE to $OUTPUT_FILE"
  if ! envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"; then
    handle_error 103 "Template processing failed" "apply_template"
    
    # Restore from backup if available
    if [ -f "${OUTPUT_FILE}.bak" ]; then
      cp "${OUTPUT_FILE}.bak" "$OUTPUT_FILE"
      log "Restored previous configuration file from backup"
    fi
    
    return 1
  fi
  
  # Validate output file
  if [ ! -s "$OUTPUT_FILE" ]; then
    handle_error 104 "Template processing resulted in empty file" "apply_template"
    return 1
  fi
  
  # Apply correct permissions
  chmod 640 "$OUTPUT_FILE"
  chown meowcoin:meowcoin "$OUTPUT_FILE"
  
  # Record configuration version
  echo "$(date -Iseconds)" > "$CONFIG_VERSION_FILE"
  
  log "Configuration template applied successfully"
  return 0
}

# Setup basic environment
function setup_environment() {
  mkdir -p $(dirname $LOG_FILE)
  touch $LOG_FILE
  chmod 750 $(dirname $LOG_FILE)
  chown meowcoin:meowcoin -R $(dirname $LOG_FILE)
  
  log "Setting up environment"
  
  # Create log directory
  mkdir -p /var/log/meowcoin
  chown meowcoin:meowcoin /var/log/meowcoin
  
  # Create required directories
  mkdir -p /home/meowcoin/.meowcoin/certs
  mkdir -p /home/meowcoin/.meowcoin/logs
  mkdir -p /home/meowcoin/.meowcoin/backups
  mkdir -p /var/lib/meowcoin/metrics
  
  # Set correct permissions
  chmod 750 /home/meowcoin/.meowcoin
  chmod 750 /home/meowcoin/.meowcoin/certs
  chmod 750 /home/meowcoin/.meowcoin/logs
  chmod 750 /home/meowcoin/.meowcoin/backups
  chmod 750 /var/lib/meowcoin/metrics
  
  chown -R meowcoin:meowcoin /home/meowcoin/.meowcoin
  chown -R meowcoin:meowcoin /var/lib/meowcoin
  
  # Set timezone if provided
  if [ ! -z "$TZ" ]; then
    if [ -f "/usr/share/zoneinfo/$TZ" ]; then
      ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
      echo $TZ > /etc/timezone
      log "Set timezone to $TZ"
    else
      log "WARNING: Invalid timezone '$TZ', defaulting to UTC"
      ln -snf /usr/share/zoneinfo/UTC /etc/localtime
      echo "UTC" > /etc/timezone
    fi
  fi
  
  # Validate RPC user
  RPC_USER=$(validate_env_variable "RPC_USER" "meowcoin" "^[a-zA-Z0-9_-]+$" "Username must contain only alphanumeric characters, underscores, and hyphens")
  log "Using RPC user: $RPC_USER"
  
  # Generate or load RPC password
  if [ -z "$RPC_PASSWORD" ]; then
    # Check if password file exists
    if [ -f "$PASSWORD_FILE" ]; then
      export RPC_PASSWORD=$(cat "$PASSWORD_FILE")
      log "Using existing RPC password from $PASSWORD_FILE"
    else
      # Generate secure password with high entropy
      export RPC_PASSWORD=$(generate_secure_password)
      log "NOTE: Access the password by viewing the $PASSWORD_FILE file inside the container volume"
    fi
  else
    # Validate user-provided password
    if [ ${#RPC_PASSWORD} -lt 32 ]; then
      log "WARNING: User-provided RPC password is too short (< 32 chars)"
      log "Consider using the auto-generated password for better security"
    else
      log "Using user-provided RPC password"
    fi
    
    # Save it for consistency
    echo "$RPC_PASSWORD" > "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
    chown meowcoin:meowcoin "$PASSWORD_FILE"
  fi
  
  # Validate other key settings
  RPC_BIND=$(validate_env_variable "RPC_BIND" "127.0.0.1" "^[0-9\.]+$" "IP address must be in valid format")
  RPC_ALLOWIP=$(validate_env_variable "RPC_ALLOWIP" "127.0.0.1" "^[0-9\.\*\/,]+$" "IP address or CIDR must be in valid format")
  
  # Calculate optimal resource allocation
  calculate_resources
}

# Validate configuration for security issues with enhanced checks
function validate_configuration() {
  log "Validating configuration"
  
  local SECURITY_ISSUES=0
  local WARNINGS=0
  local CRITICAL=0
  
  # Check for insecure RPC settings with improved pattern matching
  if [[ "$RPC_BIND" == "0.0.0.0" ]]; then
    log "WARNING: RPC is configured to bind to all interfaces (0.0.0.0)"
    SECURITY_ISSUES=$((SECURITY_ISSUES+1))
    WARNINGS=$((WARNINGS+1))
    
    # More specific checks for dangerous configurations
    if [[ "$RPC_ALLOWIP" == "0.0.0.0/0" || "$RPC_ALLOWIP" == "*" || "$RPC_ALLOWIP" =~ .*,.* && ("$RPC_ALLOWIP" =~ 0.0.0.0/0 || "$RPC_ALLOWIP" =~ \*) ]]; then
      log "CRITICAL SECURITY RISK: RPC configured to accept connections from any IP"
      log "This exposes your node to attacks from the internet"
      SECURITY_ISSUES=$((SECURITY_ISSUES+1))
      CRITICAL=$((CRITICAL+1))
      
      # Set environment flag for security warning
      export SECURITY_WARNING="INSECURE_RPC_CONFIG"
      
      # Adjust settings for safety if auto-correction is enabled
      if [ "${AUTO_CORRECT_SECURITY:-true}" = "true" ]; then
        log "Auto-correcting dangerous RPC configuration"
        export RPC_BIND="127.0.0.1"
        export RPC_ALLOWIP="127.0.0.1"
        log "Changed RPC settings to: bind=127.0.0.1, allowip=127.0.0.1"
      fi
    fi
  fi
  
  # Validate RPC password strength
  if [ ${#RPC_PASSWORD} -lt 32 ]; then
    log "WARNING: RPC password is too short, consider using the auto-generated password"
    SECURITY_ISSUES=$((SECURITY_ISSUES+1))
    WARNINGS=$((WARNINGS+1))
  fi
  
  # Check for SSL configuration
  if [ "${ENABLE_SSL:-false}" = "true" ]; then
    log "SSL is enabled for RPC connections"
    
    # Check if SSL certificate exists
    if [ ! -f "/home/meowcoin/.meowcoin/certs/meowcoin.crt" ]; then
      log "WARNING: SSL enabled but certificate not found"
      SECURITY_ISSUES=$((SECURITY_ISSUES+1))
      WARNINGS=$((WARNINGS+1))
    fi
  else
    # If RPC is exposed but SSL is not enabled
    if [[ "$RPC_BIND" != "127.0.0.1" && "$RPC_BIND" != "localhost" ]]; then
      log "WARNING: RPC exposed without SSL encryption"
      SECURITY_ISSUES=$((SECURITY_ISSUES+1))
      WARNINGS=$((WARNINGS+1))
    fi
  fi
  
  # Check JWT auth settings
  if [ "${ENABLE_JWT_AUTH:-false}" = "true" ]; then
    log "JWT authentication is enabled"
    
    # Check if JWT secret exists
    if [ ! -f "/home/meowcoin/.meowcoin/.jwtsecret" ]; then
      log "WARNING: JWT auth enabled but secret file not found"
      SECURITY_ISSUES=$((SECURITY_ISSUES+1))
      WARNINGS=$((WARNINGS+1))
    fi
  fi
  
  # Sanitize custom options to prevent injection with improved validation
  if [ ! -z "$CUSTOM_OPTS" ]; then
    # Create a temporary file for sanitized options
    local TEMP_FILE=$(mktemp)
    
    # Process each option separately for better validation
    echo "$CUSTOM_OPTS" | tr ' ' '\n' | while read OPTION; do
      # Skip empty lines
      [ -z "$OPTION" ] && continue
      
      # Validate option format (should be key=value)
      if [[ "$OPTION" =~ ^[a-zA-Z0-9_]+=[a-zA-Z0-9_\.\/\-]+$ ]]; then
        echo "$OPTION" >> "$TEMP_FILE"
      else
        log "WARNING: Skipping invalid custom option: $OPTION"
      fi
    done
    
    # Read sanitized options
    CUSTOM_OPTS=$(cat "$TEMP_FILE" | tr '\n' ' ')
    rm -f "$TEMP_FILE"
    
    export CUSTOM_OPTS
    log "Applied custom options: $CUSTOM_OPTS"
  fi
  
  # Verify critical directories exist
  for DIR in "/home/meowcoin/.meowcoin" "/home/meowcoin/.meowcoin/certs" "/home/meowcoin/.meowcoin/logs"; do
    if [ ! -d "$DIR" ]; then
      log "ERROR: Required directory missing: $DIR"
      mkdir -p "$DIR"
      chown meowcoin:meowcoin "$DIR"
      chmod 750 "$DIR"
    fi
  done
  
  # Apply configuration template with validation
  apply_template "$TEMPLATE_FILE" "$CONFIG_FILE" "RPC_USER" "RPC_PASSWORD" "RPC_BIND" "RPC_ALLOWIP" "DBCACHE" "MAX_CONNECTIONS" "MAXMEMPOOL" || handle_error 101 "Failed to apply configuration template"
  
  # Summarize security validation
  if [ $SECURITY_ISSUES -gt 0 ]; then
    log "Found $SECURITY_ISSUES potential security issues with configuration ($WARNINGS warnings, $CRITICAL critical)"
    
    # Send alert if monitoring is configured and there are critical issues
    if [ $CRITICAL -gt 0 ] && [ -x /usr/local/bin/monitoring/send-alert.sh ]; then
      /usr/local/bin/monitoring/send-alert.sh "Critical security configuration issues detected" "security_config" "critical"
    fi
  else
    log "Configuration security validation passed"
  fi
}

# Function to detect config changes that require restart
function detect_config_changes() {
  # If no previous config, no changes to detect
  if [ ! -f "${CONFIG_FILE}.bak" ]; then
    return 1
  }
  
  # Check for changes in key settings that would require a restart
  local RESTART_REQUIRED=false
  local CHANGE_DETECTED=false
  
  # Config keys that require restart if changed
  local RESTART_KEYS=("rpcbind" "port" "rpcport" "listen" "server" "rest" "zmqpub")
  
  # Check each key
  for KEY in "${RESTART_KEYS[@]}"; do
    local OLD_VALUE=$(grep "^${KEY}=" "${CONFIG_FILE}.bak" | cut -d= -f2)
    local NEW_VALUE=$(grep "^${KEY}=" "${CONFIG_FILE}" | cut -d= -f2)
    
    # If key exists in both and values differ
    if [ ! -z "$OLD_VALUE" ] && [ ! -z "$NEW_VALUE" ] && [ "$OLD_VALUE" != "$NEW_VALUE" ]; then
      log "Configuration change detected for $KEY: $OLD_VALUE -> $NEW_VALUE"
      CHANGE_DETECTED=true
      RESTART_REQUIRED=true
    fi
    
    # If key exists in one but not the other
    if ([ -z "$OLD_VALUE" ] && [ ! -z "$NEW_VALUE" ]) || ([ ! -z "$OLD_VALUE" ] && [ -z "$NEW_VALUE" ]); then
      log "Configuration change detected for $KEY: added or removed"
      CHANGE_DETECTED=true
      RESTART_REQUIRED=true
    fi
  done
  
  # Record if restart required
  if [ "$RESTART_REQUIRED" = "true" ]; then
    echo "true" > "/tmp/restart_required"
    log "Configuration changes require a restart"
    return 0
  elif [ "$CHANGE_DETECTED" = "true" ]; then
    echo "false" > "/tmp/restart_required"
    log "Configuration changes detected but no restart required"
    return 1
  else
    rm -f "/tmp/restart_required" 2>/dev/null || true
    log "No significant configuration changes detected"
    return 1
  fi
}

# Function to load custom configurations
function load_custom_configs() {
  # Check for additional config directories
  local CUSTOM_CONFIG_DIR="/etc/meowcoin/conf.d"
  
  if [ -d "$CUSTOM_CONFIG_DIR" ] && [ "$(ls -A $CUSTOM_CONFIG_DIR)" ]; then
    log "Loading custom configuration files from $CUSTOM_CONFIG_DIR"
    
    # Process each .conf file
    for CONFIG_FILE in "$CUSTOM_CONFIG_DIR"/*.conf; do
      if [ -f "$CONFIG_FILE" ]; then
        log "Applying custom configuration from $(basename $CONFIG_FILE)"
        
        # Validate file before applying
        if grep -q -E '^[a-zA-Z0-9_\-]+=[a-zA-Z0-9_\.\-\/]+$' "$CONFIG_FILE"; then
          # Append configurations
          cat "$CONFIG_FILE" >> "$CONFIG_FILE"
        else
          log "WARNING: Custom configuration file contains invalid format, skipping: $(basename $CONFIG_FILE)"
        fi
      fi
    done
  fi
}

# Main function for setup
if [ "$1" = "setup" ]; then
  setup_environment
  validate_configuration
  load_custom_configs
  detect_config_changes
elif [ "$1" = "validate" ]; then
  validate_configuration
elif [ "$1" = "resources" ]; then
  calculate_resources
else
  # Default action when sourced
  :
fi