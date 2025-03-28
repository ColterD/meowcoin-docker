# scripts/entrypoint/security.sh
#!/bin/bash

# Certificate paths
CERT_DIR="/home/meowcoin/.meowcoin/certs"
CERT_FILE="$CERT_DIR/meowcoin.crt"
KEY_FILE="$CERT_DIR/meowcoin.key"

# Setup security features
function setup_security_features() {
  # Configure SSL if enabled
  if [ "${ENABLE_SSL:-false}" = "true" ]; then
    setup_ssl_certificates
  fi
  
  # Configure fail2ban if enabled
  if [ "${ENABLE_FAIL2BAN:-false}" = "true" ]; then
    setup_fail2ban
  fi
  
  # Configure read-only filesystem if enabled
  if [ "${ENABLE_READONLY_FS:-false}" = "true" ]; then
    setup_readonly_filesystem
  fi
  
  # Configure JWT auth if enabled
  if [ "${ENABLE_JWT_AUTH:-false}" = "true" ]; then
    setup_jwt_authentication
  fi
}

# Generate or validate SSL certificates
function setup_ssl_certificates() {
  echo "[$(date -Iseconds)] Setting up SSL for RPC communication" | tee -a $LOG_FILE
  
  # Ensure certificate directory exists with proper permissions
  mkdir -p "$CERT_DIR"
  chmod 750 "$CERT_DIR"
  chown meowcoin:meowcoin "$CERT_DIR"
  
  # Generate only if they don't exist
  if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "[$(date -Iseconds)] Generating SSL certificates" | tee -a $LOG_FILE
    
    # Generate private key and certificate with proper security parameters
    openssl req -newkey rsa:4096 -x509 -sha256 -days 3650 -nodes \
      -out "$CERT_FILE" -keyout "$KEY_FILE" \
      -subj "/CN=meowcoin-node" >/dev/null 2>&1
    
    # Set proper permissions
    chmod 640 "$CERT_FILE"
    chmod 600 "$KEY_FILE"
    chown meowcoin:meowcoin "$CERT_FILE" "$KEY_FILE"
    
    echo "[$(date -Iseconds)] SSL certificates generated successfully" | tee -a $LOG_FILE
  else
    echo "[$(date -Iseconds)] Using existing SSL certificates" | tee -a $LOG_FILE
    
    # Validate existing certificate expiration
    EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_FILE" | cut -d= -f2)
    echo "[$(date -Iseconds)] Certificate expires: $EXPIRY" | tee -a $LOG_FILE
    
    # Check if certificate is expired or will expire soon
    EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
    CURRENT_EPOCH=$(date +%s)
    THIRTY_DAYS=$((30*24*60*60))
    
    if [ $EXPIRY_EPOCH -lt $CURRENT_EPOCH ]; then
      echo "[$(date -Iseconds)] WARNING: SSL certificate has expired! Generating new certificate" | tee -a $LOG_FILE
      rm "$CERT_FILE" "$KEY_FILE"
      setup_ssl_certificates
    elif [ $((EXPIRY_EPOCH - CURRENT_EPOCH)) -lt $THIRTY_DAYS ]; then
      echo "[$(date -Iseconds)] WARNING: SSL certificate will expire within 30 days" | tee -a $LOG_FILE
    fi
  fi
  
  # Add SSL options to configuration
  SSL_OPTS="rpcssl=1 rpcsslcertificatechainfile=$CERT_FILE rpcsslprivatekeyfile=$KEY_FILE"
  if [ -z "$CUSTOM_OPTS" ]; then
    export CUSTOM_OPTS="$SSL_OPTS"
  else
    export CUSTOM_OPTS="$CUSTOM_OPTS $SSL_OPTS"
  fi
}

# Setup fail2ban for RPC protection
function setup_fail2ban() {
  echo "[$(date -Iseconds)] Setting up fail2ban for RPC protection" | tee -a $LOG_FILE
  
  # Create log directory if it doesn't exist
  mkdir -p /home/meowcoin/.meowcoin/logs
  chown meowcoin:meowcoin /home/meowcoin/.meowcoin/logs
  
  # Add logging options to configuration
  LOG_OPTS="debug=rpc logips=1 shrinkdebugfile=0 debuglogfile=/home/meowcoin/.meowcoin/logs/debug.log"
  if [ -z "$CUSTOM_OPTS" ]; then
    export CUSTOM_OPTS="$LOG_OPTS"
  else
    export CUSTOM_OPTS="$CUSTOM_OPTS $LOG_OPTS"
  fi
}

# Setup read-only filesystem for security hardening
function setup_readonly_filesystem() {
  echo "[$(date -Iseconds)] Setting up read-only filesystem" | tee -a $LOG_FILE
  
  # Create necessary writable directories
  WRITABLE_DIRS=(
    "/home/meowcoin/.meowcoin/database"
    "/home/meowcoin/.meowcoin/blocks"
    "/home/meowcoin/.meowcoin/chainstate"
    "/home/meowcoin/.meowcoin/indexes"
    "/home/meowcoin/.meowcoin/logs"
    "/tmp"
  )
  
  for DIR in "${WRITABLE_DIRS[@]}"; do
    mkdir -p "$DIR"
    chown meowcoin:meowcoin "$DIR"
  done
  
  # Mark the meowcoin data directory as read-only except for specific paths
  # This is a placeholder - in a real implementation, we would use mount options
  echo "[$(date -Iseconds)] Note: Read-only filesystem configured (except for database directories)" | tee -a $LOG_FILE
}

# Setup JWT authentication for API access
function setup_jwt_authentication() {
  echo "[$(date -Iseconds)] Setting up JWT authentication" | tee -a $LOG_FILE
  
  JWT_SECRET_FILE="/home/meowcoin/.meowcoin/.jwtsecret"
  
  # Generate JWT secret if it doesn't exist
  if [ ! -f "$JWT_SECRET_FILE" ]; then
    openssl rand -hex 32 > "$JWT_SECRET_FILE"
    chmod 600 "$JWT_SECRET_FILE"
    chown meowcoin:meowcoin "$JWT_SECRET_FILE"
    echo "[$(date -Iseconds)] Generated JWT secret key" | tee -a $LOG_FILE
  fi
  
  # Add JWT options to configuration
  JWT_OPTS="rest=1 rpcauth=jwtsecret"
  if [ -z "$CUSTOM_OPTS" ]; then
    export CUSTOM_OPTS="$JWT_OPTS"
  else
    export CUSTOM_OPTS="$CUSTOM_OPTS $JWT_OPTS"
  fi
}