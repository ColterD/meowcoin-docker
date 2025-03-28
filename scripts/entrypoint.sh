#!/bin/bash
set -e

# Configuration file
CONFIG_FILE="/home/meowcoin/.meowcoin/meowcoin.conf"
TEMPLATE_FILE="/home/meowcoin/.meowcoin/meowcoin.conf.template"
PASSWORD_FILE="/home/meowcoin/.meowcoin/.rpcpassword"
CERTS_DIR="/home/meowcoin/.meowcoin/certs"

# Create certs directory if it doesn't exist
mkdir -p "$CERTS_DIR"

# Generate random credentials if not provided
if [ -z "$RPC_USER" ]; then
  export RPC_USER="meowcoin"
  echo "Warning: No RPC user specified, using default: meowcoin"
fi

if [ -z "$RPC_PASSWORD" ]; then
  # Check if password file exists
  if [ -f "$PASSWORD_FILE" ]; then
    export RPC_PASSWORD=$(cat "$PASSWORD_FILE")
    echo "Using existing RPC password from $PASSWORD_FILE"
  else
    # Generate secure password
    export RPC_PASSWORD=$(openssl rand -hex 32)
    # Store password to file for persistence
    echo "$RPC_PASSWORD" > "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
    echo "Generated secure RPC password (saved to $PASSWORD_FILE)"
    echo "NOTE: Access the password by viewing the $PASSWORD_FILE file inside the container volume."
  fi
fi

# Auto-generate SSL certificates if enabled
if [ "${ENABLE_SSL:-false}" = "true" ]; then
  CERT_FILE="$CERTS_DIR/meowcoin.crt"
  KEY_FILE="$CERTS_DIR/meowcoin.key"
  
  # Generate only if they don't exist
  if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "Generating SSL certificates for RPC..."
    
    # Generate private key and certificate
    openssl req -newkey rsa:4096 -x509 -sha256 -days 3650 -nodes \
      -out "$CERT_FILE" -keyout "$KEY_FILE" \
      -subj "/CN=meowcoin-node" >/dev/null 2>&1
    
    # Set permissions
    chmod 600 "$KEY_FILE"
    chmod 644 "$CERT_FILE"
    
    echo "SSL certificates generated successfully."
  else
    echo "Using existing SSL certificates."
  fi
  
  # Add SSL options to CUSTOM_OPTS
  SSL_OPTS="rpcssl=1 rpcsslcertificatechainfile=$CERT_FILE rpcsslprivatekeyfile=$KEY_FILE"
  if [ -z "$CUSTOM_OPTS" ]; then
    export CUSTOM_OPTS="$SSL_OPTS"
  else
    export CUSTOM_OPTS="$CUSTOM_OPTS $SSL_OPTS"
  fi
fi

# Configure fail2ban if enabled
if [ "${ENABLE_FAIL2BAN:-false}" = "true" ]; then
  echo "Configuring fail2ban for RPC authentication..."
  
  # Create log directory for meowcoind
  mkdir -p /home/meowcoin/.meowcoin/logs
  
  # Add logging options to CUSTOM_OPTS
  LOG_OPTS="debug=rpc logips=1 shrinkdebugfile=0 debuglogfile=/home/meowcoin/.meowcoin/logs/debug.log"
  if [ -z "$CUSTOM_OPTS" ]; then
    export CUSTOM_OPTS="$LOG_OPTS"
  else
    export CUSTOM_OPTS="$CUSTOM_OPTS $LOG_OPTS"
  fi
  
  # Start fail2ban (needs root, will be started at container level)
  echo "Fail2ban will be started by the container supervisor."
fi

# Configure Prometheus exporter if enabled
if [ "${ENABLE_METRICS:-false}" = "true" ]; then
  echo "Configuring Prometheus metrics exporter..."
  
  # Set up specific options for metrics if needed
  METRICS_OPTS="zmqpubhashtx=tcp://127.0.0.1:28332 zmqpubhashblock=tcp://127.0.0.1:28332"
  if [ -z "$CUSTOM_OPTS" ]; then
    export CUSTOM_OPTS="$METRICS_OPTS"
  else
    export CUSTOM_OPTS="$CUSTOM_OPTS $METRICS_OPTS"
  fi
  
  # Start metrics exporter in background
  if [ -f /usr/local/bin/meowcoin-exporter ]; then
    echo "Starting Prometheus exporter on port 9449..."
    nohup /usr/local/bin/meowcoin-exporter \
      --meowcoin.rpc-user="$RPC_USER" \
      --meowcoin.rpc-password="$RPC_PASSWORD" \
      --web.listen-address=:9449 \
      >/dev/null 2>&1 &
  else
    echo "Warning: Prometheus exporter binary not found, metrics will not be available."
  fi
fi

# Configure automatic backups if enabled
if [ "${ENABLE_BACKUPS:-false}" = "true" ]; then
  echo "Setting up automatic blockchain backups..."
  
  # Create backup directory
  BACKUP_DIR="/home/meowcoin/.meowcoin/backups"
  mkdir -p "$BACKUP_DIR"
  
  # Set up cron job for backups
  BACKUP_SCHEDULE="${BACKUP_SCHEDULE:-0 0 * * *}"  # Default: midnight daily
  BACKUP_SCRIPT="/usr/local/bin/backup-blockchain.sh"
  
  if [ -f "$BACKUP_SCRIPT" ]; then
    echo "$BACKUP_SCHEDULE $BACKUP_SCRIPT > $BACKUP_DIR/backup.log 2>&1" > /tmp/backup-cron
    crontab /tmp/backup-cron
    rm /tmp/backup-cron
    echo "Automatic backups scheduled: $BACKUP_SCHEDULE"
  else
    echo "Warning: Backup script not found, automatic backups will not be enabled."
  fi
fi

# Validate RPC settings
if [[ "$RPC_BIND" == "0.0.0.0" ]]; then
  echo "WARNING: RPC is configured to bind to all interfaces (0.0.0.0)."
  
  if [[ "$RPC_ALLOWIP" == "0.0.0.0/0" || "$RPC_ALLOWIP" == "*" ]]; then
    echo "CRITICAL SECURITY RISK: Your RPC is configured to accept connections from any IP."
    echo "This exposes your node to attacks from the internet."
    echo "Consider changing RPC_ALLOWIP to a specific IP range or localhost only."
    
    # Prompt for confirmation in interactive mode
    if [ -t 0 ]; then
      read -p "Continue with insecure configuration? [y/N] " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting for security reasons. Please update your configuration."
        exit 1
      fi
    fi
  fi
fi

# Sanitize custom options
if [ ! -z "$CUSTOM_OPTS" ]; then
  # Remove any quotes that might be used for injection
  CUSTOM_OPTS=$(echo "$CUSTOM_OPTS" | tr -d '"'"'")
  export CUSTOM_OPTS
  echo "Applied custom options: $CUSTOM_OPTS"
fi

# Create config from template
envsubst < "$TEMPLATE_FILE" > "$CONFIG_FILE"
echo "Configuration generated in $CONFIG_FILE"

# First argument is command to run
if [ "${1:0:1}" = '-' ]; then
  # If first arg is a flag, prepend meowcoind
  set -- meowcoind "$@"
fi

echo "Starting Meowcoin node..."
# Execute command
exec "$@"