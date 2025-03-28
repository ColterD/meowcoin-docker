#!/bin/bash

# Constants
CONFIG_FILE="/home/meowcoin/.meowcoin/meowcoin.conf"
TEMPLATE_FILE="/etc/meowcoin/templates/meowcoin.conf.template"
PASSWORD_FILE="/home/meowcoin/.meowcoin/.rpcpassword"
LOG_FILE="/var/log/meowcoin/setup.log"

# Dynamic resource allocation
function calculate_resources() {
  # Get available memory more reliably
  if [ -f /sys/fs/cgroup/memory.max ]; then
    # For cgroups v2
    MEMORY_LIMIT=$(cat /sys/fs/cgroup/memory.max)
    if [ "$MEMORY_LIMIT" = "max" ]; then
      # No limit set, use total system memory
      MEMORY_LIMIT_MB=$(free -m | grep Mem | awk '{print $2}')
    else
      MEMORY_LIMIT_MB=$((MEMORY_LIMIT / 1024 / 1024))
    fi
  elif [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
    # For cgroups v1
    MEMORY_LIMIT=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
    MEMORY_LIMIT_MB=$((MEMORY_LIMIT / 1024 / 1024))
  else
    # Fallback to total system memory
    MEMORY_LIMIT_MB=$(free -m | grep Mem | awk '{print $2}')
  fi
  
  # More nuanced calculation based on available memory
  if [ $MEMORY_LIMIT_MB -lt 1024 ]; then
    # Low memory environment (<1GB)
    DBCACHE_MB=$((MEMORY_LIMIT_MB / 4))
    MAX_CONNECTIONS=12
    MEMPOOL_MB=$((MEMORY_LIMIT_MB / 8))
  elif [ $MEMORY_LIMIT_MB -lt 4096 ]; then
    # Medium memory environment (1-4GB)
    DBCACHE_MB=$((MEMORY_LIMIT_MB / 3))
    MAX_CONNECTIONS=$((MEMORY_LIMIT_MB / 32))
    MEMPOOL_MB=$((MEMORY_LIMIT_MB / 6))
  else
    # High memory environment (>4GB)
    DBCACHE_MB=$((MEMORY_LIMIT_MB / 2))
    [ $DBCACHE_MB -gt 4096 ] && DBCACHE_MB=4096
    MAX_CONNECTIONS=$((MEMORY_LIMIT_MB / 40))
    [ $MAX_CONNECTIONS -gt 125 ] && MAX_CONNECTIONS=125
    MEMPOOL_MB=$((MEMORY_LIMIT_MB / 4))
    [ $MEMPOOL_MB -gt 1024 ] && MEMPOOL_MB=1024
  fi
  
  # Export as environment variables for config template
  export DBCACHE=$DBCACHE_MB
  export MAX_CONNECTIONS=$MAX_CONNECTIONS
  export MAXMEMPOOL=$MEMPOOL_MB
  
  echo "[$(date -Iseconds)] Resource allocation: dbcache=${DBCACHE}MB, maxconnections=${MAX_CONNECTIONS}, maxmempool=${MAXMEMPOOL}MB" | tee -a $LOG_FILE
}

# Generate a secure password with high entropy
function generate_secure_password() {
  # Generate password with higher entropy (48 bytes instead of 32)
  local PASSWORD=$(openssl rand -hex 48)
  
  # Store with restrictive permissions
  echo "$PASSWORD" > "$PASSWORD_FILE"
  chmod 600 "$PASSWORD_FILE"
  chown meowcoin:meowcoin "$PASSWORD_FILE"
  
  echo "[$(date -Iseconds)] Generated secure RPC password with high entropy" | tee -a $LOG_FILE
  echo "$PASSWORD"
}

# Setup basic environment
function setup_environment() {
  # Create log directory
  mkdir -p /var/log/meowcoin
  chown meowcoin:meowcoin /var/log/meowcoin
  
  # Set timezone if provided
  if [ ! -z "$TZ" ]; then
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo $TZ > /etc/timezone
    echo "[$(date -Iseconds)] Set timezone to $TZ" | tee -a $LOG_FILE
  fi
  
  # Generate RPC credentials if not provided
  if [ -z "$RPC_USER" ]; then
    export RPC_USER="meowcoin"
    echo "[$(date -Iseconds)] No RPC user specified, using default: meowcoin" | tee -a $LOG_FILE
  fi

  if [ -z "$RPC_PASSWORD" ]; then
    # Check if password file exists
    if [ -f "$PASSWORD_FILE" ]; then
      export RPC_PASSWORD=$(cat "$PASSWORD_FILE")
      echo "[$(date -Iseconds)] Using existing RPC password from $PASSWORD_FILE" | tee -a $LOG_FILE
    else
      # Generate secure password with high entropy
      export RPC_PASSWORD=$(generate_secure_password)
      echo "[$(date -Iseconds)] NOTE: Access the password by viewing the $PASSWORD_FILE file inside the container volume" | tee -a $LOG_FILE
    fi
  else
    # User provided their own password, still save it for consistency
    echo "$RPC_PASSWORD" > "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
    chown meowcoin:meowcoin "$PASSWORD_FILE"
    echo "[$(date -Iseconds)] Using user-provided RPC password (saved to $PASSWORD_FILE)" | tee -a $LOG_FILE
  fi
  
  # Calculate optimal resource allocation
  calculate_resources
}

# Validate configuration for security issues
function validate_configuration() {
  local SECURITY_ISSUES=0
  
  # Check for insecure RPC settings
  if [[ "$RPC_BIND" == "0.0.0.0" ]]; then
    echo "[$(date -Iseconds)] WARNING: RPC is configured to bind to all interfaces (0.0.0.0)" | tee -a $LOG_FILE
    SECURITY_ISSUES=$((SECURITY_ISSUES+1))
    
    if [[ "$RPC_ALLOWIP" == "0.0.0.0/0" || "$RPC_ALLOWIP" == "*" ]]; then
      echo "[$(date -Iseconds)] CRITICAL SECURITY RISK: RPC configured to accept connections from any IP" | tee -a $LOG_FILE
      echo "[$(date -Iseconds)] This exposes your node to attacks from the internet" | tee -a $LOG_FILE
      SECURITY_ISSUES=$((SECURITY_ISSUES+1))
      
      # Set environment flag for security warning
      export SECURITY_WARNING="INSECURE_RPC_CONFIG"
    fi
  fi
  
  # Validate RPC password strength
  if [ ${#RPC_PASSWORD} -lt 32 ]; then
    echo "[$(date -Iseconds)] WARNING: RPC password is too short, consider using the auto-generated password" | tee -a $LOG_FILE
    SECURITY_ISSUES=$((SECURITY_ISSUES+1))
  fi
  
  # Sanitize custom options to prevent injection
  if [ ! -z "$CUSTOM_OPTS" ]; then
    # Remove any quotes or potentially dangerous characters
    CUSTOM_OPTS=$(echo "$CUSTOM_OPTS" | tr -d '"'"'\`$&|;<>{}[]()' | tr '\n' ' ')
    export CUSTOM_OPTS
    echo "[$(date -Iseconds)] Applied custom options: $CUSTOM_OPTS" | tee -a $LOG_FILE
  fi
  
  # Generate config from template with environment variables
  envsubst < "$TEMPLATE_FILE" > "$CONFIG_FILE"
  chmod 640 "$CONFIG_FILE"
  chown meowcoin:meowcoin "$CONFIG_FILE"
  echo "[$(date -Iseconds)] Configuration generated in $CONFIG_FILE" | tee -a $LOG_FILE
  
  # Summarize security validation
  if [ $SECURITY_ISSUES -gt 0 ]; then
    echo "[$(date -Iseconds)] Found $SECURITY_ISSUES potential security issues with configuration" | tee -a $LOG_FILE
  else
    echo "[$(date -Iseconds)] Configuration security validation passed" | tee -a $LOG_FILE
  fi
}