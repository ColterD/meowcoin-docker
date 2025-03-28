# scripts/entrypoint/config.sh
#!/bin/bash

# Constants
CONFIG_FILE="/home/meowcoin/.meowcoin/meowcoin.conf"
TEMPLATE_FILE="/etc/meowcoin/templates/meowcoin.conf.template"
PASSWORD_FILE="/home/meowcoin/.meowcoin/.rpcpassword"
LOG_FILE="/var/log/meowcoin/setup.log"

# Dynamic resource allocation
function calculate_resources() {
  # Get container memory limit
  if [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
    MEMORY_LIMIT=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
    MEMORY_LIMIT_MB=$((MEMORY_LIMIT / 1024 / 1024))
  else
    # Fallback to total system memory
    MEMORY_LIMIT_MB=$(free -m | grep Mem | awk '{print $2}')
  fi
  
  # Calculate optimal dbcache (50% of RAM up to 4GB)
  DBCACHE_MB=$((MEMORY_LIMIT_MB / 2))
  [ $DBCACHE_MB -gt 4000 ] && DBCACHE_MB=4000
  
  # Calculate max connections based on memory (1 conn per 32MB)
  MAX_CONNECTIONS=$((MEMORY_LIMIT_MB / 32))
  [ $MAX_CONNECTIONS -lt 12 ] && MAX_CONNECTIONS=12
  [ $MAX_CONNECTIONS -gt 125 ] && MAX_CONNECTIONS=125
  
  # Calculate mempool size (25% of RAM up to 1GB)
  MEMPOOL_MB=$((MEMORY_LIMIT_MB / 4))
  [ $MEMPOOL_MB -gt 1000 ] && MEMPOOL_MB=1000
  
  # Export as environment variables for config template
  export DBCACHE=$DBCACHE_MB
  export MAX_CONNECTIONS=$MAX_CONNECTIONS
  export MAXMEMPOOL=$MEMPOOL_MB
  
  echo "[$(date -Iseconds)] Resource allocation: dbcache=${DBCACHE}MB, maxconnections=${MAX_CONNECTIONS}, maxmempool=${MAXMEMPOOL}MB" | tee -a $LOG_FILE
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
      # Generate secure password with proper entropy
      export RPC_PASSWORD=$(openssl rand -hex 32)
      # Store password to file for persistence
      echo "$RPC_PASSWORD" > "$PASSWORD_FILE"
      chmod 600 "$PASSWORD_FILE"
      chown meowcoin:meowcoin "$PASSWORD_FILE"
      echo "[$(date -Iseconds)] Generated secure RPC password (saved to $PASSWORD_FILE)" | tee -a $LOG_FILE
    fi
  fi
  
  # Calculate optimal resource allocation
  calculate_resources
}

# Validate configuration for security issues
function validate_configuration() {
  # Check for insecure RPC settings
  if [[ "$RPC_BIND" == "0.0.0.0" ]]; then
    echo "[$(date -Iseconds)] WARNING: RPC is configured to bind to all interfaces (0.0.0.0)" | tee -a $LOG_FILE
    
    if [[ "$RPC_ALLOWIP" == "0.0.0.0/0" || "$RPC_ALLOWIP" == "*" ]]; then
      echo "[$(date -Iseconds)] CRITICAL SECURITY RISK: RPC configured to accept connections from any IP" | tee -a $LOG_FILE
      echo "[$(date -Iseconds)] This exposes your node to attacks from the internet" | tee -a $LOG_FILE
      
      # Set environment flag for security warning
      export SECURITY_WARNING="INSECURE_RPC_CONFIG"
    fi
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
}