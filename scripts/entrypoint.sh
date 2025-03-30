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

# Check if we're handling a command
if [ "$1" = "cli" ]; then
  shift
  exec gosu meowcoin /usr/local/bin/meowcoin-cli -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" "$@"
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
  
  # Handle signals
  trap handle_shutdown SIGTERM SIGINT
  
 # Start Meowcoin daemon
  log_info "Starting Meowcoin daemon..."
  gosu meowcoin /usr/local/bin/meowcoind -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" &
  DAEMON_PID=$!
  
  # Wait for all processes
  wait $DAEMON_PID
  
  # If we get here, the daemon exited, so clean up
  if [ -n "$BACKEND_PID" ]; then
    kill $BACKEND_PID 2>/dev/null || true
  fi
  
  if [ -n "$BACKUP_PID" ]; then
    kill $BACKUP_PID 2>/dev/null || true
  fi
  
  log_info "Meowcoin daemon exited. Shutting down container."
fi