#!/bin/bash
# scripts/entrypoint/main.sh
# Main entrypoint script for Meowcoin Docker container

# Source dependency manager
source /usr/local/bin/core/dependencies.sh

# Log startup
log_info "Starting Meowcoin node container"
log_info "Meowcoin version: $(cat /meowcoin_version.txt 2>/dev/null || echo 'unknown')"

# Initialize all modules in proper order
initialize_all_modules

# Set up all modules
setup_all_modules

# Check for version changes and handle atomic updates if enabled
if [ "${ATOMIC_UPDATE_ENABLED:-true}" = "true" ] && type check_version_change >/dev/null 2>&1; then
    if check_version_change; then
        run_atomic_update
    fi
fi

# Execute startup hooks if plugins enabled
if [ "${ENABLE_PLUGINS:-false}" = "true" ] && type plugins_execute_hooks >/dev/null 2>&1; then
    log_info "Executing startup hooks"
    plugins_execute_hooks "startup"
fi

# Log completion
log_info "Configuration complete, starting supervisord"

# Register shutdown handler
function shutdown_handler() {
    log_info "Shutdown signal received, cleaning up"
    
    # Execute shutdown hooks if plugins enabled
    if [ "${ENABLE_PLUGINS:-false}" = "true" ] && type plugins_execute_hooks >/dev/null 2>&1; then
        plugins_execute_hooks "shutdown"
    fi
    
    log_info "Shutdown complete"
    exit 0
}

# Register signal handlers
trap shutdown_handler SIGTERM SIGINT

# Keep container running with supervisord
exec supervisord -c /etc/supervisor/conf.d/supervisord.conf