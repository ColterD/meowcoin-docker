#!/bin/bash
# Main entrypoint script for Meowcoin Docker container

# Source core libraries
source /usr/local/bin/core/utils.sh
source /usr/local/bin/core/config.sh
source /usr/local/bin/core/monitor.sh
source /usr/local/bin/core/backup.sh
source /usr/local/bin/core/security.sh

# Log startup with timestamp
log_info "Starting Meowcoin node container"
log_info "Meowcoin version: $(cat /meowcoin_version.txt)"

# Initialize systems
log_info "Initializing systems"
utils_init       # Initialize utilities
config_init      # Initialize configuration
security_init    # Initialize security features
monitor_init     # Initialize monitoring
backup_init      # Initialize backup system

# Setup environment
log_info "Setting up environment"
setup_environment

# Validate and update configuration
log_info "Validating configuration"
validate_configuration

# Setup security features
log_info "Setting up security features"
security_setup

# Setup monitoring features
log_info "Setting up monitoring features"
monitor_setup

# Setup backup features
log_info "Setting up backup features"
backup_setup

# Initialize plugin system if enabled
if [[ "${ENABLE_PLUGINS:-false}" == "true" ]]; then
    log_info "Initializing plugin system"
    if [[ -x /usr/local/bin/core/plugins.sh ]]; then
        source /usr/local/bin/core/plugins.sh
        plugins_init
    fi
fi

# Execute startup hooks
if [[ "${ENABLE_PLUGINS:-false}" == "true" ]]; then
    log_info "Executing startup hooks"
    plugins_execute_hooks "startup"
fi

# Log completion
log_info "Configuration complete, starting supervisord"

# Register shutdown handler
function shutdown_handler() {
    log_info "Shutdown signal received, cleaning up"
    
    # Execute shutdown hooks
    if [[ "${ENABLE_PLUGINS:-false}" == "true" ]]; then
        plugins_execute_hooks "shutdown"
    fi
    
    log_info "Shutdown complete"
    exit 0
}

# Register signal handlers
trap shutdown_handler SIGTERM SIGINT

# Keep container running with supervisord
exec supervisord -c /etc/supervisor/conf.d/meowcoin.conf