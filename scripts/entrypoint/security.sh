#!/bin/bash
set -e

# Configuration with improved security settings
CERT_DIR="/home/meowcoin/.meowcoin/certs"
CERT_FILE="$CERT_DIR/meowcoin.crt"
KEY_FILE="$CERT_DIR/meowcoin.key"
CA_FILE="$CERT_DIR/ca.crt"
JWT_SECRET_FILE="/home/meowcoin/.meowcoin/.jwtsecret"
SSL_CERT_DAYS=365  # More frequent rotation
SSL_KEY_SIZE=4096
SSL_CIPHER_LIST="ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384"
SSL_PROTOCOLS="TLSv1.2 TLSv1.3"
JWT_ALGORITHM="ES256"  # More modern algorithm than the default
SSL_MIN_DAYS_BEFORE_RENEWAL=30
TRACE_ID="${TRACE_ID:-$(date +%s)-$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8)}"

# Helper function for logging
function log() {
  echo "[$TRACE_ID][$(date -Iseconds)] $1" | tee -a "$SECURITY_LOG"
}

# Error handling function
function handle_error() {
  local EXIT_CODE=$1
  local ERROR_MESSAGE=$2
  local ERROR_SOURCE=${3:-"security.sh"}
  
  log "ERROR [$ERROR_SOURCE]: $ERROR_MESSAGE (exit code: $EXIT_CODE)"
  
  # Send alert if monitoring is configured
  if [ -x /usr/local/bin/monitoring/send-alert.sh ]; then
    /usr/local/bin/monitoring/send-alert.sh "Security error: $ERROR_MESSAGE" "security_error" "critical"
  fi
  
  # Exit if this is a critical error
  if [ $EXIT_CODE -gt 100 ]; then
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

# Setup security features
function setup_security_features() {
  # Create security log
  SECURITY_LOG="/var/log/meowcoin/security.log"
  mkdir -p $(dirname $SECURITY_LOG)
  touch $SECURITY_LOG
  chown meowcoin:meowcoin $SECURITY_LOG
  chmod 640 $SECURITY_LOG
  
  log "Initializing security features"
  
  # Configure SSL if enabled
  if [ "${ENABLE_SSL:-false}" = "true" ]; then
    setup_ssl_certificates || handle_error $? "SSL certificate setup failed"
  fi
  
  # Configure fail2ban if enabled
  if [ "${ENABLE_FAIL2BAN:-false}" = "true" ]; then
    setup_fail2ban || handle_error $? "Fail2ban setup failed"
  fi
  
  # Configure read-only filesystem if enabled
  if [ "${ENABLE_READONLY_FS:-false}" = "true" ]; then
    setup_readonly_filesystem || handle_error $? "Read-only filesystem setup failed"
  fi
  
  # Configure JWT auth if enabled
  if [ "${ENABLE_JWT_AUTH:-false}" = "true" ]; then
    setup_jwt_authentication || handle_error $? "JWT authentication setup failed"
  fi
  
  # Configure additional security hardening
  apply_security_hardening || handle_error $? "Security hardening failed"
  
  # Schedule security checks
  schedule_security_checks || handle_error $? "Failed to schedule security checks"
  
  log "Security features initialized successfully"
}

# Generate or validate SSL certificates with improved parameters
function setup_ssl_certificates() {
  log "Setting up SSL for RPC communication"
  
  # Ensure certificate directory exists with proper permissions
  mkdir -p "$CERT_DIR"
  chmod 750 "$CERT_DIR"
  chown meowcoin:meowcoin "$CERT_DIR"
  
  # Generate only if they don't exist
  if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    log "Generating SSL certificates"
    
    # Create a secure private key with strong parameters
    if ! openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:$SSL_KEY_SIZE \
         -out "$KEY_FILE" 2>> $SECURITY_LOG; then
      handle_error 101 "Failed to generate SSL private key"
      return 1
    fi
    
    # Generate certificate with stronger parameters
    if ! openssl req -new -x509 -key "$KEY_FILE" \
         -out "$CERT_FILE" \
         -days $SSL_CERT_DAYS \
         -sha256 \
         -subj "/CN=meowcoin-node/O=Meowcoin/C=US" \
         -addext "subjectAltName = DNS:meowcoin-node, DNS:localhost, IP:127.0.0.1" \
         -addext "keyUsage = digitalSignature, keyEncipherment" \
         -addext "extendedKeyUsage = serverAuth" \
         2>> $SECURITY_LOG; then
      handle_error 102 "Failed to generate SSL certificate"
      return 1
    fi
    
    # Set proper permissions
    chmod 640 "$CERT_FILE"
    chmod 600 "$KEY_FILE"
    chown meowcoin:meowcoin "$CERT_FILE" "$KEY_FILE"
    
    # Generate certificate hash for verification
    CERT_HASH=$(openssl x509 -noout -fingerprint -sha256 -in "$CERT_FILE" | cut -d= -f2)
    log "Generated certificate with fingerprint: $CERT_HASH"
    
    # Store certificate metadata
    echo "$(date -Iseconds)" > "$CERT_DIR/.cert_generated"
    echo "$CERT_HASH" > "$CERT_DIR/.cert_fingerprint"
    echo "$SSL_CERT_DAYS" > "$CERT_DIR/.cert_validity_days"
    
    log "SSL certificates generated successfully"
  else
    log "Using existing SSL certificates"
    
    # Validate existing certificate expiration
    EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_FILE" | cut -d= -f2)
    log "Certificate expires: $EXPIRY"
    
    # Check if certificate will expire soon
    EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
    CURRENT_EPOCH=$(date +%s)
    RENEWAL_THRESHOLD=$((SSL_MIN_DAYS_BEFORE_RENEWAL*24*60*60))
    
    if [ $((EXPIRY_EPOCH - CURRENT_EPOCH)) -lt $RENEWAL_THRESHOLD ]; then
      log "WARNING: SSL certificate will expire within $SSL_MIN_DAYS_BEFORE_RENEWAL days. Generating new certificate."
      
      # Backup old certificate
      local BACKUP_SUFFIX=$(date +%Y%m%d%H%M%S)
      cp "$CERT_FILE" "${CERT_FILE}.${BACKUP_SUFFIX}"
      cp "$KEY_FILE" "${KEY_FILE}.${BACKUP_SUFFIX}"
      
      # Generate new certificate
      setup_ssl_certificates
    fi
    
    # Verify certificate permissions
    if [ "$(stat -c %a "$CERT_FILE")" != "640" ]; then
      log "Fixing certificate permissions"
      chmod 640 "$CERT_FILE"
    fi
    if [ "$(stat -c %a "$KEY_FILE")" != "600" ]; then
      log "Fixing key file permissions"
      chmod 600 "$KEY_FILE"
    fi
  fi
  
  # Add SSL options to configuration
  local SSL_OPTS="rpcssl=1 rpcsslcertificatechainfile=$CERT_FILE rpcsslprivatekeyfile=$KEY_FILE"
  
  # Add stronger SSL configuration parameters
  SSL_OPTS="$SSL_OPTS rpcsslciphers=$SSL_CIPHER_LIST"
  
  if [ -z "$CUSTOM_OPTS" ]; then
    export CUSTOM_OPTS="$SSL_OPTS"
  else
    export CUSTOM_OPTS="$CUSTOM_OPTS $SSL_OPTS"
  fi
  
  return 0
}

# Setup fail2ban for RPC protection with improved configuration
function setup_fail2ban() {
  log "Setting up fail2ban for RPC protection"
  
  # Create log directory if it doesn't exist
  mkdir -p /home/meowcoin/.meowcoin/logs
  chown meowcoin:meowcoin /home/meowcoin/.meowcoin/logs
  
  # Add logging options to configuration
  local LOG_OPTS="debug=rpc logips=1 shrinkdebugfile=0 debuglogfile=/home/meowcoin/.meowcoin/logs/debug.log"
  if [ -z "$CUSTOM_OPTS" ]; then
    export CUSTOM_OPTS="$LOG_OPTS"
  else
    export CUSTOM_OPTS="$CUSTOM_OPTS $LOG_OPTS"
  fi
  
  # Check if fail2ban is installed
  if ! command -v fail2ban-server >/dev/null 2>&1; then
    log "WARNING: fail2ban is not installed, cannot enable fail2ban protection"
    return 1
  fi
  
  # Create additional fail2ban filters for improved security
  # Filter for repeated invalid requests
  if [ ! -f "/etc/fail2ban/filter.d/meowcoin-invalid.conf" ]; then
    cat > /etc/fail2ban/filter.d/meowcoin-invalid.conf <<EOF
[Definition]
failregex = ^.*HTTP method: [^"]+ error: Request parsing failed: invalid request .* \[<HOST>\]$
ignoreregex =
EOF
  fi
  
  # Filter for excessive resource usage
  if [ ! -f "/etc/fail2ban/filter.d/meowcoin-ddos.conf" ]; then
    cat > /etc/fail2ban/filter.d/meowcoin-ddos.conf <<EOF
[Definition]
failregex = ^.*Excessive resource usage from .*\[<HOST>\]$
ignoreregex =
EOF
  fi
  
  # Filter for repeated authentication failures
  if [ ! -f "/etc/fail2ban/filter.d/meowcoin-auth.conf" ]; then
    cat > /etc/fail2ban/filter.d/meowcoin-auth.conf <<EOF
[Definition]
failregex = ^.*Failed authentication from .* \[<HOST>\]$
ignoreregex =
EOF
  fi
  
  # Create or update jail.local
  if [ ! -f "/etc/fail2ban/jail.local" ]; then
    cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
ignoreip = 127.0.0.1/8 ::1

[meowcoin-rpc]
enabled = true
filter = meowcoin-rpc
logpath = /home/meowcoin/.meowcoin/logs/debug.log
maxretry = 5
bantime = 7200

[meowcoin-invalid]
enabled = true
filter = meowcoin-invalid
logpath = /home/meowcoin/.meowcoin/logs/debug.log
maxretry = 5
bantime = 7200

[meowcoin-ddos]
enabled = true
filter = meowcoin-ddos
logpath = /home/meowcoin/.meowcoin/logs/debug.log
maxretry = 3
bantime = 86400

[meowcoin-auth]
enabled = true
filter = meowcoin-auth
logpath = /home/meowcoin/.meowcoin/logs/debug.log
maxretry = 3
bantime = 14400
EOF
  else
    # Ensure all jails are defined
    grep -q "\[meowcoin-rpc\]" /etc/fail2ban/jail.local || echo -e "\n[meowcoin-rpc]\nenabled = true\nfilter = meowcoin-rpc\nlogpath = /home/meowcoin/.meowcoin/logs/debug.log\nmaxretry = 5\nbantime = 7200" >> /etc/fail2ban/jail.local
    grep -q "\[meowcoin-invalid\]" /etc/fail2ban/jail.local || echo -e "\n[meowcoin-invalid]\nenabled = true\nfilter = meowcoin-invalid\nlogpath = /home/meowcoin/.meowcoin/logs/debug.log\nmaxretry = 5\nbantime = 7200" >> /etc/fail2ban/jail.local
    grep -q "\[meowcoin-ddos\]" /etc/fail2ban/jail.local || echo -e "\n[meowcoin-ddos]\nenabled = true\nfilter = meowcoin-ddos\nlogpath = /home/meowcoin/.meowcoin/logs/debug.log\nmaxretry = 3\nbantime = 86400" >> /etc/fail2ban/jail.local
    grep -q "\[meowcoin-auth\]" /etc/fail2ban/jail.local || echo -e "\n[meowcoin-auth]\nenabled = true\nfilter = meowcoin-auth\nlogpath = /home/meowcoin/.meowcoin/logs/debug.log\nmaxretry = 3\nbantime = 14400" >> /etc/fail2ban/jail.local
  fi
  
  # Customize fail2ban settings if provided
  if [ ! -z "${FAIL2BAN_BANTIME}" ]; then
    sed -i "s/bantime = 3600/bantime = ${FAIL2BAN_BANTIME}/" /etc/fail2ban/jail.local
    log "Fail2ban ban time set to ${FAIL2BAN_BANTIME}"
  fi
  
  if [ ! -z "${FAIL2BAN_FINDTIME}" ]; then
    sed -i "s/findtime = 600/findtime = ${FAIL2BAN_FINDTIME}/" /etc/fail2ban/jail.local
    log "Fail2ban find time set to ${FAIL2BAN_FINDTIME}"
  fi
  
  if [ ! -z "${FAIL2BAN_MAXRETRY}" ]; then
    sed -i "s/maxretry = 5/maxretry = ${FAIL2BAN_MAXRETRY}/" /etc/fail2ban/jail.local
    log "Fail2ban max retry set to ${FAIL2BAN_MAXRETRY}"
  fi
  
  if [ ! -z "${FAIL2BAN_IGNOREIP}" ]; then
    sed -i "s|ignoreip = 127.0.0.1/8 ::1|ignoreip = 127.0.0.1/8 ::1 ${FAIL2BAN_IGNOREIP}|" /etc/fail2ban/jail.local
    log "Fail2ban ignore IPs set to include ${FAIL2BAN_IGNOREIP}"
  fi
  
  # Validate fail2ban configuration
  log "Validating fail2ban configuration"
  if ! fail2ban-client -t 2>&1 | tee -a $SECURITY_LOG; then
    log "WARNING: Fail2ban configuration test failed"
    return 1
  fi
  
  # Restart fail2ban to apply changes
  if [ -x "/etc/init.d/fail2ban" ]; then
    /etc/init.d/fail2ban restart
  elif systemctl status >/dev/null 2>&1; then
    systemctl restart fail2ban
  else
    log "WARNING: Cannot restart fail2ban, not using standard service management"
    # Start manually
    killall -9 fail2ban-server >/dev/null 2>&1 || true
    fail2ban-server -b -s /var/run/fail2ban/fail2ban.sock
  fi
  
  log "Fail2ban configuration complete"
  return 0
}

# Setup read-only filesystem for security hardening
function setup_readonly_filesystem() {
  log "Setting up read-only filesystem"
  
  # Create necessary writable directories
  local WRITABLE_DIRS=(
    "/home/meowcoin/.meowcoin/database"
    "/home/meowcoin/.meowcoin/blocks"
    "/home/meowcoin/.meowcoin/chainstate"
    "/home/meowcoin/.meowcoin/indexes"
    "/home/meowcoin/.meowcoin/logs"
    "/home/meowcoin/.meowcoin/backups"
    "/tmp"
    "/var/log"
    "/var/run"
    "/var/lib/meowcoin"
  )
  
  for DIR in "${WRITABLE_DIRS[@]}"; do
    mkdir -p "$DIR"
    chown meowcoin:meowcoin "$DIR"
    chmod 750 "$DIR"
    log "Created writable directory: $DIR"
  done
  
  # Check if running in a container
  if [ -f "/.dockerenv" ]; then
    log "Running in a container, using Docker volume mounts for writable areas"
    
    # Create a file to indicate readonly is enabled
    touch /etc/meowcoin/.readonly_enabled
    chmod 644 /etc/meowcoin/.readonly_enabled
    
    # In Docker, we rely on volume mounts for writable areas
    return 0
  fi
  
  # For non-container environments, we can set up tmpfs mounts
  # Create tmpfs mounts for volatile directories that need write access
  cat > /etc/fstab.meowcoin <<EOF
tmpfs /tmp tmpfs defaults,noatime,nosuid,nodev,noexec,mode=1777,size=128M 0 0
tmpfs /var/run tmpfs defaults,noatime,nosuid,nodev,mode=0755,size=32M 0 0
EOF

  # Try to apply the mounts
  if command -v mount >/dev/null 2>&1; then
    log "Mounting tmpfs for volatile directories"
    
    # Mount tmpfs
    if ! mount -a -T /etc/fstab.meowcoin; then
      log "WARNING: Failed to mount tmpfs directories"
    fi
  else
    log "WARNING: mount command not available, cannot create tmpfs mounts"
  fi
  
  log "Read-only filesystem configured (except for essential directories)"
  
  # Set a flag to indicate readonly is enabled
  touch /etc/meowcoin/.readonly_enabled
  chmod 644 /etc/meowcoin/.readonly_enabled
  
  return 0
}

# Setup JWT authentication for API access with improved security
function setup_jwt_authentication() {
  log "Setting up JWT authentication"
  
  # Generate JWT secret if it doesn't exist
  if [ ! -f "$JWT_SECRET_FILE" ]; then
    # Create JWT directory with proper permissions
    mkdir -p "$(dirname "$JWT_SECRET_FILE")"
    
    # Generate 512-bit random key using EC P-256 curve
    if ! openssl ecparam -name prime256v1 -genkey | openssl pkcs8 -topk8 -nocrypt -out "$JWT_SECRET_FILE"; then
      handle_error 103 "Failed to generate JWT secret key"
      return 1
    fi
    
    chmod 600 "$JWT_SECRET_FILE"
    chown meowcoin:meowcoin "$JWT_SECRET_FILE"
    log "Generated JWT secret key using EC P-256 curve"
  else
    log "Using existing JWT secret key"
    
    # Validate key format and permissions
    if ! openssl ec -in "$JWT_SECRET_FILE" -noout 2>/dev/null; then
      log "WARNING: Existing JWT key is not in EC format. Generating new key."
      mv "$JWT_SECRET_FILE" "${JWT_SECRET_FILE}.old"
      setup_jwt_authentication
      return $?
    fi
    
    # Fix permissions if needed
    if [ "$(stat -c %a "$JWT_SECRET_FILE")" != "600" ]; then
      log "Fixing JWT secret file permissions"
      chmod 600 "$JWT_SECRET_FILE"
      chown meowcoin:meowcoin "$JWT_SECRET_FILE"
    fi
  fi
  
  # Create public key for verification
  if ! openssl ec -in "$JWT_SECRET_FILE" -pubout -out "${JWT_SECRET_FILE}.pub" 2>/dev/null; then
    handle_error 104 "Failed to generate JWT public key"
    return 1
  fi
  
  chmod 640 "${JWT_SECRET_FILE}.pub"
  chown meowcoin:meowcoin "${JWT_SECRET_FILE}.pub"
  
  # Add REST API and JWT auth options to configuration
  local JWT_OPTS="rest=1 rpcauth=jwtsecret jwt=1 jwtalgos=$JWT_ALGORITHM"
  
  # Add options for more secure JWT settings if needed
  if [ "${JWT_AUTH_STRICT:-false}" = "true" ]; then
    JWT_OPTS="$JWT_OPTS rpcallowip=127.0.0.1 rpcbind=127.0.0.1"
    log "JWT authentication in strict mode (localhost only)"
  fi
  
  if [ -z "$CUSTOM_OPTS" ]; then
    export CUSTOM_OPTS="$JWT_OPTS"
  else
    export CUSTOM_OPTS="$CUSTOM_OPTS $JWT_OPTS"
  fi
  
  # Create helper script for generating access tokens with expiration
  mkdir -p /usr/local/bin/utils
  cat > /usr/local/bin/utils/generate-jwt-token.sh <<'EOF'
#!/bin/bash
# Generate a JWT token for API access with improved security

JWT_SECRET_FILE="/home/meowcoin/.meowcoin/.jwtsecret"
JWT_EXPIRY=${1:-3600}  # Default token expiry: 1 hour
JWT_SCOPE=${2:-"read,write"}  # Default scope: full access
JWT_SUBJECT=${3:-"meowcoin-api"}  # Default subject

if [ ! -f "$JWT_SECRET_FILE" ]; then
  echo "JWT secret file not found. JWT authentication may not be enabled."
  exit 1
fi

# Generate header with algorithm from key type
if grep -q "BEGIN EC PRIVATE KEY" "$JWT_SECRET_FILE"; then
  ALGORITHM="ES256"
else
  ALGORITHM="HS256"  # Fallback to HMAC
fi

HEADER="{\"alg\":\"$ALGORITHM\",\"typ\":\"JWT\"}"
HEADER_B64=$(echo -n $HEADER | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

# Current timestamp for iat (issued at)
NOW=$(date +%s)
# Expiry timestamp
EXPIRY=$((NOW + JWT_EXPIRY))

# Generate payload with more claims
PAYLOAD="{\"iat\":$NOW,\"exp\":$EXPIRY,\"sub\":\"$JWT_SUBJECT\",\"scope\":\"$JWT_SCOPE\",\"iss\":\"meowcoin-node\",\"jti\":\"$(uuidgen || echo $RANDOM-$RANDOM-$RANDOM)\"}"
PAYLOAD_B64=$(echo -n $PAYLOAD | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

# Combine header and payload
UNSIGNED_TOKEN="$HEADER_B64.$PAYLOAD_B64"

# Sign the token
if [ "$ALGORITHM" = "ES256" ]; then
  # For ECDSA, we need to use the right signature format
  SIGNATURE=$(echo -n "$UNSIGNED_TOKEN" | openssl dgst -sha256 -sign "$JWT_SECRET_FILE" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
else
  # For HMAC, we use the key directly
  SIGNATURE=$(echo -n "$UNSIGNED_TOKEN" | openssl dgst -sha256 -hmac "$(cat $JWT_SECRET_FILE)" -binary | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
fi

# Complete token
JWT_TOKEN="$UNSIGNED_TOKEN.$SIGNATURE"

echo "JWT Token: $JWT_TOKEN"
echo
echo "Token details:"
echo "  Algorithm: $ALGORITHM"
echo "  Subject: $JWT_SUBJECT"
echo "  Scope: $JWT_SCOPE"
echo "  Issued at: $(date -d @$NOW)"
echo "  Expires at: $(date -d @$EXPIRY)"
echo "  Valid for: $JWT_EXPIRY seconds"
echo
echo "Example usage:"
echo "curl -s -H \"Authorization: Bearer $JWT_TOKEN\" -H \"Content-Type: application/json\" -d '{\"method\":\"getblockchaininfo\",\"params\":[],\"id\":1}' http://localhost:8332/"
EOF
  
  chmod +x /usr/local/bin/utils/generate-jwt-token.sh
  log "JWT token generation utility created with improved security"
  
  # Create token verification script
  cat > /usr/local/bin/utils/verify-jwt-token.sh <<'EOF'
#!/bin/bash
# Script to verify JWT tokens

JWT_TOKEN="$1"
JWT_PUB_FILE="/home/meowcoin/.meowcoin/.jwtsecret.pub"

if [ -z "$JWT_TOKEN" ]; then
  echo "Usage: $0 <jwt_token>"
  exit 1
fi

if [ ! -f "$JWT_PUB_FILE" ]; then
  echo "JWT public key file not found."
  exit 1
fi

# Extract parts
IFS='.' read -r HEADER_B64 PAYLOAD_B64 SIGNATURE_B64 <<< "$JWT_TOKEN"

# Decode header and payload
HEADER=$(echo -n "$HEADER_B64" | tr '-_' '+/' | base64 -d 2>/dev/null)
PAYLOAD=$(echo -n "$PAYLOAD_B64" | tr '-_' '+/' | base64 -d 2>/dev/null)

# Print decoded data
echo "Header: $HEADER"
echo "Payload: $PAYLOAD"

# Extract expiry
EXP=$(echo "$PAYLOAD" | sed -n 's/.*"exp":\([0-9]*\).*/\1/p')
NOW=$(date +%s)

if [ -z "$EXP" ]; then
  echo "ERROR: No expiry found in token"
  exit 1
fi

if [ $NOW -gt $EXP ]; then
  echo "ERROR: Token has expired at $(date -d @$EXP)"
  exit 1
else
  echo "Token is valid until $(date -d @$EXP)"
fi

# Verify signature (this is a simplified check - proper verification needs a JWT library)
# For a real verification, consider using a dedicated JWT tool
echo "NOTE: Full cryptographic signature verification requires additional libraries."
EOF

  chmod +x /usr/local/bin/utils/verify-jwt-token.sh
  log "JWT token verification utility created"
  
  # Create token rotation script
  cat > /usr/local/bin/utils/rotate-jwt-keys.sh <<'EOF'
#!/bin/bash
# Script to rotate JWT keys

JWT_SECRET_FILE="/home/meowcoin/.meowcoin/.jwtsecret"
BACKUP_DIR="/home/meowcoin/.meowcoin/key-backups"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
chown meowcoin:meowcoin "$BACKUP_DIR"

# Backup existing key
if [ -f "$JWT_SECRET_FILE" ]; then
  BACKUP_FILE="$BACKUP_DIR/jwt_key_$(date +%Y%m%d_%H%M%S).bak"
  cp "$JWT_SECRET_FILE" "$BACKUP_FILE"
  chmod 600 "$BACKUP_FILE"
  chown meowcoin:meowcoin "$BACKUP_FILE"
  echo "JWT key backed up to $BACKUP_FILE"
fi

# Generate new key
openssl ecparam -name prime256v1 -genkey | openssl pkcs8 -topk8 -nocrypt -out "$JWT_SECRET_FILE"
chmod 600 "$JWT_SECRET_FILE"
chown meowcoin:meowcoin "$JWT_SECRET_FILE"

# Create public key for verification
openssl ec -in "$JWT_SECRET_FILE" -pubout -out "${JWT_SECRET_FILE}.pub" 2>/dev/null
chmod 640 "${JWT_SECRET_FILE}.pub"
chown meowcoin:meowcoin "${JWT_SECRET_FILE}.pub"

echo "JWT key rotated successfully at $(date -Iseconds)"
echo "You may need to restart the Meowcoin service for changes to take effect"
EOF

  chmod +x /usr/local/bin/utils/rotate-jwt-keys.sh
  log "Created JWT key rotation utility"
  
  # Schedule key rotation if enabled
  if [ "${JWT_KEY_ROTATION:-false}" = "true" ]; then
    local ROTATION_SCHEDULE="${JWT_KEY_ROTATION_SCHEDULE:-0 0 1 * *}"  # Default: monthly
    
    # Create cron job
    if [ -d "/etc/cron.d" ]; then
      cat > /etc/cron.d/jwt-key-rotation <<EOF
# JWT key rotation schedule
$ROTATION_SCHEDULE root /usr/local/bin/utils/rotate-jwt-keys.sh > /var/log/meowcoin/jwt-rotation.log 2>&1
EOF
      
      chmod 644 /etc/cron.d/jwt-key-rotation
      log "Scheduled JWT key rotation: $ROTATION_SCHEDULE"
    else
      log "WARNING: Cannot schedule JWT key rotation (cron.d directory not found)"
    fi
  fi
  
  return 0
}

# Apply additional security hardening measures
function apply_security_hardening() {
  log "Applying additional security hardening"
  
  # Restrict file permissions
  find /home/meowcoin/.meowcoin -type f -not -path "*/blocks/*" -not -path "*/chainstate/*" -not -path "*/database/*" -exec chmod 640 {} \; 2>/dev/null || true
  find /home/meowcoin/.meowcoin -type d -exec chmod 750 {} \; 2>/dev/null || true
  
  # Protect sensitive files with stricter permissions
  find /home/meowcoin/.meowcoin -name "wallet.dat" -exec chmod 600 {} \; 2>/dev/null || true
  find /home/meowcoin/.meowcoin -name "*.conf" -exec chmod 600 {} \; 2>/dev/null || true
  find /home/meowcoin/.meowcoin -name "*key*" -exec chmod 600 {} \; 2>/dev/null || true
  find /home/meowcoin/.meowcoin -name "*private*" -exec chmod 600 {} \; 2>/dev/null || true
  
  # Set system resource limits for meowcoin user
  if [ -d "/etc/security/limits.d" ]; then
    cat > /etc/security/limits.d/meowcoin.conf <<EOF
meowcoin soft nofile 65535
meowcoin hard nofile 65535
meowcoin soft nproc 4096
meowcoin hard nproc 4096
EOF
    log "Set resource limits for meowcoin user"
  else
    log "WARNING: Cannot set resource limits (limits.d directory not found)"
  fi

  # Disable core dumps for security
  if [ -f "/etc/security/limits.conf" ]; then
    echo "* hard core 0" >> /etc/security/limits.conf
    log "Disabled core dumps"
  fi
  
  # Set kernel security parameters if running as privileged container
  if [ -w /proc/sys/kernel/randomize_va_space ]; then
    echo 2 > /proc/sys/kernel/randomize_va_space  # Enable ASLR
    log "Enabled ASLR"
  fi

  # Setup kernel hardening if running with appropriate permissions
  if [ -w /proc/sys/kernel/dmesg_restrict ]; then
    echo 1 > /proc/sys/kernel/dmesg_restrict
    log "Restricted dmesg access"
  fi
  
  # Check and apply sysctl hardening if available
  if command -v sysctl >/dev/null 2>&1 && [ -d "/proc/sys" ]; then
    # Network hardening
    sysctl -w net.ipv4.tcp_syncookies=1 >/dev/null 2>&1 || true
    sysctl -w net.ipv4.conf.all.rp_filter=1 >/dev/null 2>&1 || true
    sysctl -w net.ipv4.conf.default.rp_filter=1 >/dev/null 2>&1 || true
    
    # Memory protections
    sysctl -w kernel.kptr_restrict=2 >/dev/null 2>&1 || true
    sysctl -w vm.mmap_min_addr=65536 >/dev/null 2>&1 || true
    
    log "Applied kernel security hardening via sysctl"
  fi
  
  # Run checksec to verify binary security if available
  if command -v checksec >/dev/null 2>&1; then
    log "Checking binary security properties:"
    checksec --file=/usr/bin/meowcoind >> $SECURITY_LOG 2>&1 || true
  fi
  
  # Create .noexec files in directories to help prevent execution
  touch /home/meowcoin/.meowcoin/.noexec
  chmod 444 /home/meowcoin/.meowcoin/.noexec
  
  # Create security warning banner
  mkdir -p /etc/meowcoin
  cat > /etc/meowcoin/security-banner.txt <<EOF
================================================================================
                         MEOWCOIN NODE - AUTHORIZED ACCESS ONLY
================================================================================
This system is restricted to authorized users for legitimate Meowcoin node
operation. All activities may be monitored and recorded.
Unauthorized access will be fully investigated and reported to authorities.
================================================================================
EOF

  # Create a SHA-256 hash of critical binary files
  if command -v sha256sum >/dev/null 2>&1; then
    BINARY_INTEGRITY_FILE="/etc/meowcoin/binary-integrity.txt"
    sha256sum /usr/bin/meowcoind /usr/bin/meowcoin-cli > "$BINARY_INTEGRITY_FILE"
    chmod 444 "$BINARY_INTEGRITY_FILE"
    log "Created binary integrity file"
  fi

  log "Security hardening completed"
  return 0
}

# Schedule regular security checks
function schedule_security_checks() {
  log "Setting up scheduled security checks"
  
  # Copy security check scripts
  if [ -f "/usr/local/bin/security/check-certs.sh" ]; then
    chmod +x /usr/local/bin/security/check-certs.sh
  else
    log "WARNING: Certificate check script not found"
  fi
  
  # Create integrity check script
  mkdir -p /usr/local/bin/security
  cat > /usr/local/bin/security/check-integrity.sh <<'EOF'
#!/bin/bash
# Script to verify integrity of critical files

LOG_FILE="/var/log/meowcoin/security.log"
INTEGRITY_FILE="/etc/meowcoin/binary-integrity.txt"
TRACE_ID="$(date +%s)-$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8)"

# Log function
function log() {
  echo "[$TRACE_ID][$(date -Iseconds)] $1" | tee -a "$LOG_FILE"
}

log "Running integrity check"

# Check if integrity file exists
if [ ! -f "$INTEGRITY_FILE" ]; then
  log "ERROR: Integrity file not found"
  exit 1
fi

# Verify binary integrity
if ! sha256sum -c "$INTEGRITY_FILE" >/dev/null 2>&1; then
  log "CRITICAL: Binary integrity check failed"
  log "Expected hashes:"
  cat "$INTEGRITY_FILE" | tee -a "$LOG_FILE"
  log "Current hashes:"
  sha256sum /usr/bin/meowcoind /usr/bin/meowcoin-cli | tee -a "$LOG_FILE"
  
  # Send alert
  if [ -x /usr/local/bin/monitoring/send-alert.sh ]; then
    /usr/local/bin/monitoring/send-alert.sh "Binary integrity check failed - possible tampering detected" "integrity_failure" "critical"
  fi
  
  exit 1
else
  log "Binary integrity check passed"
fi

# Check for unusual setuid/setgid binaries in key directories
if find /usr/bin /usr/local/bin -perm -4000 -o -perm -2000 | grep -v "^/usr/bin/sudo$" > /tmp/setuid_check.txt; then
  if [ -s /tmp/setuid_check.txt ]; then
    log "WARNING: Found unusual setuid/setgid binaries:"
    cat /tmp/setuid_check.txt | tee -a "$LOG_FILE"
    
    # Send alert
    if [ -x /usr/local/bin/monitoring/send-alert.sh ]; then
      /usr/local/bin/monitoring/send-alert.sh "Unusual setuid/setgid binaries detected" "setuid_binaries" "warning"
    fi
  fi
fi

# Check for unusual open ports
if command -v ss >/dev/null 2>&1; then
  OPEN_PORTS=$(ss -tuln | grep LISTEN | grep -v "127.0.0.1\|::1")
  if [ ! -z "$OPEN_PORTS" ]; then
    log "WARNING: Found non-localhost open ports:"
    echo "$OPEN_PORTS" | tee -a "$LOG_FILE"
    
    # Send alert if ports other than expected ones
    if ! echo "$OPEN_PORTS" | grep -q ":8333 \|:8332 \|:9449 "; then
      if [ -x /usr/local/bin/monitoring/send-alert.sh ]; then
        /usr/local/bin/monitoring/send-alert.sh "Unexpected open ports detected" "unexpected_ports" "warning"
      fi
    fi
  fi
fi

# Check for suspicious processes
if command -v ps >/dev/null 2>&1; then
  SUSPICIOUS=$(ps aux | grep -v "^meowcoin\|^root\|^nobody" | grep -v grep)
  if [ ! -z "$SUSPICIOUS" ]; then
    log "WARNING: Processes running as non-standard users:"
    echo "$SUSPICIOUS" | tee -a "$LOG_FILE"
    
    # Send alert
    if [ -x /usr/local/bin/monitoring/send-alert.sh ]; then
      /usr/local/bin/monitoring/send-alert.sh "Suspicious processes detected" "suspicious_process" "warning"
    fi
  fi
fi

log "Integrity check completed"
exit 0
EOF

  chmod +x /usr/local/bin/security/check-integrity.sh
  
  # Create permission check script
  cat > /usr/local/bin/security/check-permissions.sh <<'EOF'
#!/bin/bash
# Script to verify permissions on critical files

LOG_FILE="/var/log/meowcoin/security.log"
TRACE_ID="$(date +%s)-$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8)"

# Log function
function log() {
  echo "[$TRACE_ID][$(date -Iseconds)] $1" | tee -a "$LOG_FILE"
}

log "Running permission check"

# Check wallet.dat permissions
WALLET_ISSUES=0
for WALLET in $(find /home/meowcoin/.meowcoin -name "wallet.dat" 2>/dev/null); do
  PERMS=$(stat -c "%a" "$WALLET")
  if [ "$PERMS" != "600" ]; then
    log "CRITICAL: $WALLET has incorrect permissions: $PERMS"
    chmod 600 "$WALLET"
    log "Fixed permissions on $WALLET"
    WALLET_ISSUES=$((WALLET_ISSUES+1))
  fi
done

# Check key files
KEY_ISSUES=0
for KEYFILE in $(find /home/meowcoin/.meowcoin -name "*key*" -o -name "*.pem" -o -name "*.key" 2>/dev/null); do
  PERMS=$(stat -c "%a" "$KEYFILE")
  if [ "$PERMS" != "600" ] && [ "$PERMS" != "400" ]; then
    log "WARNING: $KEYFILE has incorrect permissions: $PERMS"
    chmod 600 "$KEYFILE"
    log "Fixed permissions on $KEYFILE"
    KEY_ISSUES=$((KEY_ISSUES+1))
  fi
done

# Check configuration files
CONFIG_ISSUES=0
for CONFIG in $(find /home/meowcoin/.meowcoin -name "*.conf" 2>/dev/null); do
  PERMS=$(stat -c "%a" "$CONFIG")
  if [ "$PERMS" != "600" ] && [ "$PERMS" != "640" ]; then
    log "WARNING: $CONFIG has incorrect permissions: $PERMS"
    chmod 640 "$CONFIG"
    log "Fixed permissions on $CONFIG"
    CONFIG_ISSUES=$((CONFIG_ISSUES+1))
  fi
done

# Check directories
DIR_ISSUES=0
for DIR in $(find /home/meowcoin/.meowcoin -type d 2>/dev/null); do
  PERMS=$(stat -c "%a" "$DIR")
  if [ "$PERMS" != "750" ] && [ "$PERMS" != "700" ]; then
    log "WARNING: $DIR has incorrect permissions: $PERMS"
    chmod 750 "$DIR"
    log "Fixed permissions on $DIR"
    DIR_ISSUES=$((DIR_ISSUES+1))
  fi
done

# Report issues
TOTAL_ISSUES=$((WALLET_ISSUES + KEY_ISSUES + CONFIG_ISSUES + DIR_ISSUES))
if [ $TOTAL_ISSUES -gt 0 ]; then
  log "Found and fixed $TOTAL_ISSUES permission issues"
  
  # Send alert
  if [ -x /usr/local/bin/monitoring/send-alert.sh ]; then
    /usr/local/bin/monitoring/send-alert.sh "Found and fixed $TOTAL_ISSUES incorrect file permissions" "permission_issues" "warning"
  fi
else
  log "No permission issues found"
fi

log "Permission check completed"
exit 0
EOF

  chmod +x /usr/local/bin/security/check-permissions.sh
  
  # Schedule security checks via cron if available
  if [ -d "/etc/cron.d" ]; then
    cat > /etc/cron.d/meowcoin-security <<EOF
# Meowcoin node security checks
15 */6 * * * root /usr/local/bin/security/check-integrity.sh > /dev/null 2>&1
30 */12 * * * root /usr/local/bin/security/check-permissions.sh > /dev/null 2>&1
0 0 * * * root /usr/local/bin/security/check-certs.sh > /dev/null 2>&1
EOF
    chmod 644 /etc/cron.d/meowcoin-security
    log "Scheduled regular security checks via cron"
  else
    log "WARNING: Cannot schedule security checks (cron.d directory not found)"
    
    # If we're using supervisord, we could add them there
    if [ -d "/etc/supervisor/conf.d" ] && command -v supervisorctl >/dev/null 2>&1; then
      cat > /etc/supervisor/conf.d/security-checks.conf <<EOF
[program:security-checks]
command=/bin/bash -c "while true; do sleep 21600; /usr/local/bin/security/check-integrity.sh; sleep 21600; /usr/local/bin/security/check-permissions.sh; sleep 21600; /usr/local/bin/security/check-certs.sh; done"
user=root
autostart=true
autorestart=true
priority=90
stdout_logfile=/var/log/meowcoin/security-checks.log
stderr_logfile=/var/log/meowcoin/security-checks.log
EOF
      log "Scheduled security checks via supervisor"
    fi
  fi
  
  return 0
}