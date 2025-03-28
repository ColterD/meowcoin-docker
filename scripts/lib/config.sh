#!/bin/bash
# Configuration management library for Meowcoin Docker
# Standardizes configuration loading, validation, and application

# Source common utilities
source /usr/local/bin/lib/utils.sh

# Default paths
DEFAULT_CONFIG_FILE="/home/meowcoin/.meowcoin/meowcoin.conf"
DEFAULT_TEMPLATE_FILE="/etc/meowcoin/templates/meowcoin.conf.template"
PASSWORD_FILE="/home/meowcoin/.meowcoin/.rpcpassword"
CONFIG_VERSION_FILE="/home/meowcoin/.meowcoin/.config_version"

# Load configuration with validation
function load_config() {
  local CONFIG_FILE="${1:-$DEFAULT_CONFIG_FILE}"
  local REQUIRED_VARS=("${@:2}")
  
  if [ ! -f "$CONFIG_FILE" ]; then
    handle_error 101 "Configuration file not found: $CONFIG_FILE" "config" "ERROR" "config_missing" "warning"
    return 1
  fi
  
  log "Loading configuration from $CONFIG_FILE" "INFO"
  
  # Source the config file
  source "$CONFIG_FILE"
  
  # Validate required variables
  for VAR in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!VAR}" ]; then
      handle_error 102 "Required variable $VAR is not set" "config" "ERROR" "config_invalid" "warning"
      return 1
    fi
  done
  
  log "Configuration loaded successfully" "INFO"
  return 0
}

# Validate configuration for security issues
function validate_configuration() {
  local CONFIG_FILE="${1:-$DEFAULT_CONFIG_FILE}"
  
  log "Validating configuration for security issues" "INFO"
  
  local SECURITY_ISSUES=0
  local WARNINGS=0
  local CRITICAL=0
  
  # Check if config file exists
  if [ ! -f "$CONFIG_FILE" ]; then
    handle_error 101 "Configuration file not found: $CONFIG_FILE" "config" "ERROR" "config_missing" "warning"
    return 1
  fi
  
  # Check for insecure RPC settings
  local RPC_BIND=$(grep "^rpcbind=" "$CONFIG_FILE" | cut -d= -f2)
  local RPC_ALLOWIP=$(grep "^rpcallowip=" "$CONFIG_FILE" | cut -d= -f2)
  
  if [[ "$RPC_BIND" == "0.0.0.0" ]]; then
    log "RPC is configured to bind to all interfaces (0.0.0.0)" "WARNING"
    SECURITY_ISSUES=$((SECURITY_ISSUES+1))
    WARNINGS=$((WARNINGS+1))
    
    # Check for dangerous configurations
    if [[ "$RPC_ALLOWIP" == "0.0.0.0/0" || "$RPC_ALLOWIP" == "*" || "$RPC_ALLOWIP" =~ .*,.* && ("$RPC_ALLOWIP" =~ 0.0.0.0/0 || "$RPC_ALLOWIP" =~ \*) ]]; then
      log "CRITICAL SECURITY RISK: RPC configured to accept connections from any IP" "CRITICAL"
      log "This exposes your node to attacks from the internet" "CRITICAL"
      SECURITY_ISSUES=$((SECURITY_ISSUES+1))
      CRITICAL=$((CRITICAL+1))
      
      # Set environment flag for security warning
      export SECURITY_WARNING="INSECURE_RPC_CONFIG"
      
      # Adjust settings for safety if auto-correction is enabled
      if [ "${AUTO_CORRECT_SECURITY:-true}" = "true" ]; then
        log "Auto-correcting dangerous RPC configuration" "WARNING"
        sed -i "s/^rpcbind=.*/rpcbind=127.0.0.1/" "$CONFIG_FILE"
        sed -i "s/^rpcallowip=.*/rpcallowip=127.0.0.1/" "$CONFIG_FILE"
        log "Changed RPC settings to: bind=127.0.0.1, allowip=127.0.0.1" "WARNING"
      fi
    fi
  fi
  
  # Check for SSL configuration
  local SSL_ENABLED=$(grep -c "^rpcssl=1" "$CONFIG_FILE")
  
  if [ $SSL_ENABLED -eq 0 ]; then
    # If RPC is exposed but SSL is not enabled
    if [[ "$RPC_BIND" != "127.0.0.1" && "$RPC_BIND" != "localhost" ]]; then
      log "RPC exposed without SSL encryption" "WARNING"
      SECURITY_ISSUES=$((SECURITY_ISSUES+1))
      WARNINGS=$((WARNINGS+1))
    fi
  else
    log "SSL is enabled for RPC connections" "INFO"
    
    # Check if SSL certificate exists
    local SSL_CERT=$(grep "^rpcsslcertificatechainfile=" "$CONFIG_FILE" | cut -d= -f2)
    if [ ! -f "$SSL_CERT" ]; then
      log "SSL enabled but certificate not found: $SSL_CERT" "WARNING"
      SECURITY_ISSUES=$((SECURITY_ISSUES+1))
      WARNINGS=$((WARNINGS+1))
    fi
  fi
  
  # Check RPC password strength
  local RPC_USER=$(grep "^rpcuser=" "$CONFIG_FILE" | cut -d= -f2)
  local RPC_PASSWORD=$(grep "^rpcpassword=" "$CONFIG_FILE" | cut -d= -f2)
  
  if [ ${#RPC_PASSWORD} -lt 32 ]; then
    log "RPC password is too short, consider using the auto-generated password" "WARNING"
    SECURITY_ISSUES=$((SECURITY_ISSUES+1))
    WARNINGS=$((WARNINGS+1))
  fi
  
  # Summarize security validation
  if [ $SECURITY_ISSUES -gt 0 ]; then
    log "Found $SECURITY_ISSUES potential security issues with configuration ($WARNINGS warnings, $CRITICAL critical)" "WARNING"
    
    # Send alert if monitoring is configured and there are critical issues
    if [ $CRITICAL -gt 0 ] && [ -x /usr/local/bin/monitoring/send-alert.sh ]; then
      /usr/local/bin/monitoring/send-alert.sh "Critical security configuration issues detected" "security_config" "critical"
    fi
    
    return 1
  else
    log "Configuration security validation passed" "INFO"
    return 0
  fi
}

# Generate a secure password with high entropy
function generate_secure_password() {
  local PASSWORD_FILE="${1:-$PASSWORD_FILE}"
  local LENGTH="${2:-64}"
  
  # Generate password with higher entropy
  local PASSWORD=$(generate_secure_random $LENGTH "password")
  
  # Store with restrictive permissions
  echo "$PASSWORD" > "$PASSWORD_FILE"
  chmod 600 "$PASSWORD_FILE"
  chown meowcoin:meowcoin "$PASSWORD_FILE"
  
  log "Generated secure password with high entropy (${LENGTH} chars)" "INFO"
  echo "$PASSWORD"
}

# Apply configuration template with validation
function apply_template() {
  local TEMPLATE_FILE="${1:-$DEFAULT_TEMPLATE_FILE}"
  local OUTPUT_FILE="${2:-$DEFAULT_CONFIG_FILE}"
  shift 2
  local REQUIRED_VARS=("$@")
  
  log "Applying template $TEMPLATE_FILE to $OUTPUT_FILE" "INFO"
  
  # Check if all required variables are set
  for VAR in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!VAR}" ]; then
      handle_error 102 "Required variable $VAR is not set" "apply_template" "ERROR" "config_invalid" "warning"
      return 1
    fi
  done
  
  # Create backup if target file exists
  if [ -f "$OUTPUT_FILE" ]; then
    cp "$OUTPUT_FILE" "${OUTPUT_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
    log "Created backup of existing configuration file" "INFO"
  fi
  
  # Create directory if it doesn't exist
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  
  # Apply template
  if ! envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"; then
    handle_error 103 "Template processing failed" "apply_template" "ERROR" "config_error" "warning"
    
    # Restore from backup if available
    if [ -f "${OUTPUT_FILE}.bak" ]; then
      cp "${OUTPUT_FILE}.bak" "$OUTPUT_FILE"
      log "Restored previous configuration file from backup" "WARNING"
    fi
    
    return 1
  fi
  
  # Validate output file
  if [ ! -s "$OUTPUT_FILE" ]; then
    handle_error 104 "Template processing resulted in empty file" "apply_template" "ERROR" "config_error" "warning"
    return 1
  fi
  
  # Validate configuration syntax
  if ! grep -q "^server=1" "$OUTPUT_FILE"; then
    handle_error 105 "Generated configuration is missing required parameters" "apply_template" "ERROR" "config_error" "warning"
    return 1
  fi
  
  # Apply correct permissions
  chmod 640 "$OUTPUT_FILE"
  chown meowcoin:meowcoin "$OUTPUT_FILE"
  
  # Record configuration version
  echo "$(date -Iseconds)" > "$CONFIG_VERSION_FILE"
  
  log "Configuration template applied successfully" "INFO"
  return 0
}

# Function to detect config changes that require restart
function detect_config_changes() {
  local CONFIG_FILE="${1:-$DEFAULT_CONFIG_FILE}"
  local BACKUP_FILE="${CONFIG_FILE}.bak"
  
  # If no previous config, no changes to detect
  if [ ! -f "$BACKUP_FILE" ]; then
    return 1
  }
  
  # Check for changes in key settings that would require a restart
  local RESTART_REQUIRED=false
  local CHANGE_DETECTED=false
  
  # Config keys that require restart if changed
  local RESTART_KEYS=("rpcbind" "port" "rpcport" "listen" "server" "rest" "zmqpub")
  
  # Check each key
  for KEY in "${RESTART_KEYS[@]}"; do
    local OLD_VALUE=$(grep "^${KEY}=" "$BACKUP_FILE" | cut -d= -f2)
    local NEW_VALUE=$(grep "^${KEY}=" "$CONFIG_FILE" | cut -d= -f2)
    
    # If key exists in both and values differ
    if [ ! -z "$OLD_VALUE" ] && [ ! -z "$NEW_VALUE" ] && [ "$OLD_VALUE" != "$NEW_VALUE" ]; then
      log "Configuration change detected for $KEY: $OLD_VALUE -> $NEW_VALUE" "INFO"
      CHANGE_DETECTED=true
      RESTART_REQUIRED=true
    fi
    
    # If key exists in one but not the other
    if ([ -z "$OLD_VALUE" ] && [ ! -z "$NEW_VALUE" ]) || ([ ! -z "$OLD_VALUE" ] && [ -z "$NEW_VALUE" ]); then
      log "Configuration change detected for $KEY: added or removed" "INFO"
      CHANGE_DETECTED=true
      RESTART_REQUIRED=true
    fi
  done
  
  # Record if restart required
  if [ "$RESTART_REQUIRED" = "true" ]; then
    echo "true" > "/tmp/restart_required"
    log "Configuration changes require a restart" "WARNING"
    return 0
  elif [ "$CHANGE_DETECTED" = "true" ]; then
    echo "false" > "/tmp/restart_required"
    log "Configuration changes detected but no restart required" "INFO"
    return 1
  else
    rm -f "/tmp/restart_required" 2>/dev/null || true
    log "No significant configuration changes detected" "INFO"
    return 1
  fi
}

# Function to load custom configurations
function load_custom_configs() {
  local CONFIG_FILE="${1:-$DEFAULT_CONFIG_FILE}"
  local CUSTOM_CONFIG_DIR="${2:-/etc/meowcoin/conf.d}"
  
  # Check for additional config directories
  if [ -d "$CUSTOM_CONFIG_DIR" ] && [ "$(ls -A $CUSTOM_CONFIG_DIR 2>/dev/null)" ]; then
    log "Loading custom configuration files from $CUSTOM_CONFIG_DIR" "INFO"
    
    # Process each .conf file
    for CONF_FILE in "$CUSTOM_CONFIG_DIR"/*.conf; do
      if [ -f "$CONF_FILE" ]; then
        log "Applying custom configuration from $(basename $CONF_FILE)" "INFO"
        
        # Validate file before applying
        if grep -q -E '^[a-zA-Z0-9_\-]+=[a-zA-Z0-9_\.\-\/]+$' "$CONF_FILE"; then
          # Append configurations
          cat "$CONF_FILE" >> "$CONFIG_FILE"
        else
          log "Custom configuration file contains invalid format, skipping: $(basename $CONF_FILE)" "WARNING"
        fi
      fi
    done
  fi
}

# Dynamic resource allocation with improved detection
function calculate_resources() {
  log "Calculating optimal resource allocation" "INFO"
  
  # Get available memory
  local MEMORY_LIMIT_MB=$(get_memory_info "total")
  log "Detected memory: ${MEMORY_LIMIT_MB}MB" "INFO"
  
  # Get CPU count
  local CPU_COUNT=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "1")
  log "Detected CPU count: $CPU_COUNT" "INFO"
  
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
  log "Detected disk type: $DISK_TYPE" "INFO"
  
  # Calculate resources based on memory and system type
  if [ $MEMORY_LIMIT_MB -lt 1024 ]; then
    # Low memory environment (<1GB)
    DBCACHE_MB=$((MEMORY_LIMIT_MB / 4))
    MAX_CONNECTIONS=12
    MEMPOOL_MB=$((MEMORY_LIMIT_MB / 8))
    RPC_THREADS=$((CPU_COUNT > 2 ? 2 : 1))
    log "Low memory profile selected" "INFO"
  elif [ $MEMORY_LIMIT_MB -lt 4096 ]; then
    # Medium memory environment (1-4GB)
    DBCACHE_MB=$((MEMORY_LIMIT_MB / 3))
    MAX_CONNECTIONS=$((MEMORY_LIMIT_MB / 32))
    MEMPOOL_MB=$((MEMORY_LIMIT_MB / 6))
    RPC_THREADS=$((CPU_COUNT / 2 > 0 ? CPU_COUNT / 2 : 1))
    log "Medium memory profile selected" "INFO"
  else
    # High memory environment (>4GB)
    DBCACHE_MB=$((MEMORY_LIMIT_MB / 2))
    [ $DBCACHE_MB -gt 4096 ] && DBCACHE_MB=4096
    MAX_CONNECTIONS=$((MEMORY_LIMIT_MB / 40))
    [ $MAX_CONNECTIONS -gt 125 ] && MAX_CONNECTIONS=125
    MEMPOOL_MB=$((MEMORY_LIMIT_MB / 4))
    [ $MEMPOOL_MB -gt 1024 ] && MEMPOOL_MB=1024
    RPC_THREADS=$CPU_COUNT
    log "High memory profile selected" "INFO"
  fi
  
  # Disk-specific optimizations
  if [ "$DISK_TYPE" = "ssd" ]; then
    # SSD optimizations
    DBCACHE_MB=$((DBCACHE_MB * 120 / 100))  # Increase cache by 20% for SSDs
    log "Applied SSD optimizations (+20% dbcache)" "INFO"
  elif [ "$DISK_TYPE" = "hdd" ]; then
    # HDD optimizations - lower concurrent I/O
    MAX_CONNECTIONS=$((MAX_CONNECTIONS * 80 / 100))  # Reduce connections by 20% for HDDs
    log "Applied HDD optimizations (-20% max connections)" "INFO"
  fi
  
  # Export as environment variables for config template
  export DBCACHE=$DBCACHE_MB
  export MAX_CONNECTIONS=$MAX_CONNECTIONS
  export MAXMEMPOOL=$MEMPOOL_MB
  export RPC_THREADS=$RPC_THREADS
  
  log "Resource allocation: dbcache=${DBCACHE}MB, maxconnections=${MAX_CONNECTIONS}, maxmempool=${MAXMEMPOOL}MB, rpcthreads=${RPC_THREADS}" "INFO"
}

# Export functions for use in other scripts
export -f load_config
export -f validate_configuration
export -f generate_secure_password
export -f apply_template
export -f detect_config_changes
export -f load_custom_configs
export -f calculate_resources