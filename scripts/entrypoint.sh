#!/bin/bash
set -e

# Source helper functions
source /scripts/functions.sh

# Display banner
display_banner "🐱 Meowcoin Node"
echo "Version: $(get_version)"
echo "----------------------------------------"

# Create data directories
mkdir -p "${MEOWCOIN_DATA}"
mkdir -p "${MEOWCOIN_CONFIG}"
mkdir -p "${MEOWCOIN_DATA}/.meowcoin"

# Securely handle shutdown
handle_shutdown() {
  echo "Received shutdown signal, gracefully stopping services..."
  
  # Stop backend server if running
  if [ -n "$BACKEND_PID" ] && kill -0 $BACKEND_PID 2>/dev/null; then
    echo "Stopping backend server..."
    kill -TERM $BACKEND_PID
    wait $BACKEND_PID 2>/dev/null || true
  fi
  
  # Stop backup manager if running
  if [ -n "$BACKUP_PID" ] && kill -0 $BACKUP_PID 2>/dev/null; then
    echo "Stopping backup manager..."
    kill -TERM $BACKUP_PID
    wait $BACKUP_PID 2>/dev/null || true
  fi
  
  # Stop Meowcoin daemon gracefully
  if [ -n "$DAEMON_PID" ] && kill -0 $DAEMON_PID 2>/dev/null; then
    echo "Stopping Meowcoin daemon gracefully..."
    gosu meowcoin meowcoin-cli -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" stop
    
    # Wait for daemon to stop with timeout
    TIMEOUT=60
    while [ $TIMEOUT -gt 0 ]; do
      if ! kill -0 $DAEMON_PID 2>/dev/null; then
        break
      fi
      sleep 1
      TIMEOUT=$((TIMEOUT - 1))
    done
    
    # Force kill if still running after timeout
    if kill -0 $DAEMON_PID 2>/dev/null; then
      echo "Daemon not responding, forcing shutdown..."
      kill -9 $DAEMON_PID 2>/dev/null || true
    fi
  fi
  
  echo "Shutdown complete."
  exit 0
}

# Check if we're handling a command
if [ "$1" = "cli" ]; then
  shift
  if [ $# -eq 0 ]; then
    echo "Error: No command specified"
    exit 1
  fi
  
  # Sanitize inputs for security
  SAFE_ARGS=""
  for arg in "$@"; do
    # Basic sanitization - can be improved
    SAFE_ARG=$(echo "$arg" | tr -cd '[:alnum:]._-')
    SAFE_ARGS="$SAFE_ARGS $SAFE_ARG"
  done
  
  exec gosu meowcoin /usr/local/bin/meowcoin-cli -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" $SAFE_ARGS
elif [ "$1" = "shell" ]; then
  exec /bin/bash
elif [ "$1" = "help" ]; then
  display_help
  exit 0
else
  # Auto-configure settings based on system resources
  /scripts/auto-configure.sh
  
  # Check for custom config and apply if exists
  apply_custom_config
  
  # Verify meowcoind exists and is executable
  if [ ! -f "/usr/local/bin/meowcoind" ] || [ ! -x "/usr/local/bin/meowcoind" ]; then
    log_error "CRITICAL ERROR: Meowcoin daemon not found or not executable"
    exit 1
  fi
  
  # Display access information
  display_access_info
  
  # Set up signal handlers
  trap handle_shutdown SIGTERM SIGINT SIGHUP
  
  # Start backup manager if enabled
  if [ "$BACKUP_ENABLED" = "true" ]; then
    /scripts/backup-manager.sh &
    BACKUP_PID=$!
  fi
  
  # Start Node.js backend in background
  cd /app/backend
  log_info "Starting Node.js backend server"
  node dist/index.js &
  BACKEND_PID=$!
  
  # Start Meowcoin daemon
  log_info "Starting Meowcoin daemon..."
  gosu meowcoin /usr/local/bin/meowcoind -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" &
  DAEMON_PID=$!
  
  # Wait for any process to exit
  wait -n
  
  # If we get here, one of the processes exited, so clean up
  handle_shutdown
fi