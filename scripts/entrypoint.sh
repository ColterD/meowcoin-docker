#!/bin/bash
set -e

# Source helper functions
source /scripts/functions.sh

# Display banner
display_banner "🐱 Meowcoin Node"
echo "Version: $(get_version)"
echo "----------------------------------------"

# Create and fix permissions for data directories
for dir in "${MEOWCOIN_DATA}" "${MEOWCOIN_CONFIG}" "${MEOWCOIN_DATA}/.meowcoin"; do
    mkdir -p "$dir"
    chown meowcoin:meowcoin "$dir" 2>/dev/null || {
        log_error "Failed to set ownership for $dir. Ensure volume permissions allow UID 10000."
        exit 1
    }
    chmod 700 "$dir"
done

# Check if we're handling a command
if [ "$1" = "cli" ]; then
<<<<<<< HEAD
    shift
    exec gosu meowcoin /usr/local/bin/meowcoin-cli -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" "$@"
=======
  shift
  exec su-exec meowcoin /usr/local/bin/meowcoin-cli -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" "$@"
>>>>>>> parent of 0706e65 (refactor)
elif [ "$1" = "shell" ]; then
    exec /bin/bash
elif [ "$1" = "help" ]; then
<<<<<<< HEAD
    display_help
    exit 0
fi

# Auto-configure settings based on system resources (run once)
log_info "Running auto-configuration..."
/scripts/auto-configure.sh || {
    log_error "Auto-configuration failed. Check logs for details."
    exit 1
}

# Check for custom config and apply if exists
apply_custom_config

# Verify meowcoind exists and is executable
if [ ! -f "/usr/local/bin/meowcoind" ]; then
    log_error "CRITICAL ERROR: Meowcoin daemon not found at /usr/local/bin/meowcoind"
    log_error "Available files in /usr/local/bin:"
    ls -la /usr/local/bin
    exit 1
fi
if [ ! -x "/usr/local/bin/meowcoind" ]; then
    log_error "CRITICAL ERROR: Meowcoin daemon is not executable"
    log_error "Trying to fix permissions..."
    chmod +x /usr/local/bin/meowcoind
    if [ ! -x "/usr/local/bin/meowcoind" ]; then
        log_error "Failed to make daemon executable. Exiting."
        exit 1
    fi
fi

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

# Handle signals for clean shutdown
handle_shutdown() {
    log_info "Received shutdown signal. Cleaning up..."
    kill -TERM "$MONITOR_PID" 2>/dev/null || true
    kill -TERM "$NGINX_PID" 2>/dev/null || true
    if [ -n "$BACKUP_PID" ]; then
        kill -TERM "$BACKUP_PID" 2>/dev/null || true
    fi
    # Give processes a moment to shut down
    wait "$MONITOR_PID" "$NGINX_PID" "$BACKUP_PID" 2>/dev/null || true
    exit 0
}
trap handle_shutdown SIGTERM SIGINT

# Start Meowcoin daemon with retry logic
log_info "Starting Meowcoin daemon..."
RETRY_COUNT=0
MAX_RETRIES=3

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if gosu meowcoin /usr/local/bin/meowcoind -conf="${MEOWCOIN_CONFIG}/meowcoin.conf"; then
        log_info "Meowcoin daemon started successfully."
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        EXIT_CODE=$?
        log_error "Meowcoin daemon exited with code $EXIT_CODE (attempt $RETRY_COUNT of $MAX_RETRIES)"
        
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            log_info "Restarting daemon in 10 seconds..."
            sleep 10
        else
            log_error "Max retries reached. Exiting."
            handle_shutdown
            exit $EXIT_CODE
        fi
    fi
done

# Wait for background processes (shouldn't reach here unless daemon exits cleanly)
wait "$MONITOR_PID" "$NGINX_PID" "$BACKUP_PID" 2>/dev/null || true
=======
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
>>>>>>> parent of 0706e65 (refactor)
