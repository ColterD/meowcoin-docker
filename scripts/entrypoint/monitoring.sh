# scripts/entrypoint/monitoring.sh
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
  
  # Create exporter configuration
  mkdir -p /etc/meowcoin-exporter
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
    "network_stats": true
  }
}
EOF

  # Create exporter startup script
  cat > /usr/local/bin/start-exporter.sh <<EOF
#!/bin/bash
/usr/local/bin/meowcoin-exporter \
  --meowcoin.rpc-user="${RPC_USER}" \
  --meowcoin.rpc-password="${RPC_PASSWORD}" \
  --web.listen-address=:9449
EOF

  chmod +x /usr/local/bin/start-exporter.sh
}

# Setup advanced health monitoring
function setup_health_monitoring() {
  echo "[$(date -Iseconds)] Setting up health monitoring" | tee -a $LOG_FILE
  
  # Create health check directories
  mkdir -p /etc/meowcoin/health
  
  # Configure health check thresholds
  cat > /etc/meowcoin/health/thresholds.conf <<EOF
MAX_BLOCKS_BEHIND=6
MIN_PEERS=3
MAX_MEMPOOL_SIZE=300
EOF

  # Ensure health check script is executable
  chmod +x /usr/local/bin/monitoring/health-check.sh
}