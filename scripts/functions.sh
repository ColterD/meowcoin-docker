#!/bin/bash

# Function to log messages with timestamp
log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log_warning() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1" >&2
}

log_error() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

# Function to get Meowcoin version
get_version() {
  if [ -f "/usr/local/bin/meowcoind" ]; then
    if [ -x "/usr/local/bin/meowcoind" ]; then
      /usr/local/bin/meowcoind --version 2>/dev/null | head -n 1 | awk '{print $NF}' || echo "Error getting version"
    else
      echo "Binary not executable"
      chmod +x /usr/local/bin/meowcoind 2>/dev/null || echo "Failed to set executable permission"
    fi
  else
    echo "Binary not found"
    find / -name "meowcoind" -type f 2>/dev/null | head -n 5 || echo "No meowcoind binary found on system"
  fi
}

# Function to display banner
display_banner() {
  echo ""
  echo "============================================"
  echo "$1"
  echo "============================================"
  echo ""
}

# Function to handle graceful shutdown
handle_shutdown() {
  log_info "Received shutdown signal, stopping services gracefully..."
  
  # Create shutdown flag
  touch "${MEOWCOIN_DATA}/.meowcoin/shutdown.flag"
  
  # Stop the daemon gracefully
  log_info "Stopping Meowcoin daemon..."
  if pgrep -x "meowcoind" > /dev/null; then
    gosu meowcoin /usr/local/bin/meowcoin-cli -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" stop || {
      log_warning "Failed to stop daemon gracefully, attempting to kill process"
      pkill -15 meowcoind
    }
  else
    log_warning "Meowcoin daemon not running, nothing to stop"
  fi
  
  # Wait for the daemon to stop
  local count=0
  while pgrep -x "meowcoind" > /dev/null; do
    sleep 1
    count=$((count + 1))
    if [ $count -ge 30 ]; then
      log_warning "Forcing Meowcoin daemon shutdown after 30 seconds timeout"
      pkill -9 meowcoind
      break
    fi
  done
  
  # Stop nginx
  log_info "Stopping web server..."
  nginx -s quit || pkill -15 nginx
  
  # Exit
  log_info "Shutdown complete"
  exit 0
}

# Function to display access information
display_access_info() {
  local rpc_pass=$(cat "${MEOWCOIN_DATA}/.meowcoin/rpc.pass" 2>/dev/null || echo "unknown")
  
  echo ""
  echo "----------------------------------------"
  echo "ACCESS INFORMATION"
  echo "----------------------------------------"
  echo "Web Dashboard: http://localhost:8080"
  echo ""
  echo "RPC Access:"
  echo "  Username: meowcoin"
  echo "  Password: ${rpc_pass}"
  echo "  Port: 9766"
  echo ""
  echo "CLI Access:"
  echo "  docker exec meowcoin-node cli getblockchaininfo"
  echo "----------------------------------------"
  echo ""
}

# Function to apply custom config if available
apply_custom_config() {
  if [ -f "${MEOWCOIN_CONFIG}/custom-meowcoin.conf" ]; then
    log_info "Found custom configuration, applying..."
    cat "${MEOWCOIN_CONFIG}/custom-meowcoin.conf" >> "${MEOWCOIN_CONFIG}/meowcoin.conf"
  fi
}

# Function to set up web server
setup_web_server() {
  # Ensure the API status file exists
  mkdir -p /var/www/html/api
  echo '{"status":"starting"}' > /var/www/html/api/status.json
  chown -R meowcoin:meowcoin /var/www/html/api
}

# Function to display help
display_help() {
  echo "Meowcoin Docker Container"
  echo ""
  echo "Usage:"
  echo "  docker exec meowcoin-node [COMMAND]"
  echo ""
  echo "Commands:"
  echo "  cli [args]    Run meowcoin-cli with given arguments"
  echo "  shell         Start a shell inside the container"
  echo "  help          Display this help message"
  echo ""
  echo "Examples:"
  echo "  docker exec meowcoin-node cli getblockchaininfo"
  echo "  docker exec meowcoin-node cli getnetworkinfo"
  echo "  docker exec meowcoin-node shell"
  echo ""
}