#!/bin/bash

# Setup monitoring features
function setup_monitoring_features() {
  # Configure Prometheus exporter if enabled
  if [ "${ENABLE_METRICS:-false}" = "true" ]; then
    setup_prometheus_exporter
  fi
  
  # Configure advanced health checks
  setup_health_monitoring
}

# Setup Prometheus metrics exporter
function setup_prometheus_exporter() {
  echo "[$(date -Iseconds)] Setting up Prometheus metrics exporter" | tee -a $LOG_FILE
  
  # Set up ZMQ for blockchain notifications
  ZMQ_OPTS="zmqpubhashtx=tcp://127.0.0.1:28332 zmqpubhashblock=tcp://127.0.0.1:28332 zmqpubrawblock=tcp://127.0.0.1:28332 zmqpubrawtx=tcp://127.0.0.1:28332"
  if [ -z "$CUSTOM_OPTS" ]; then
    export CUSTOM_OPTS="$ZMQ_OPTS"
  else
    export CUSTOM_OPTS="$CUSTOM_OPTS $ZMQ_OPTS"
  fi
  
  # Create exporter configuration directory
  mkdir -p /etc/meowcoin-exporter
  
  # Create comprehensive config with all metrics enabled
  cat > /etc/meowcoin-exporter/config.json <<EOF
{
  "meowcoin": {
    "rpc": {
      "host": "127.0.0.1",
      "port": 8332,
      "user": "${RPC_USER}",
      "password": "${RPC_PASSWORD}"
    },
    "zmq": {
      "enabled": true,
      "address": "tcp://127.0.0.1:28332"
    }
  },
  "web": {
    "listen_address": ":9449",
    "telemetry_path": "/metrics",
    "enable_pprof": false
  },
  "features": {
    "transaction_stats": true,
    "block_stats": true,
    "mempool_stats": true,
    "network_stats": true,
    "peer_stats": true,
    "wallet_stats": ${ENABLE_WALLET_METRICS:-false}
  },
  "advanced": {
    "collect_interval": 15,
    "log_level": "info"
  }
}
EOF

  # Create exporter startup script with proper options
  cat > /usr/local/bin/start-exporter.sh <<EOF
#!/bin/bash
# Prometheus metrics exporter startup script
export PATH=\$PATH:/usr/local/bin

# Check for required binaries
if [ ! -f /usr/local/bin/meowcoin-exporter ]; then
  echo "[$(date -Iseconds)] ERROR: Prometheus exporter binary not found" >&2
  exit 1
fi

# Start with config file
if [ -f /etc/meowcoin-exporter/config.json ]; then
  echo "[$(date -Iseconds)] Starting Prometheus exporter with config file"
  exec /usr/local/bin/meowcoin-exporter \
    --config-file=/etc/meowcoin-exporter/config.json
else
  # Fallback to command-line arguments
  echo "[$(date -Iseconds)] Starting Prometheus exporter with command-line arguments"
  exec /usr/local/bin/meowcoin-exporter \
    --meowcoin.rpc-host=127.0.0.1 \
    --meowcoin.rpc-user="${RPC_USER}" \
    --meowcoin.rpc-password="${RPC_PASSWORD}" \
    --web.listen-address=:9449
fi
EOF

  chmod +x /usr/local/bin/start-exporter.sh
  echo "[$(date -Iseconds)] Prometheus exporter configuration complete" | tee -a $LOG_FILE
}

# Setup advanced health monitoring
function setup_health_monitoring() {
  echo "[$(date -Iseconds)] Setting up health monitoring" | tee -a $LOG_FILE
  
  # Create health check directories
  mkdir -p /etc/meowcoin/health
  
  # Configure health check thresholds with better defaults based on environment
  if [ $MEMORY_LIMIT_MB -lt 2048 ]; then
    # Low resource environment
    MAX_BLOCKS_BEHIND=10
    MIN_PEERS=2
    MAX_MEMPOOL_SIZE=100
  elif [ $MEMORY_LIMIT_MB -lt 8192 ]; then
    # Medium resource environment
    MAX_BLOCKS_BEHIND=6
    MIN_PEERS=4
    MAX_MEMPOOL_SIZE=300
  else
    # High resource environment
    MAX_BLOCKS_BEHIND=3
    MIN_PEERS=8
    MAX_MEMPOOL_SIZE=1000
  fi

  # Save thresholds to config file  
  cat > /etc/meowcoin/health/thresholds.conf <<EOF
# Health check thresholds
MAX_BLOCKS_BEHIND=$MAX_BLOCKS_BEHIND
MIN_PEERS=$MIN_PEERS
MAX_MEMPOOL_SIZE=$MAX_MEMPOOL_SIZE
# Additional parameters
HEALTH_CHECK_INTERVAL=300
ALERT_ON_SYNC_STALLED=true
CHECK_DISK_SPACE=true
MIN_FREE_SPACE_GB=5
EOF

  # Ensure health check script is executable
  if [ -f /usr/local/bin/monitoring/health-check.sh ]; then
    chmod +x /usr/local/bin/monitoring/health-check.sh
    echo "[$(date -Iseconds)] Health check script configured" | tee -a $LOG_FILE
  else
    echo "[$(date -Iseconds)] WARNING: Health check script not found" | tee -a $LOG_FILE
  fi
  
  # Setup status endpoint if enabled
  if [ "${ENABLE_STATUS_ENDPOINT:-false}" = "true" ]; then
    echo "[$(date -Iseconds)] Configuring status endpoint on port 9450" | tee -a $LOG_FILE
    mkdir -p /var/www/status
    # Create simple status page update script
    cat > /usr/local/bin/monitoring/update-status.sh <<EOF
#!/bin/bash
# Update status page based on health check results
STATUS_FILE="/tmp/meowcoin_health_status.json"
STATUS_HTML="/var/www/status/index.html"

if [ -f "\$STATUS_FILE" ]; then
  # Extract values from JSON
  BLOCKS=\$(jq -r '.blocks' "\$STATUS_FILE")
  HEADERS=\$(jq -r '.headers' "\$STATUS_FILE")
  BEHIND=\$(jq -r '.blocks_behind' "\$STATUS_FILE")
  PEERS=\$(jq -r '.connections' "\$STATUS_FILE")
  STATUS=\$(jq -r '.status' "\$STATUS_FILE")
  
  # Create HTML
  cat > "\$STATUS_HTML" <<HTML
<!DOCTYPE html>
<html>
<head>
  <title>Meowcoin Node Status</title>
  <meta http-equiv="refresh" content="60">
  <style>
    body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
    h1 { color: #333; }
    .status { padding: 15px; border-radius: 5px; margin: 10px 0; }
    .healthy { background-color: #d4edda; }
    .warning { background-color: #fff3cd; }
    .error { background-color: #f8d7da; }
    .info { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
    .label { font-weight: bold; }
  </style>
</head>
<body>
  <h1>Meowcoin Node Status</h1>
  <div class="status \${STATUS == 'healthy' ? 'healthy' : 'warning'}">
    <h2>Status: \$STATUS</h2>
  </div>
  <div class="info">
    <div><span class="label">Blocks:</span> \$BLOCKS</div>
    <div><span class="label">Headers:</span> \$HEADERS</div>
    <div><span class="label">Blocks Behind:</span> \$BEHIND</div>
    <div><span class="label">Peers:</span> \$PEERS</div>
    <div><span class="label">Last Update:</span> \$(date)</div>
  </div>
</body>
</html>
HTML
fi
EOF
    chmod +x /usr/local/bin/monitoring/update-status.sh
    
    # Set up cron to update status
    echo "* * * * * /usr/local/bin/monitoring/update-status.sh >/dev/null 2>&1" > /etc/cron.d/update-status
    chmod 644 /etc/cron.d/update-status
  fi
}