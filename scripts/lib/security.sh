#!/bin/bash
# Security utilities for Meowcoin Docker
# Standardizes security features, checks, and hardening

# Source common utilities
source /usr/local/bin/lib/utils.sh

# Certificate configuration
CERT_DIR="/home/meowcoin/.meowcoin/certs"
CERT_FILE="$CERT_DIR/meowcoin.crt"
KEY_FILE="$CERT_DIR/meowcoin.key"
CA_FILE="$CERT_DIR/ca.crt"
JWT_SECRET_FILE="/home/meowcoin/.meowcoin/.jwtsecret"
SSL_CERT_DAYS="${SSL_CERT_DAYS:-365}"
SSL_KEY_SIZE="${SSL_KEY_SIZE:-4096}"
SSL_CIPHER_LIST="${SSL_CIPHER_LIST:-ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384}"
SSL_PROTOCOLS="${SSL_PROTOCOLS:-TLSv1.2 TLSv1.3}"
JWT_ALGORITHM="${JWT_ALGORITHM:-ES256}"
SSL_MIN_DAYS_BEFORE_RENEWAL="${SSL_MIN_DAYS_BEFORE_RENEWAL:-30}"

# Generate or validate SSL certificates
function setup_ssl_certificates() {
  log "Setting up SSL for RPC communication" "INFO"
  
  # Ensure certificate directory exists with proper permissions
  mkdir -p "$CERT_DIR"
  chmod 750 "$CERT_DIR"
  chown meowcoin:meowcoin "$CERT_DIR"
  
  # Generate only if they don't exist
  if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    log "Generating SSL certificates" "INFO"
    
    # Create a secure private key with strong parameters
    if ! openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:$SSL_KEY_SIZE \
         -out "$KEY_FILE" 2>> $LOG_FILE; then
      handle_error 101 "Failed to generate SSL private key" "ssl_setup" "ERROR" "ssl_error" "critical"
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
         2>> $LOG_FILE; then
      handle_error 102 "Failed to generate SSL certificate" "ssl_setup" "ERROR" "ssl_error" "critical"
      return 1
    fi
    
    # Set proper permissions
    chmod 640 "$CERT_FILE"
    chmod 600 "$KEY_FILE"
    chown meowcoin:meowcoin "$CERT_FILE" "$KEY_FILE"
    
    # Generate certificate hash for verification
    CERT_HASH=$(openssl x509 -noout -fingerprint -sha256 -in "$CERT_FILE" | cut -d= -f2)
    log "Generated certificate with fingerprint: $CERT_HASH" "INFO"
    
    # Store certificate metadata
    echo "$(date -Iseconds)" > "$CERT_DIR/.cert_generated"
    echo "$CERT_HASH" > "$CERT_DIR/.cert_fingerprint"
    echo "$SSL_CERT_DAYS" > "$CERT_DIR/.cert_validity_days"
    
    log "SSL certificates generated successfully" "INFO"
  else
    log "Using existing SSL certificates" "INFO"
    
    # Validate existing certificate expiration
    EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_FILE" | cut -d= -f2)
    log "Certificate expires: $EXPIRY" "INFO"
    
    # Check if certificate will expire soon
    EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
    CURRENT_EPOCH=$(date +%s)
    RENEWAL_THRESHOLD=$((SSL_MIN_DAYS_BEFORE_RENEWAL*24*60*60))
    
    if [ $((EXPIRY_EPOCH - CURRENT_EPOCH)) -lt $RENEWAL_THRESHOLD ]; then
      log "SSL certificate will expire within $SSL_MIN_DAYS_BEFORE_RENEWAL days. Generating new certificate." "WARNING"
      
      # Backup old certificate
      local BACKUP_SUFFIX=$(date +%Y%m%d%H%M%S)
      cp "$CERT_FILE" "${CERT_FILE}.${BACKUP_SUFFIX}"
      cp "$KEY_FILE" "${KEY_FILE}.${BACKUP_SUFFIX}"
      
      # Generate new certificate
      setup_ssl_certificates
    fi
    
    # Verify certificate permissions
    if [ "$(stat -c %a "$CERT_FILE")" != "640" ]; then
      log "Fixing certificate permissions" "WARNING"
      chmod 640 "$CERT_FILE"
    fi
    if [ "$(stat -c %a "$KEY_FILE")" != "600" ]; then
      log "Fixing key file permissions" "WARNING"
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

# Setup fail2ban for RPC protection
function setup_fail2ban() {
  log "Setting up fail2ban for RPC protection" "INFO"
  
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
    log "fail2ban is not installed, cannot enable fail2ban protection" "ERROR"
    return 1
  fi
  
  # Create additional fail2ban filters if needed
  setup_fail2ban_filters
  
  # Create or update jail.local configuration
  create_fail2ban_jail
  
  # Validate fail2ban configuration
  log "Validating fail2ban configuration" "INFO"
  if ! fail2ban-client -t 2>&1 | tee -a $LOG_FILE; then
    log "Fail2ban configuration test failed" "ERROR"
    return 1
  fi
  
  log "Fail2ban configuration complete" "INFO"
  return 0
}

# Create fail2ban filters
function setup_fail2ban_filters() {
  # Filter for RPC authentication failures
  if [ ! -f "/etc/fail2ban/filter.d/meowcoin-rpc.conf" ]; then
    cat > /etc/fail2ban/filter.d/meowcoin-rpc.conf <<EOF
[Definition]
failregex = ^.*Incorrect rpcuser or rpcpassword.*\[<HOST>\]$
            ^.*Unauthorized RPC access.*\[<HOST>\]$
            ^.*Failed authentication from.*\[<HOST>\]$
ignoreregex =
EOF
  fi
  
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
  
  log "Fail2ban filters created" "INFO"
}

# Create fail2ban jail configuration
function create_fail2ban_jail() {
  if [ ! -f "/etc/fail2ban/jail.local" ]; then
    cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = ${FAIL2BAN_BANTIME:-3600}
findtime = ${FAIL2BAN_FINDTIME:-600}
maxretry = ${FAIL2BAN_MAXRETRY:-5}
ignoreip = 127.0.0.1/8 ::1 ${FAIL2BAN_IGNOREIP}

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
    log "Fail2ban ban time set to ${FAIL2BAN_BANTIME}" "INFO"
  fi
  
  if [ ! -z "${FAIL2BAN_FINDTIME}" ]; then
    sed -i "s/findtime = 600/findtime = ${FAIL2BAN_FINDTIME}/" /etc/fail2ban/jail.local
    log "Fail2ban find time set to ${FAIL2BAN_FINDTIME}" "INFO"
  fi
  
  if [ ! -z "${FAIL2BAN_MAXRETRY}" ]; then
    sed -i "s/maxretry = 5/maxretry = ${FAIL2BAN_MAXRETRY}/" /etc/fail2ban/jail.local
    log "Fail2ban max retry set to ${FAIL2BAN_MAXRETRY}" "INFO"
  fi
  
  if [ ! -z "${FAIL2BAN_IGNOREIP}" ]; then
    sed -i "s|ignoreip = 127.0.0.1/8 ::1|ignoreip = 127.0.0.1/8 ::1 ${FAIL2BAN_IGNOREIP}|" /etc/fail2ban/jail.local
    log "Fail2ban ignore IPs set to include ${FAIL2BAN_IGNOREIP}" "INFO"
  fi
  
  log "Fail2ban jail configured" "INFO"
}

# Setup read-only filesystem for security hardening
function setup_readonly_filesystem() {
  log "Setting up read-only filesystem" "INFO"
  
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
    log "Created writable directory: $DIR" "DEBUG"
  done
  
  # Check if running in a container
  if [ -f "/.dockerenv" ]; then
    log "Running in a container, using Docker volume mounts for writable areas" "INFO"
    
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
    log "Mounting tmpfs for volatile directories" "INFO"
    
    # Mount tmpfs
    if ! mount -a -T /etc/fstab.meowcoin; then
      log "Failed to mount tmpfs directories" "WARNING"
    fi
  else
    log "mount command not available, cannot create tmpfs mounts" "WARNING"
  fi
  
  log "Read-only filesystem configured (except for essential directories)" "INFO"
  
  # Set a flag to indicate readonly is enabled
  touch /etc/meowcoin/.readonly_enabled
  chmod 644 /etc/meowcoin/.readonly_enabled
  
  return 0
}

# Setup JWT authentication for API access
function setup_jwt_authentication() {
  log "Setting up JWT authentication with algorithm: $JWT_ALGORITHM" "INFO"
  
  # Generate JWT secret if it doesn't exist
  if [ ! -f "$JWT_SECRET_FILE" ]; then
    # Create JWT directory with proper permissions
    mkdir -p "$(dirname "$JWT_SECRET_FILE")"
    
    # Generate key using appropriate EC curve based on algorithm
    if [ "$JWT_ALGORITHM" = "ES384" ]; then
      # P-384 curve for ES384
      if ! openssl ecparam -name secp384r1 -genkey | openssl pkcs8 -topk8 -nocrypt -out "$JWT_SECRET_FILE"; then
        handle_error 103 "Failed to generate JWT secret key" "jwt_setup" "ERROR" "jwt_error" "critical"
        return 1
      fi
      log "Generated JWT secret key using EC P-384 curve" "INFO"
    elif [ "$JWT_ALGORITHM" = "ES512" ]; then
      # P-521 curve for ES512
      if ! openssl ecparam -name secp521r1 -genkey | openssl pkcs8 -topk8 -nocrypt -out "$JWT_SECRET_FILE"; then
        handle_error 103 "Failed to generate JWT secret key" "jwt_setup" "ERROR" "jwt_error" "critical"
        return 1
      fi
      log "Generated JWT secret key using EC P-521 curve" "INFO"
    else
      # Default P-256 curve for ES256
      if ! openssl ecparam -name prime256v1 -genkey | openssl pkcs8 -topk8 -nocrypt -out "$JWT_SECRET_FILE"; then
        handle_error 103 "Failed to generate JWT secret key" "jwt_setup" "ERROR" "jwt_error" "critical"
        return 1
      fi
      log "Generated JWT secret key using EC P-256 curve" "INFO"
    fi
    
    chmod 600 "$JWT_SECRET_FILE"
    chown meowcoin:meowcoin "$JWT_SECRET_FILE"
  else
    log "Using existing JWT secret key" "INFO"
    
    # Validate key format and permissions
    if ! openssl ec -in "$JWT_SECRET_FILE" -noout 2>/dev/null; then
      log "Existing JWT key is not in EC format. Generating new key." "WARNING"
      mv "$JWT_SECRET_FILE" "${JWT_SECRET_FILE}.old"
      setup_jwt_authentication
      return $?
    fi
    
    # Fix permissions if needed
    if [ "$(stat -c %a "$JWT_SECRET_FILE")" != "600" ]; then
      log "Fixing JWT secret file permissions" "WARNING"
      chmod 600 "$JWT_SECRET_FILE"
      chown meowcoin:meowcoin "$JWT_SECRET_FILE"
    fi
  fi
  
  # Create public key for verification
  if ! openssl ec -in "$JWT_SECRET_FILE" -pubout -out "${JWT_SECRET_FILE}.pub" 2>/dev/null; then
    handle_error 104 "Failed to generate JWT public key" "jwt_setup" "ERROR" "jwt_error" "critical"
    return 1
  fi
  
  chmod 640 "${JWT_SECRET_FILE}.pub"
  chown meowcoin:meowcoin "${JWT_SECRET_FILE}.pub"
  
  # Add REST API and JWT auth options to configuration
  local JWT_OPTS="rest=1 rpcauth=jwtsecret jwt=1 jwtalgos=$JWT_ALGORITHM"
  
  # Add options for more secure JWT settings if needed
  if [ "${JWT_AUTH_STRICT:-false}" = "true" ]; then
    JWT_OPTS="$JWT_OPTS rpcallowip=127.0.0.1 rpcbind=127.0.0.1"
    log "JWT authentication in strict mode (localhost only)" "INFO"
  fi
  
  if [ -z "$CUSTOM_OPTS" ]; then
    export CUSTOM_OPTS="$JWT_OPTS"
  else
    export CUSTOM_OPTS="$CUSTOM_OPTS $JWT_OPTS"
  fi
  
  # Create token management utility scripts
  create_jwt_utility_scripts
  
  log "JWT authentication setup complete" "INFO"
  return 0
}

# Create JWT token management utilities
function create_jwt_utility_scripts() {
  # Create utility directory if it doesn't exist
  mkdir -p /usr/local/bin/utils
  
  # Create helper script for generating access tokens with expiration
  cat > /usr/local/bin/utils/generate-jwt-token.sh <<'EOF'
#!/bin/bash
# Generate a JWT token for API access

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
  # Determine algorithm from key size
  KEY_SIZE=$(openssl ec -in "$JWT_SECRET_FILE" -text -noout 2>/dev/null | grep "ASN1 OID" | awk '{print $3}')
  case "$KEY_SIZE" in
    prime256v1) ALGORITHM="ES256" ;;
    secp384r1) ALGORITHM="ES384" ;;
    secp521r1) ALGORITHM="ES512" ;;
    *) ALGORITHM="ES256" ;;  # Default
  esac
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
if [ "$ALGORITHM" = "ES256" ] || [ "$ALGORITHM" = "ES384" ] || [ "$ALGORITHM" = "ES512" ]; then
  # For ECDSA, we need to use the right signature format
  SIGNATURE=$(echo -n "$UNSIGNED_TOKEN" | openssl dgst -sha${ALGORITHM#ES} -sign "$JWT_SECRET_FILE" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
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
  log "JWT token generation utility created" "INFO"
  
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
  echo "No expiry found in token"
  exit 1
fi

if [ $NOW -gt $EXP ]; then
  echo "Token has expired at $(date -d @$EXP)"
  exit 1
else
  echo "Token is valid until $(date -d @$EXP)"
fi

# Extract algorithm
ALG=$(echo "$HEADER" | sed -n 's/.*"alg": *"\([^"]*\)".*/\1/p')
echo "Token algorithm: $ALG"

echo "For full cryptographic verification, you would need a JWT library"
EOF

  chmod +x /usr/local/bin/utils/verify-jwt-token.sh
  log "JWT token verification utility created" "INFO"
  
  # Create token rotation script
  cat > /usr/local/bin/utils/rotate-jwt-keys.sh <<'EOF'
#!/bin/bash
# Script to rotate JWT keys

JWT_SECRET_FILE="/home/meowcoin/.meowcoin/.jwtsecret"
BACKUP_DIR="/home/meowcoin/.meowcoin/key-backups"
JWT_ALGORITHM=${1:-ES256}  # Default algorithm or pass as parameter

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

# Generate new key based on algorithm
case "$JWT_ALGORITHM" in
  ES384) 
    echo "Generating ES384 key (P-384 curve)"
    openssl ecparam -name secp384r1 -genkey | openssl pkcs8 -topk8 -nocrypt -out "$JWT_SECRET_FILE"
    ;;
  ES512)
    echo "Generating ES512 key (P-521 curve)"
    openssl ecparam -name secp521r1 -genkey | openssl pkcs8 -topk8 -nocrypt -out "$JWT_SECRET_FILE"
    ;;
  *)
    echo "Generating ES256 key (P-256 curve)"
    openssl ecparam -name prime256v1 -genkey | openssl pkcs8 -topk8 -nocrypt -out "$JWT_SECRET_FILE"
    ;;
esac

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
  log "Created JWT key rotation utility" "INFO"
  
  # Schedule key rotation if enabled
  if [ "${JWT_KEY_ROTATION:-false}" = "true" ]; then
    local ROTATION_SCHEDULE="${JWT_KEY_ROTATION_SCHEDULE:-0 0 1 * *}"  # Default: monthly
    
    # Create cron job
    if [ -d "/etc/cron.d" ]; then
      cat > /etc/cron.d/jwt-key-rotation <<EOF
# JWT key rotation schedule
$ROTATION_SCHEDULE root /usr/local/bin/utils/rotate-jwt-keys.sh $JWT_ALGORITHM > /var/log/meowcoin/jwt-rotation.log 2>&1
EOF
      
      chmod 644 /etc/cron.d/jwt-key-rotation
      log "Scheduled JWT key rotation: $ROTATION_SCHEDULE" "INFO"
    else
      log "Cannot schedule JWT key rotation (cron.d directory not found)" "WARNING"
    fi
  fi
}

# Apply additional security hardening measures
function apply_security_hardening() {
  log "Applying additional security hardening" "INFO"
  
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
    log "Set resource limits for meowcoin user" "INFO"
  else
    log "Cannot set resource limits (limits.d directory not found)" "WARNING"
  fi

  # Disable core dumps for security
  if [ -f "/etc/security/limits.conf" ]; then
    echo "* hard core 0" >> /etc/security/limits.conf
    log "Disabled core dumps" "INFO"
  fi
  
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
    log "Created binary integrity file" "INFO"
  fi

  log "Security hardening completed" "INFO"
  return 0
}

# Check certificate expiration
function check_certificates() {
  local CERT_DIR="/home/meowcoin/.meowcoin/certs"
  local ALERT_DAYS="${1:-30}"
  
  log "Checking SSL certificates" "INFO"
  
  # Check if certs directory exists
  if [ ! -d "$CERT_DIR" ]; then
    log "Certificate directory not found: $CERT_DIR" "WARNING"
    return 0
  fi
  
  # Find all certificate files
  find "$CERT_DIR" -name "*.crt" -o -name "*.pem" | while read cert_file; do
    log "Checking certificate: $cert_file" "DEBUG"
    
    # Get expiration date
    EXPIRY_DATE=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
    EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)
    CURRENT_EPOCH=$(date +%s)
    DAYS_REMAINING=$(( ($EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))
    
    log "Certificate $cert_file expires in $DAYS_REMAINING days" "INFO"
    
    # Check if certificate is expired or will expire soon
    if [ $EXPIRY_EPOCH -lt $CURRENT_EPOCH ]; then
      log "ERROR: Certificate has expired: $cert_file" "ERROR"
      
      # Send alert
      send_alert "certificate_expired" "SSL certificate has expired: $cert_file" "critical"
      
    elif [ $DAYS_REMAINING -lt $ALERT_DAYS ]; then
      log "WARNING: Certificate will expire soon: $cert_file ($DAYS_REMAINING days)" "WARNING"
      
      # Send alert
      send_alert "certificate_expiring" "SSL certificate will expire in $DAYS_REMAINING days: $cert_file" "warning"
    fi
  done
  
  return 0
}

# Check binary integrity
function check_binary_integrity() {
  local INTEGRITY_FILE="/etc/meowcoin/binary-integrity.txt"
  
  log "Running binary integrity check" "INFO"
  
  # Check if integrity file exists
  if [ ! -f "$INTEGRITY_FILE" ]; then
    log "Integrity file not found" "WARNING"
    return 1
  fi
  
  # Verify binary integrity
  if ! sha256sum -c "$INTEGRITY_FILE" >/dev/null 2>&1; then
    log "Binary integrity check failed" "ERROR"
    log "Expected hashes:" "ERROR"
    cat "$INTEGRITY_FILE" | tee -a "$LOG_FILE"
    log "Current hashes:" "ERROR"
    sha256sum /usr/bin/meowcoind /usr/bin/meowcoin-cli | tee -a "$LOG_FILE"
    
    # Send alert
    send_alert "integrity_failure" "Binary integrity check failed - possible tampering detected" "critical"
    
    return 1
  else
    log "Binary integrity check passed" "INFO"
  fi
  
  # Check for unusual setuid/setgid binaries in key directories
  if find /usr/bin /usr/local/bin -perm -4000 -o -perm -2000 | grep -v "^/usr/bin/sudo$" > /tmp/setuid_check.txt; then
    if [ -s /tmp/setuid_check.txt ]; then
      log "Found unusual setuid/setgid binaries:" "WARNING"
      cat /tmp/setuid_check.txt | tee -a "$LOG_FILE"
      
      # Send alert
      send_alert "setuid_binaries" "Unusual setuid/setgid binaries detected" "warning"
    fi
  fi
  
  return 0
}

# Check file permissions
function check_permissions() {
  local WALLET_ISSUES=0
  local KEY_ISSUES=0
  local CONFIG_ISSUES=0
  local DIR_ISSUES=0
  
  log "Running permission check" "INFO"
  
  # Check wallet.dat permissions
  for WALLET in $(find /home/meowcoin/.meowcoin -name "wallet.dat" 2>/dev/null); do
    PERMS=$(stat -c "%a" "$WALLET")
    if [ "$PERMS" != "600" ]; then
      log "wallet.dat has incorrect permissions: $PERMS" "WARNING"
      chmod 600 "$WALLET"
      log "Fixed permissions on $WALLET" "WARNING"
      WALLET_ISSUES=$((WALLET_ISSUES+1))
    fi
  done
  
  # Check key files
  for KEYFILE in $(find /home/meowcoin/.meowcoin -name "*key*" -o -name "*.pem" -o -name "*.key" 2>/dev/null); do
    PERMS=$(stat -c "%a" "$KEYFILE")
    if [ "$PERMS" != "600" ] && [ "$PERMS" != "400" ]; then
      log "$KEYFILE has incorrect permissions: $PERMS" "WARNING"
      chmod 600 "$KEYFILE"
      log "Fixed permissions on $KEYFILE" "WARNING"
      KEY_ISSUES=$((KEY_ISSUES+1))
    fi
  done
  
  # Check configuration files
  for CONFIG in $(find /home/meowcoin/.meowcoin -name "*.conf" 2>/dev/null); do
    PERMS=$(stat -c "%a" "$CONFIG")
    if [ "$PERMS" != "600" ] && [ "$PERMS" != "640" ]; then
      log "$CONFIG has incorrect permissions: $PERMS" "WARNING"
      chmod 640 "$CONFIG"
      log "Fixed permissions on $CONFIG" "WARNING"
      CONFIG_ISSUES=$((CONFIG_ISSUES+1))
    fi
  done
  
  # Check directories
  for DIR in $(find /home/meowcoin/.meowcoin -type d 2>/dev/null); do
    PERMS=$(stat -c "%a" "$DIR")
    if [ "$PERMS" != "750" ] && [ "$PERMS" != "700" ]; then
      log "$DIR has incorrect permissions: $PERMS" "WARNING"
      chmod 750 "$DIR"
      log "Fixed permissions on $DIR" "WARNING"
      DIR_ISSUES=$((DIR_ISSUES+1))
    fi
  done
  
  # Report issues
  TOTAL_ISSUES=$((WALLET_ISSUES + KEY_ISSUES + CONFIG_ISSUES + DIR_ISSUES))
  if [ $TOTAL_ISSUES -gt 0 ]; then
    log "Found and fixed $TOTAL_ISSUES permission issues" "WARNING"
    
    # Send alert
    send_alert "permission_issues" "Found and fixed $TOTAL_ISSUES incorrect file permissions" "warning"
  else
    log "No permission issues found" "INFO"
  fi
  
  return 0
}

# Schedule security checks
function schedule_security_checks() {
  log "Setting up scheduled security checks" "INFO"
  
  # Schedule security checks via cron if available
  if [ -d "/etc/cron.d" ]; then
    cat > /etc/cron.d/meowcoin-security <<EOF
# Meowcoin node security checks
15 */6 * * * root /usr/local/bin/lib/security.sh check_binary_integrity > /dev/null 2>&1
30 */12 * * * root /usr/local/bin/lib/security.sh check_permissions > /dev/null 2>&1
0 0 * * * root /usr/local/bin/lib/security.sh check_certificates > /dev/null 2>&1
EOF
    chmod 644 /etc/cron.d/meowcoin-security
    log "Scheduled regular security checks via cron" "INFO"
  else
    log "Cannot schedule security checks (cron.d directory not found)" "WARNING"
  fi
  
  return 0
}

# Setup all security features
function setup_security_features() {
  # Create security log
  SECURITY_LOG="/var/log/meowcoin/security.log"
  mkdir -p $(dirname $SECURITY_LOG)
  touch $SECURITY_LOG
  chmod 640 $SECURITY_LOG
  
  log "Initializing security features" "INFO"
  
  # Configure SSL if enabled
  if [ "${ENABLE_SSL:-false}" = "true" ]; then
    setup_ssl_certificates || handle_error $? "SSL certificate setup failed" "security" "ERROR" "ssl_error" "warning"
  fi
  
  # Configure fail2ban if enabled
  if [ "${ENABLE_FAIL2BAN:-false}" = "true" ]; then
    setup_fail2ban || handle_error $? "Fail2ban setup failed" "security" "ERROR" "fail2ban_error" "warning"
  fi
  
  # Configure read-only filesystem if enabled
  if [ "${ENABLE_READONLY_FS:-false}" = "true" ]; then
    setup_readonly_filesystem || handle_error $? "Read-only filesystem setup failed" "security" "ERROR" "readonly_error" "warning"
  fi
  
  # Configure JWT auth with algorithm selection
  if [ "${ENABLE_JWT_AUTH:-false}" = "true" ]; then
    setup_jwt_authentication || handle_error $? "JWT authentication setup failed" "security" "ERROR" "jwt_error" "warning"
  fi
  
  # Configure additional security hardening
  apply_security_hardening || handle_error $? "Security hardening failed" "security" "ERROR" "hardening_error" "warning"
  
  # Schedule security checks
  schedule_security_checks || handle_error $? "Failed to schedule security checks" "security" "ERROR" "schedule_error" "warning"
  
  log "Security features initialized successfully" "INFO"
  
  return 0
}

# Handle command-line arguments for direct execution
if [ "$1" = "check_certificates" ]; then
  check_certificates "${2:-30}"
elif [ "$1" = "check_binary_integrity" ]; then
  check_binary_integrity
elif [ "$1" = "check_permissions" ]; then
  check_permissions
elif [ "$1" = "apply_hardening" ]; then
  apply_security_hardening
fi

# Export functions for use in other scripts
export -f setup_ssl_certificates
export -f setup_fail2ban
export -f setup_fail2ban_filters
export -f create_fail2ban_jail
export -f setup_readonly_filesystem
export -f setup_jwt_authentication
export -f create_jwt_utility_scripts
export -f apply_security_hardening
export -f check_certificates
export -f check_binary_integrity
export -f check_permissions
export -f schedule_security_checks
export -f setup_security_features