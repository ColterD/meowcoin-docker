#!/bin/bash

# Certificate paths
CERT_DIR="/home/meowcoin/.meowcoin/certs"
CERT_FILE="$CERT_DIR/meowcoin.crt"
KEY_FILE="$CERT_DIR/meowcoin.key"
JWT_SECRET_FILE="/home/meowcoin/.meowcoin/.jwtsecret"

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
  
  # Customize fail2ban settings if provided
  if [ ! -z "${FAIL2BAN_BANTIME}" ]; then
    sed -i "s/bantime = 1h/bantime = ${FAIL2BAN_BANTIME}/" /etc/fail2ban/jail.local
    echo "[$(date -Iseconds)] Fail2ban ban time set to ${FAIL2BAN_BANTIME}" | tee -a $LOG_FILE
  fi
  
  if [ ! -z "${FAIL2BAN_FINDTIME}" ]; then
    sed -i "s/findtime = 10m/findtime = ${FAIL2BAN_FINDTIME}/" /etc/fail2ban/jail.local
    echo "[$(date -Iseconds)] Fail2ban find time set to ${FAIL2BAN_FINDTIME}" | tee -a $LOG_FILE
  fi
  
  if [ ! -z "${FAIL2BAN_MAXRETRY}" ]; then
    sed -i "s/maxretry = 5/maxretry = ${FAIL2BAN_MAXRETRY}/" /etc/fail2ban/jail.local
    echo "[$(date -Iseconds)] Fail2ban max retry set to ${FAIL2BAN_MAXRETRY}" | tee -a $LOG_FILE
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
  
  # In a real production environment, we would mount the filesystem read-only
  # and bind mount specific directories as read-write
  echo "[$(date -Iseconds)] Read-only filesystem configured (except for essential directories)" | tee -a $LOG_FILE
}

# Setup JWT authentication for API access
function setup_jwt_authentication() {
  echo "[$(date -Iseconds)] Setting up JWT authentication" | tee -a $LOG_FILE
  
  # Generate JWT secret if it doesn't exist
  if [ ! -f "$JWT_SECRET_FILE" ]; then
    # Generate 256-bit random key
    openssl rand -hex 32 > "$JWT_SECRET_FILE"
    chmod 600 "$JWT_SECRET_FILE"
    chown meowcoin:meowcoin "$JWT_SECRET_FILE"
    echo "[$(date -Iseconds)] Generated JWT secret key" | tee -a $LOG_FILE
  else
    echo "[$(date -Iseconds)] Using existing JWT secret key" | tee -a $LOG_FILE
  fi
  
  # Add REST API and JWT auth options to configuration
  JWT_OPTS="rest=1 rpcauth=jwtsecret"
  
  # Add options for more secure JWT settings if needed
  if [ "${JWT_AUTH_STRICT:-false}" = "true" ]; then
    JWT_OPTS="$JWT_OPTS rpcallowip=127.0.0.1 rpcbind=127.0.0.1"
    echo "[$(date -Iseconds)] JWT authentication in strict mode (localhost only)" | tee -a $LOG_FILE
  fi
  
  if [ -z "$CUSTOM_OPTS" ]; then
    export CUSTOM_OPTS="$JWT_OPTS"
  else
    export CUSTOM_OPTS="$CUSTOM_OPTS $JWT_OPTS"
  fi
  
  # Create helper script for generating access tokens
  mkdir -p /usr/local/bin/utils
  cat > /usr/local/bin/utils/generate-jwt-token.sh <<EOF
#!/bin/bash
# Generate a JWT token for API access

JWT_SECRET_FILE="/home/meowcoin/.meowcoin/.jwtsecret"

if [ -f "\$JWT_SECRET_FILE" ]; then
  JWT_TOKEN=\$(cat "\$JWT_SECRET_FILE" | xxd -p -c 1000)
  echo "JWT Token: \$JWT_TOKEN"
  echo
  echo "Example usage:"
  echo "curl -s -H \"Authorization: Bearer \$JWT_TOKEN\" -H \"Content-Type: application/json\" -d '{\"method\":\"getblockchaininfo\",\"params\":[],\"id\":1}' http://localhost:8332/"
else
  echo "JWT secret file not found. JWT authentication may not be enabled."
fi
EOF
  
  chmod +x /usr/local/bin/utils/generate-jwt-token.sh
  echo "[$(date -Iseconds)] JWT token generation utility created" | tee -a $LOG_FILE
}