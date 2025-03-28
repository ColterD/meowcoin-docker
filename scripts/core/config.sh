# scripts/core/config.sh
#!/bin/bash
# Configuration management library for Meowcoin Docker
# Standardizes configuration loading, validation, and application

# Source core utilities
source /usr/local/bin/core/utils.sh

# Default paths
DEFAULT_CONFIG_FILE="/home/meowcoin/.meowcoin/meowcoin.conf"
DEFAULT_TEMPLATE_FILE="/etc/meowcoin/templates/meowcoin.conf.template"
PASSWORD_FILE="/home/meowcoin/.meowcoin/.rpcpassword"
CONFIG_VERSION_FILE="/home/meowcoin/.meowcoin/.config_version"
SECRETS_DIR="/run/secrets"

# Setup environment
function setup_environment() {
  mkdir -p /home/meowcoin/.meowcoin
  mkdir -p /var/log/meowcoin
  mkdir -p /var/lib/meowcoin/metrics
  
  # Set correct permissions
  chmod 750 /home/meowcoin/.meowcoin
  chmod 750 /var/log/meowcoin
  chmod 750 /var/lib/meowcoin/metrics
  
  chown -R meowcoin:meowcoin /home/meowcoin/.meowcoin
  chown -R meowcoin:meowcoin /var/lib/meowcoin
  chown meowcoin:meowcoin /var/log/meowcoin
  
  # Set timezone if provided
  if [ ! -z "$TZ" ]; then
    if [ -f "/usr/share/zoneinfo/$TZ" ]; then
      ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
      echo $TZ > /etc/timezone
      log "Set timezone to $TZ" "INFO"
    else
      log "Invalid timezone '$TZ', defaulting to UTC" "WARNING"
      ln -snf /usr/share/zoneinfo/UTC /etc/localtime
      echo "UTC" > /etc/timezone
    fi
  fi
  
  # Validate environment schema
  validate_environment_schema
  
  # Validate RPC user
  RPC_USER=$(validate_env_variable "RPC_USER" "meowcoin" "^[a-zA-Z0-9_-]+$" "Username must contain only alphanumeric characters, underscores, and hyphens")
  log "Using RPC user: $RPC_USER" "INFO"
  
  # Setup RPC credentials using Docker secrets if available
  setup_rpc_credentials
  
  # Validate other key settings
  RPC_BIND=$(validate_env_variable "RPC_BIND" "127.0.0.1" "^[0-9\.]+$" "IP address must be in valid format")
  RPC_ALLOWIP=$(validate_env_variable "RPC_ALLOWIP" "127.0.0.1" "^[0-9\.\*\/,]+$" "IP address or CIDR must be in valid format")
  
  # Calculate optimal resource allocation
  calculate_resources
  
  return 0
}

# Validate environment variables schema
function validate_environment_schema() {
  local ERRORS=0
  
  # Validate required variables
  for VAR in RPC_USER RPC_BIND; do
    if [ -z "${!VAR}" ]; then
      log "Required variable $VAR is not set" "WARNING"
      ERRORS=$((ERRORS+1))
    fi
  done
  
  # Validate integer variables
  for VAR in MAX_CONNECTIONS DBCACHE MAXMEMPOOL RPC_THREADS RPC_TIMEOUT RPC_WORKQUEUE; do
    if [ ! -z "${!VAR}" ] && [[ ! "${!VAR}" =~ ^[0-9]+$ ]]; then
      log "Variable $VAR must be an integer: ${!VAR}" "WARNING"
      ERRORS=$((ERRORS+1))
    fi
  done
  
  # Validate boolean variables
  for VAR in ENABLE_SSL ENABLE_FAIL2BAN ENABLE_JWT_AUTH ENABLE_READONLY_FS ENABLE_METRICS ENABLE_BACKUPS BACKUP_REMOTE_ENABLED; do
    if [ ! -z "${!VAR}" ] && [[ ! "${!VAR}" =~ ^(true|false)$ ]]; then
      log "Variable $VAR must be 'true' or 'false': ${!VAR}" "WARNING"
      ERRORS=$((ERRORS+1))
    fi
  done
  
  # Validate IP format for RPC_BIND
  if [ ! -z "$RPC_BIND" ] && ! is_valid_ip "$RPC_BIND"; then
    log "RPC_BIND must be in valid IP format: $RPC_BIND" "WARNING"
    ERRORS=$((ERRORS+1))
  fi
  
  # Check for insecure configurations
  if [ "$RPC_BIND" = "0.0.0.0" ] && [ "$RPC_ALLOWIP" = "0.0.0.0/0" ] && [ "${ENABLE_SSL:-false}" != "true" ]; then
    log "SECURITY WARNING: Exposing RPC to all addresses without SSL encryption" "WARNING"
  fi
  
  if [ $ERRORS -gt 0 ]; then
    log "Found $ERRORS environment validation errors" "WARNING"
    return 1
  fi
  
  return 0
}

# Generate/load RPC credentials with Docker secrets support
function setup_rpc_credentials() {
  # Check if Docker secret exists first
  if [ -f "$SECRETS_DIR/meowcoin_rpc_password" ]; then
    export RPC_PASSWORD=$(cat "$SECRETS_DIR/meowcoin_rpc_password")
    log "Using RPC password from Docker secret" "INFO"
  elif [ -z "$RPC_PASSWORD" ]; then
    # Check if password file exists
    if [ -f "$PASSWORD_FILE" ]; then
      export RPC_PASSWORD=$(cat "$PASSWORD_FILE")
      log "Using existing RPC password from $PASSWORD_FILE" "INFO"
    else
      # Generate secure password with high entropy
      export RPC_PASSWORD=$(generate_secure_password)
      log "Access the password by viewing the $PASSWORD_FILE file inside the container volume" "INFO"
    fi
  else
    # Validate user-provided password
    if [ ${#RPC_PASSWORD} -lt 32 ]; then
      log "User-provided RPC password is too short (< 32 chars)" "WARNING"
      log "Consider using the auto-generated password for better security" "WARNING"
    else
      log "Using user-provided RPC password" "INFO"
    fi
    
    # Save it for consistency
    echo "$RPC_PASSWORD" > "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
    chown meowcoin:meowcoin "$PASSWORD_FILE"
  fi
}

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
    if [ $CRITICAL -gt 0 ] && [ -x /usr/local/bin/tools/send-alert.sh ]; then
      /usr/local/bin/tools/send-alert.sh "Critical security configuration issues detected" "security_config" "critical"
    fi
    
    return 1
  else
    log "Configuration security validation passed" "INFO"
    return 0
  fi
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

# Enhanced resource calculation with better container awareness
function calculate_resources() {
  log "Calculating optimal resource allocation" "INFO"
  
  # Get memory metrics with enhanced container detection
  local MEMORY_TOTAL=$(get_memory_info "total")
  local MEMORY_AVAILABLE=$(get_memory_info "available")
  local MEMORY_UTILIZATION=$(echo "scale=2; (($MEMORY_TOTAL - $MEMORY_AVAILABLE) / $MEMORY_TOTAL) * 100" | bc)
  
  log "Detected memory: ${MEMORY_TOTAL}MB total, ${MEMORY_AVAILABLE}MB available, ${MEMORY_UTILIZATION}% used" "INFO"
  
  # Get CPU info with load consideration
  local CPU_COUNT=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "1")
  local CPU_LOAD=$(cat /proc/loadavg | awk '{print $1}')
  local CPU_LOAD_PERCENT=$(echo "scale=2; ($CPU_LOAD / $CPU_COUNT) * 100" | bc)
  
  log "Detected CPU: $CPU_COUNT cores, load: $CPU_LOAD ($CPU_LOAD_PERCENT%)" "INFO"
  
  # Get disk metrics
  local DISK_TYPE=$(detect_disk_type)
  local DISK_SPEED=$(measure_disk_speed)
  
  log "Detected disk: type=$DISK_TYPE, speed=$DISK_SPEED MB/s" "INFO"
  
  # Calculate optimal resources
  calculate_optimal_resources "$MEMORY_TOTAL" "$MEMORY_AVAILABLE" "$CPU_COUNT" "$CPU_LOAD_PERCENT" "$DISK_TYPE" "$DISK_SPEED"
  
  log "Resource allocation: dbcache=${DBCACHE}MB, maxconnections=${MAX_CONNECTIONS}, maxmempool=${MAXMEMPOOL}MB, rpcthreads=${RPC_THREADS}" "INFO"
}

# Sophisticated resource allocation with multiple factors
function calculate_optimal_resources() {
  local MEM_TOTAL=$1
  local MEM_AVAILABLE=$2
  local CPU_COUNT=$3
  local CPU_LOAD_PCT=$4
  local DISK_TYPE=$5
  local DISK_SPEED=$6
  
  # Base allocations on system profile
  if [ $MEM_TOTAL -lt 1024 ]; then
    # Low memory profile with dynamic scaling
    MEMORY_SCALING_FACTOR=0.25
    CONNECTION_FACTOR=12
    RPC_THREAD_FACTOR=0.5
  elif [ $MEM_TOTAL -lt 4096 ]; then
    # Medium memory profile
    MEMORY_SCALING_FACTOR=0.33
    CONNECTION_FACTOR=0.03  # 3% of memory in MB
    RPC_THREAD_FACTOR=0.5
  else
    # High memory profile with caps
    MEMORY_SCALING_FACTOR=0.45
    CONNECTION_FACTOR=0.025 # 2.5% of memory in MB
    RPC_THREAD_FACTOR=0.75
  fi
  
  # Apply current load adjustments
  if [ $(echo "$CPU_LOAD_PCT > 70" | bc) -eq 1 ]; then
    # High CPU load - reduce resource usage
    MEMORY_SCALING_FACTOR=$(echo "$MEMORY_SCALING_FACTOR * 0.8" | bc)
    CONNECTION_FACTOR=$(echo "$CONNECTION_FACTOR * 0.8" | bc)
    RPC_THREAD_FACTOR=$(echo "$RPC_THREAD_FACTOR * 0.8" | bc)
  fi
  
  # Calculate values with adjustments
  DBCACHE_MB=$(echo "$MEM_TOTAL * $MEMORY_SCALING_FACTOR" | bc | cut -d. -f1)
  
  # For connections, handle both fixed and percentage-based factors
  if [ $CONNECTION_FACTOR -ge 1 ]; then
    # Fixed value
    MAX_CONNECTIONS=$CONNECTION_FACTOR
  else
    # Percentage-based
    MAX_CONNECTIONS=$(echo "$MEM_TOTAL * $CONNECTION_FACTOR" | bc | cut -d. -f1)
  fi
  
  MEMPOOL_MB=$(echo "$MEM_TOTAL * $MEMORY_SCALING_FACTOR * 0.5" | bc | cut -d. -f1)
  RPC_THREADS=$(echo "$CPU_COUNT * $RPC_THREAD_FACTOR" | bc | cut -d. -f1)
  
  # Ensure minimum values
  RPC_THREADS=$([ $RPC_THREADS -lt 1 ] && echo 1 || echo $RPC_THREADS)
  
  # Apply disk-specific optimizations
  if [ "$DISK_TYPE" = "ssd" ]; then
    # SSD optimizations
    DBCACHE_MB=$(echo "$DBCACHE_MB * 1.2" | bc | cut -d. -f1)  # Increase cache by 20% for SSDs
    log "Applied SSD optimizations (+20% dbcache)" "INFO"
  elif [ "$DISK_TYPE" = "hdd" ]; then
    # HDD optimizations - lower concurrent I/O
    MAX_CONNECTIONS=$(echo "$MAX_CONNECTIONS * 0.8" | bc | cut -d. -f1)  # Reduce connections by 20% for HDDs
    log "Applied HDD optimizations (-20% max connections)" "INFO"
  fi
  
  # Apply speed-based optimizations
  if [ $DISK_SPEED -lt 50 ] && [ $DISK_TYPE = "hdd" ]; then
    # Slow HDD - reduce dbcache to minimize I/O contention
    DBCACHE_MB=$(echo "$DBCACHE_MB * 0.8" | bc | cut -d. -f1)
    log "Applied slow disk optimizations (-20% dbcache for slow disk)" "INFO"
  fi
  
  # Apply upper bounds for safety
  [ $DBCACHE_MB -gt 4096 ] && DBCACHE_MB=4096
  [ $MAX_CONNECTIONS -gt 125 ] && MAX_CONNECTIONS=125
  [ $MEMPOOL_MB -gt 1024 ] && MEMPOOL_MB=1024
  [ $RPC_THREADS -gt $CPU_COUNT ] && RPC_THREADS=$CPU_COUNT
  
  # Export variables
  export DBCACHE=$DBCACHE_MB
  export MAX_CONNECTIONS=$MAX_CONNECTIONS
  export MAXMEMPOOL=$MEMPOOL_MB
  export RPC_THREADS=$RPC_THREADS
}

# Export functions
export -f setup_environment
export -f validate_environment_schema
export -f setup_rpc_credentials
export -f load_config
export -f generate_secure_password
export -f validate_configuration
export -f apply_template
export -f detect_config_changes
export -f load_custom_configs
export -f calculate_resources
export -f calculate_optimal_resources