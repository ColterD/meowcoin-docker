#!/bin/bash

# Logging function
log() {
    local level="$1"
    local msg="$2"
    local timestamp=$(date -u '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg"
}

# Check if running as meowcoin user
if [ "$(id -u)" -ne 10000 ]; then
    log "ERROR" "Script must run as meowcoin user (UID 10000)"
    exit 1
fi

log "INFO" "Auto-configuring Meowcoin settings..."

# Detect system memory
TOTAL_MEMORY=$(free -m | awk '/^Mem:/{print $2}')
log "INFO" "Detected system memory: ${TOTAL_MEMORY}MB"

# Adjust dbcache based on memory (e.g., 25% of total memory, min 512MB, max 8192MB)
if [ "$SYSTEM_MEMORY" = "auto" ]; then
    DBCACHE=$((TOTAL_MEMORY / 4))
    if [ "$DBCACHE" -lt 512 ]; then DBCACHE=512; fi
    if [ "$DBCACHE" -gt 8192 ]; then DBCACHE=8192; fi
else
    DBCACHE="$SYSTEM_MEMORY"
fi

# Adjust maxconnections (e.g., 100 default, scale with memory if auto)
if [ "$MAX_CONNECTIONS" = "auto" ]; then
    MAX_CONN=$((TOTAL_MEMORY / 322))  # Rough scale: 1 connection per 322MB
    if [ "$MAX_CONN" -lt 50 ]; then MAX_CONN=50; fi
    if [ "$MAX_CONN" -gt 200 ]; then MAX_CONN=200; fi
else
    MAX_CONN="$MAX_CONNECTIONS"
fi

# Ensure .meowcoin directory exists and is writable
MEOWCOIN_DIR="/data/.meowcoin"
RPC_PASS_FILE="${RPC_PASSWORD_FILE:-/data/.meowcoin/rpc.pass}"
if [ ! -d "$MEOWCOIN_DIR" ]; then
    mkdir -p "$MEOWCOIN_DIR" || { log "ERROR" "Failed to create $MEOWCOIN_DIR"; exit 1; }
fi
if [ ! -w "$MEOWCOIN_DIR" ]; then
    log "ERROR" "$MEOWCOIN_DIR is not writable by meowcoin user"
    exit 1
fi

<<<<<<< HEAD
# Generate RPC password if not exists
if [ ! -f "$RPC_PASS_FILE" ]; then
    log "INFO" "Generating RPC password..."
    openssl rand -hex 32 > "$RPC_PASS_FILE" 2>/dev/null || {
        log "ERROR" "Failed to generate RPC password at $RPC_PASS_FILE"
        exit 1
    }
    chmod 600 "$RPC_PASS_FILE"
else
    log "INFO" "Using existing RPC password file: $RPC_PASS_FILE"
fi
=======
# Save RPC password to secure location
echo $RPC_PASS > "${MEOWCOIN_DATA}/.meowcoin/rpc.pass"
chmod 600 "${MEOWCOIN_DATA}/.meowcoin/rpc.pass"
>>>>>>> parent of 0706e65 (refactor)

# Update configuration file
CONFIG_FILE="/data/.meowcoin/meowcoin.conf"
cat << EOF > "$CONFIG_FILE"
# Auto-generated on $(date -u '+%Y-%m-%d %H:%M:%S UTC')
server=1
listen=1
txindex=${ENABLE_TXINDEX:-1}
upnp=0
dbcache=$DBCACHE
maxmempool=500
maxconnections=$MAX_CONN
maxreceivebuffer=5000
maxsendbuffer=1000
mempoolexpiry=72
min-relay-tx-fee=0.00001
limitfreerelay=5
rpcuser=meowcoin
rpcpasswordfile=$RPC_PASS_FILE
rpcallowip=127.0.0.1/32
rpcbind=127.0.0.1
rpcport=9766
logtimestamps=1
printtoconsole=0
logfile=/data/meowcoin.log
EOF

<<<<<<< HEAD
log "INFO" "Configuration written to $CONFIG_FILE"
log "INFO" "Auto-configuration complete."
=======
log_info "Configuration complete. Applied settings:"
log_info "- DB Cache: ${DB_CACHE}MB"
log_info "- Max Mempool: ${MAX_MEMPOOL}MB"
log_info "- Max Connections: ${CONNECTIONS}"

# Setup nginx for web interface
cat > /etc/nginx/http.d/default.conf << EOF
server {
    listen 8080 default_server;
    listen [::]:8080 default_server;
    
    root /var/www/html;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location /api {
        alias /var/www/html/api;
        add_header Cache-Control "no-store, no-cache, must-revalidate";
    }
}
EOF

log_info "Web server configured on port 8080"
>>>>>>> parent of 0706e65 (refactor)
