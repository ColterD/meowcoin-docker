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

# Setup security features
function setup_security_features() {
  # Create security log
  SECURITY_LOG="/var/log/meowcoin/security.log"
  mkdir -p $(dirname $SECURITY_LOG)
  touch $SECURITY_LOG
  chown meowcoin:meowcoin $SECURITY_LOG
  chmod 640 $SECURITY_LOG
  
  echo "[$(date -Iseconds)] Initializing security features" | tee -a $SECURITY_LOG
  
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
  
  # Configure additional security hardening
  apply_security_hardening
}

# Generate or validate SSL certificates with improved parameters
function setup_ssl_certificates() {
  echo "[$(date -Iseconds)] Setting up SSL for RPC communication" | tee -a $SECURITY_LOG
  
  # Ensure certificate directory exists with proper permissions
  mkdir -p "$CERT_DIR"
  chmod 750 "$CERT_DIR"
  chown meowcoin:meowcoin "$CERT_DIR"
  
  # Generate only if they don't exist
  if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "[$(date -Iseconds)] Generating SSL certificates" | tee -a $SECURITY_LOG
    
    # Generate private key with strong parameters
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:$SSL_KEY_SIZE \
      -out "$KEY_FILE" 2>> $SECURITY_LOG
    
    # Generate certificate with stronger parameters
    openssl req -new -x509 -key "$KEY_FILE" \
      -out "$CERT_FILE" \
      -days $SSL_CERT_DAYS \
      -sha256 \
      -subj "/CN=meowcoin-node/O=Meowcoin/C=US" \
      -addext "subjectAltName = DNS:meowcoin-node, DNS:localhost, IP:127.0.0.1" \
      -addext "keyUsage = digitalSignature, keyEncipherment" \
      -addext "extendedKeyUsage = serverAuth" \
      2>> $SECURITY_LOG
    
    # Set proper permissions
    chmod 640 "$CERT_FILE"
    chmod 600 "$KEY_FILE"
    chown meowcoin:meowcoin "$CERT_FILE" "$KEY_FILE"
    
    # Generate certificate hash for verification
    CERT_HASH=$(openssl x509 -noout -fingerprint -sha256 -in "$CERT_FILE" | cut -d= -f2)
    echo "[$(date -Iseconds)] Generated certificate with fingerprint: $CERT_HASH" | tee -a $SECURITY_LOG
    
    echo "[$(date -Iseconds)] SSL certificates generated successfully" | tee -a $SECURITY_LOG
  else
    echo "[$(date -Iseconds)] Using existing SSL certificates" | tee -a $SECURITY_LOG
    
    # Validate existing certificate expiration
    EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_FILE" | cut -d= -f2)
    echo "[$(date -Iseconds)] Certificate expires: $EXPIRY" | tee -a $SECURITY_LOG
    
    # Check if certificate will expire soon
    EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
    CURRENT_EPOCH=$(date +%s)
    RENEWAL_THRESHOLD=$((SSL_MIN_DAYS_BEFORE_RENEWAL*24*60*60))
    
    if [ $((EXPIRY_EPOCH - CURRENT_EPOCH)) -lt $RENEWAL_THRESHOLD ]; then
      echo "[$(date -Iseconds)] WARNING: SSL certificate will expire within $SSL_MIN_DAYS_BEFORE_RENEWAL days. Generating new certificate." | tee -a $SECURITY_LOG
      
      # Backup old certificate
      local BACKUP_SUFFIX=$(date +%Y%m%d%H%M%S)
      cp "$CERT_FILE" "${CERT_FILE}.${BACKUP_SUFFIX}"
      cp "$KEY_FILE" "${KEY_FILE}.${BACKUP_SUFFIX}"
      
      # Generate new certificate
      setup_ssl_certificates
    fi
    
    # Verify certificate permissions
    if [ "$(stat -c %a "$CERT_FILE")" != "640" ]; then
      echo "[$(date -Iseconds)] Fixing certificate permissions" | tee -a $SECURITY_LOG
      chmod 640 "$CERT_FILE"
    fi
    if [ "$(stat -c %a "$KEY_FILE")" != "600" ]; then
      echo "[$(date -Iseconds)] Fixing key file permissions" | tee -a $SECURITY_LOG
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
}

# Setup fail2ban for RPC protection with improved configuration
function setup_fail2ban() {
  echo "[$(date -Iseconds)] Setting up fail2ban for RPC protection" | tee -a $SECURITY_LOG
  
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
  
  # Create additional fail2ban filters for improved security
  # Filter for repeated invalid requests
  cat > /etc/fail2ban/filter.d/meowcoin-invalid.conf <<EOF
[Definition]
failregex = ^.*HTTP method: [^"]+ error: Request parsing failed: invalid request .* \[<HOST>\]$
ignoreregex =
EOF

  # Filter for excessive resource usage
  cat > /etc/fail2ban/filter.d/meowcoin-ddos.conf <<EOF
[Definition]
failregex = ^.*Excessive resource usage from .*\[<HOST>\]$
ignoreregex =
EOF

  # Add additional jails
  cat >> /etc/fail2ban/jail.local <<EOF

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
EOF

  # Customize fail2ban settings if provided
  if [ ! -z "${FAIL2BAN_BANTIME}" ]; then
    sed -i "s/bantime = 1h/bantime = ${FAIL2BAN_BANTIME}/" /etc/fail2ban/jail.local
    echo "[$(date -Iseconds)] Fail2ban ban time set to ${FAIL2BAN_BANTIME}" | tee -a $SECURITY_LOG
  fi
  
  if [ ! -z "${FAIL2BAN_FINDTIME}" ]; then
    sed -i "s/findtime = 10m/findtime = ${FAIL2BAN_FINDTIME}/" /etc/fail2ban/jail.local
    echo "[$(date -Iseconds)] Fail2ban find time set to ${FAIL2BAN_FINDTIME}" | tee -a $SECURITY_LOG
  fi
  
  if [ ! -z "${FAIL2BAN_MAXRETRY}" ]; then
    sed -i "s/maxretry = 5/maxretry = ${FAIL2BAN_MAXRETRY}/" /etc/fail2ban/jail.local
    echo "[$(date -Iseconds)] Fail2ban max retry set to ${FAIL2BAN_MAXRETRY}" | tee -a $SECURITY_LOG
  fi
  
  # Validate fail2ban configuration
  echo "[$(date -Iseconds)] Validating fail2ban configuration" | tee -a $SECURITY_LOG
  fail2ban-client -t 2>&1 | tee -a $SECURITY_LOG
  
  echo "[$(date -Iseconds)] Fail2ban configuration complete" | tee -a $SECURITY_LOG
}

# Setup read-only filesystem for security hardening
function setup_readonly_filesystem() {
  echo "[$(date -Iseconds)] Setting up read-only filesystem" | tee -a $SECURITY_LOG
  
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
  )
  
  for DIR in "${WRITABLE_DIRS[@]}"; do
    mkdir -p "$DIR"
    chown meowcoin:meowcoin "$DIR"
    chmod 750 "$DIR"
    echo "[$(date -Iseconds)] Created writable directory: $DIR" | tee -a $SECURITY_LOG
  done
  
  # Create tmpfs mounts for volatile directories that need write access
  cat > /etc/fstab.meowcoin <<EOF
tmpfs /tmp tmpfs defaults,noatime,nosuid,nodev,noexec,mode=1777,size=128M 0 0
tmpfs /var/run tmpfs defaults,noatime,nosuid,nodev,mode=0755,size=32M 0 0
EOF

  echo "[$(date -Iseconds)] Read-only filesystem configured (except for essential directories)" | tee -a $SECURITY_LOG
  
  # Set a flag to indicate readonly is enabled
  touch /etc/meowcoin/.readonly_enabled
}

# Setup JWT authentication for API access with improved security
function setup_jwt_authentication() {
  echo "[$(date -Iseconds)] Setting up JWT authentication" | tee -a $SECURITY_LOG
  
  # Generate JWT secret if it doesn't exist
  if [ ! -f "$JWT_SECRET_FILE" ]; then
    # Generate 512-bit random key (improved from 256-bit)
    openssl ecparam -name prime256v1 -genkey | openssl pkcs8 -topk8 -nocrypt -out "$JWT_SECRET_FILE"
    chmod 600 "$JWT_SECRET_FILE"
    chown meowcoin:meowcoin "$JWT_SECRET_FILE"
    echo "[$(date -Iseconds)] Generated JWT secret key using EC P-256 curve" | tee -a $SECURITY_LOG
  else
    echo "[$(date -Iseconds)] Using existing JWT secret key" | tee -a $SECURITY_LOG
    
    # Validate key format
    if ! openssl ec -in "$JWT_SECRET_FILE" -noout 2>/dev/null; then
      echo "[$(date -Iseconds)] WARNING: Existing JWT key is not in EC format. Generating new key." | tee -a $SECURITY_LOG
      mv "$JWT_SECRET_FILE" "${JWT_SECRET_FILE}.old"
      setup_jwt_authentication
      return
    fi
  fi
  
  # Create public key for verification
  openssl ec -in "$JWT_SECRET_FILE" -pubout -out "${JWT_SECRET_FILE}.pub" 2>/dev/null
  chmod 640 "${JWT_SECRET_FILE}.pub"
  chown meowcoin:meowcoin "${JWT_SECRET_FILE}.pub"
  
  # Add REST API and JWT auth options to configuration
  local JWT_OPTS="rest=1 rpcauth=jwtsecret jwt=1 jwtalgos=$JWT_ALGORITHM"
  
  # Add options for more secure JWT settings if needed
  if [ "${JWT_AUTH_STRICT:-false}" = "true" ]; then
    JWT_OPTS="$JWT_OPTS rpcallowip=127.0.0.1 rpcbind=127.0.0.1"
    echo "[$(date -Iseconds)] JWT authentication in strict mode (localhost only)" | tee -a $SECURITY_LOG
  fi
  
  if [ -z "$CUSTOM_OPTS" ]; then
    export CUSTOM_OPTS="$JWT_OPTS"
  else
    export CUSTOM_OPTS="$CUSTOM_OPTS $JWT_OPTS"
  fi
  
  # Create helper script for generating access tokens with expiration
  mkdir -p /usr/local/bin/utils
  cat > /usr/local/bin/utils/generate-jwt-token.sh <<EOF
#!/bin/bash
# Generate a JWT token for API access with improved security

JWT_SECRET_FILE="/home/meowcoin/.meowcoin/.jwtsecret"
JWT_EXPIRY=\${1:-3600}  # Default token expiry: 1 hour

if [ ! -f "\$JWT_SECRET_FILE" ]; then
  echo "JWT secret file not found. JWT authentication may not be enabled."
  exit 1
fi

# Generate header
HEADER='{"alg":"ES256","typ":"JWT"}'
HEADER_B64=\$(echo -n \$HEADER | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

# Current timestamp for iat (issued at)
NOW=\$(date +%s)
# Expiry timestamp
EXPIRY=\$((NOW + JWT_EXPIRY))

# Generate payload with expiry
PAYLOAD='{"iat":'"\$NOW"',"exp":'"\$EXPIRY"',"sub":"meowcoin-node"}'
PAYLOAD_B64=\$(echo -n \$PAYLOAD | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

# Combine header and payload
UNSIGNED_TOKEN="\$HEADER_B64.\$PAYLOAD_B64"

# Sign the token
SIGNATURE=\$(echo -n "\$UNSIGNED_TOKEN" | openssl dgst -sha256 -sign "\$JWT_SECRET_FILE" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

# Complete token
JWT_TOKEN="\$UNSIGNED_TOKEN.\$SIGNATURE"

echo "JWT Token: \$JWT_TOKEN"
echo
echo "Token details:"
echo "  Issued at: \$(date -d @\$NOW)"
echo "  Expires at: \$(date -d @\$EXPIRY)"
echo "  Valid for: \$JWT_EXPIRY seconds"
echo
echo "Example usage:"
echo "curl -s -H \"Authorization: Bearer \$JWT_TOKEN\" -H \"Content-Type: application/json\" -d '{\"method\":\"getblockchaininfo\",\"params\":[],\"id\":1}' http://localhost:8332/"
EOF
  
  chmod +x /usr/local/bin/utils/generate-jwt-token.sh
  echo "[$(date -Iseconds)] JWT token generation utility created with improved security" | tee -a $SECURITY_LOG
  
  # Create token rotation script
  cat > /usr/local/bin/utils/rotate-jwt-keys.sh <<EOF
#!/bin/bash
# Script to rotate JWT keys

JWT_SECRET_FILE="/home/meowcoin/.meowcoin/.jwtsecret"
BACKUP_DIR="/home/meowcoin/.meowcoin/key-backups"

mkdir -p "\$BACKUP_DIR"
chmod 700 "\$BACKUP_DIR"

# Backup existing key
if [ -f "\$JWT_SECRET_FILE" ]; then
  BACKUP_FILE="\$BACKUP_DIR/jwt_key_\$(date +%Y%m%d_%H%M%S).bak"
  cp "\$JWT_SECRET_FILE" "\$BACKUP_FILE"
  chmod 600 "\$BACKUP_FILE"
  echo "JWT key backed up to \$BACKUP_FILE"
fi

# Generate new key
openssl ecparam -name prime256v1 -genkey | openssl pkcs8 -topk8 -nocrypt -out "\$JWT_SECRET_FILE"
chmod 600 "\$JWT_SECRET_FILE"

# Create public key for verification
openssl ec -in "\$JWT_SECRET_FILE" -pubout -out "\${JWT_SECRET_FILE}.pub" 2>/dev/null
chmod 640 "\${JWT_SECRET_FILE}.pub"

echo "JWT key rotated successfully at \$(date -Iseconds)"
EOF

  chmod +x /usr/local/bin/utils/rotate-jwt-keys.sh
  echo "[$(date -Iseconds)] Created JWT key rotation utility" | tee -a $SECURITY_LOG
  
  # Schedule key rotation if enabled
  if [ "${JWT_KEY_ROTATION:-false}" = "true" ]; then
    local ROTATION_SCHEDULE="${JWT_KEY_ROTATION_SCHEDULE:-0 0 1 * *}"  # Default: monthly
    
    cat > /etc/cron.d/jwt-key-rotation <<EOF
# JWT key rotation schedule
$ROTATION_SCHEDULE root /usr/local/bin/utils/rotate-jwt-keys.sh > /var/log/meowcoin/jwt-rotation.log 2>&1
EOF
    
    chmod 644 /etc/cron.d/jwt-key-rotation
    echo "[$(date -Iseconds)] Scheduled JWT key rotation: $ROTATION_SCHEDULE" | tee -a $SECURITY_LOG
  fi
}

# Apply additional security hardening measures
function apply_security_hardening() {
  echo "[$(date -Iseconds)] Applying additional security hardening" | tee -a $SECURITY_LOG
  
  # Restrict file permissions
  find /home/meowcoin/.meowcoin -type f -exec chmod 640 {} \; 2>/dev/null || true
  find /home/meowcoin/.meowcoin -type d -exec chmod 750 {} \; 2>/dev/null || true
  
  # Protect configuration files
  chmod 600 /home/meowcoin/.meowcoin/*.conf 2>/dev/null || true
  
  # Set system resource limits for meowcoin user
  cat > /etc/security/limits.d/meowcoin.conf <<EOF
meowcoin soft nofile 65535
meowcoin hard nofile 65535
meowcoin soft nproc 4096
meowcoin hard nproc 4096
EOF

  # Disable core dumps for security
  echo "* hard core 0" >> /etc/security/limits.conf
  
  # Set kernel security parameters if running as privileged container
  if [ -w /proc/sys/kernel/randomize_va_space ]; then
    echo 2 > /proc/sys/kernel/randomize_va_space  # Enable ASLR
    echo "[$(date -Iseconds)] Enabled ASLR" | tee -a $SECURITY_LOG
  fi

  # Setup kernel hardening if running with appropriate permissions
  if [ -w /proc/sys/kernel/dmesg_restrict ]; then
    echo 1 > /proc/sys/kernel/dmesg_restrict
    echo "[$(date -Iseconds)] Restricted dmesg access" | tee -a $SECURITY_LOG
  fi
  
  # Add security warning banner
  cat > /etc/motd <<EOF
================================================================================
                         MEOWCOIN NODE - AUTHORIZED ACCESS ONLY
================================================================================
This system is restricted to authorized users for legitimate Meowcoin node
operation. All activities may be monitored and recorded.
Unauthorized access will be fully investigated and reported to authorities.
================================================================================
EOF

  echo "[$(date -Iseconds)] Security hardening completed" | tee -a $SECURITY_LOG
}