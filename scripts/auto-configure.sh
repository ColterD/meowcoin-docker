#!/bin/bash
# Auto-configure Meowcoin settings based on system resources
set -e

# Source helper functions - with error handling
if [ -f "/scripts/functions.sh" ]; then
  source /scripts/functions.sh
else
  echo "ERROR: functions.sh not found, creating minimal functions"
  log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"; }
  log_warning() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1" >&2; }
  log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2; }
fi

log_info "Auto-configuring Meowcoin settings..."

# Detect system memory
if [ "$SYSTEM_MEMORY" = "auto" ]; then
  TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
  log_info "Detected system memory: ${TOTAL_MEM}MB"
  
  # Configure dbcache based on available memory (25% of total memory up to 1GB)
  DB_CACHE=$(( TOTAL_MEM / 4 ))
  if [ $DB_CACHE -gt 1024 ]; then
    DB_CACHE=1024
  fi
  
  # Configure maxmempool based on available memory (15% of total memory up to 500MB)
  MAX_MEMPOOL=$(( TOTAL_MEM / 7 ))
  if [ $MAX_MEMPOOL -gt 500 ]; then
    MAX_MEMPOOL=500
  fi
else
  # Manual configuration
  TOTAL_MEM=$SYSTEM_MEMORY
  DB_CACHE=$(( TOTAL_MEM / 4 ))
  MAX_MEMPOOL=$(( TOTAL_MEM / 7 ))
fi

# Determine optimal connection count based on available memory
if [ "$MAX_CONNECTIONS" = "auto" ]; then
  if [ $TOTAL_MEM -lt 1024 ]; then
    # Less than 1GB RAM
    CONNECTIONS=15
  elif [ $TOTAL_MEM -lt 4096 ]; then
    # Less than 4GB RAM
    CONNECTIONS=30
  else
    # 4GB+ RAM
    CONNECTIONS=50
  fi
else
  CONNECTIONS=$MAX_CONNECTIONS
fi

# Generate random RPC credentials
RPC_USER="meowcoin"
RPC_PASS=$(openssl rand -hex 32)

# Save RPC password to secure location
mkdir -p "${MEOWCOIN_DATA}/.meowcoin"
echo $RPC_PASS > "${MEOWCOIN_DATA}/.meowcoin/rpc.pass"
chmod 600 "${MEOWCOIN_DATA}/.meowcoin/rpc.pass"

# Generate optimized configuration
log_info "Creating optimized meowcoin.conf"
cat > "${MEOWCOIN_CONFIG}/meowcoin.conf" << EOF
# Meowcoin Configuration
# Auto-generated on $(date)

# Network settings
server=1
listen=1
txindex=${ENABLE_TXINDEX}

# Performance settings
dbcache=${DB_CACHE}
maxmempool=${MAX_MEMPOOL}
maxconnections=${CONNECTIONS}

# RPC settings
rpcuser=${RPC_USER}
rpcpassword=${RPC_PASS}
rpcallowip=127.0.0.1/32
rpcbind=127.0.0.1
rpcport=9766

# For internal container access
rpcallowip=172.16.0.0/12
rpcallowip=192.168.0.0/16
rpcallowip=10.0.0.0/8

# Logging settings
logtimestamps=1
printtoconsole=1

# Apply any custom options from environment
${MEOWCOIN_OPTIONS}
EOF

log_info "Configuration complete. Applied settings:"
log_info "- DB Cache: ${DB_CACHE}MB"
log_info "- Max Mempool: ${MAX_MEMPOOL}MB"
log_info "- Max Connections: ${CONNECTIONS}"

# Setup nginx for web interface
log_info "Setting up nginx web server"

# Clean up any existing nginx configurations to avoid conflicts
if [ -d "/etc/nginx/sites-enabled" ]; then
  rm -f /etc/nginx/sites-enabled/*
fi

# Determine the correct path for nginx configuration
if [ -d "/etc/nginx/conf.d" ]; then
    NGINX_CONF_PATH="/etc/nginx/conf.d/default.conf"
    # Remove any existing default config
    rm -f "$NGINX_CONF_PATH"
elif [ -d "/etc/nginx/sites-available" ]; then
    NGINX_CONF_PATH="/etc/nginx/sites-available/default"
    NGINX_ENABLED_PATH="/etc/nginx/sites-enabled/default"
    # Remove any existing default config
    rm -f "$NGINX_CONF_PATH"
    rm -f "$NGINX_ENABLED_PATH"
elif [ -d "/etc/nginx/http.d" ]; then
    NGINX_CONF_PATH="/etc/nginx/http.d/default.conf"
    # Remove any existing default config
    rm -f "$NGINX_CONF_PATH"
else
    mkdir -p /etc/nginx/conf.d
    NGINX_CONF_PATH="/etc/nginx/conf.d/default.conf"
fi

# Write a very simple nginx configuration that should work
log_info "Writing nginx configuration to ${NGINX_CONF_PATH}"
cat > "${NGINX_CONF_PATH}" << 'EOFnginx'
server {
    listen 8080;
    server_name _;
    
    root /var/www/html;
    index index.html;
    
    # Main site
    location / {
        try_files $uri $uri/ =404;
    }
    
    # API endpoint
    location /api/ {
        proxy_pass http://localhost:8080/var/www/html/api/;
        add_header Cache-Control "no-store, no-cache, must-revalidate";
    }
}
EOFnginx

# Create symlink if using sites-enabled
if [ ! -z "${NGINX_ENABLED_PATH}" ] && [ ! -f "${NGINX_ENABLED_PATH}" ]; then
    ln -sf "${NGINX_CONF_PATH}" "${NGINX_ENABLED_PATH}"
fi

# Ensure correct ownership and permissions
chown -R meowcoin:meowcoin /var/www/html
chmod -R 755 /var/www/html

log_info "Web server configured on port 8080"

# Test nginx configuration
nginx -t || log_error "Nginx configuration test failed"