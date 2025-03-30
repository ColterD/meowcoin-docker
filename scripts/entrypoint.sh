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
  exec su-exec meowcoin /usr/local/bin/meowcoin-cli -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" "$@"
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
  
  # Start the monitoring processes
  /scripts/node-monitor.sh &
  MONITOR_PID=$!
  
  # Start backup manager if enabled
  if [ "$BACKUP_ENABLED" = "true" ]; then
    /scripts/backup-manager.sh &
    BACKUP_PID=$!
  fi
  
  # Start the web server
  setup_web_server
  nginx &
  NGINX_PID=$!
  
  # Display access information
  display_access_info
  
  # Handle signals
  trap handle_shutdown SIGTERM SIGINT
  
  # Debugging: Check for meowcoind executable
  echo "Checking for meowcoind executable..."
  echo "Contents of /usr/local/bin:"
  ls -la /usr/local/bin
  echo "Searching for meowcoind in filesystem:"
  find / -name "meowcoind" 2>/dev/null || echo "No meowcoind found in filesystem"
  
  # Verify meowcoind exists
  if [ ! -f "/usr/local/bin/meowcoind" ]; then
    log_error "Meowcoin daemon not found at /usr/local/bin/meowcoind"
    log_error "Available files in /usr/local/bin:"
    ls -la /usr/local/bin
    exit 1
  fi
  
  # Start Meowcoin daemon
  echo "Starting Meowcoin daemon..."
  su-exec meowcoin /usr/local/bin/meowcoind -conf="${MEOWCOIN_CONFIG}/meowcoin.conf"
  
  # If we get here, the daemon exited, so clean up
  kill $MONITOR_PID 2>/dev/null || true
  kill $NGINX_PID 2>/dev/null || true
  if [ -n "$BACKUP_PID" ]; then
    kill $BACKUP_PID 2>/dev/null || true
  fi
fi