#!/bin/bash
# scripts/entrypoint/main.sh
# Main entrypoint script for Meowcoin Docker container

set -e

# Source library modules
source /usr/local/bin/lib/utils.sh
source /usr/local/bin/lib/config.sh
source /usr/local/bin/lib/security.sh
source /usr/local/bin/lib/monitoring.sh
source /usr/local/bin/lib/backup.sh

# Log startup with timestamp
log "Starting Meowcoin node container" "INFO"
log "Meowcoin version: $(cat /meowcoin_version.txt)" "INFO"

# Setup environment
log "Setting up environment" "INFO"
setup_environment

# Validate configuration
log "Validating configuration" "INFO"
validate_configuration

# Setup security features
log "Setting up security features" "INFO"
setup_security_features

# Setup monitoring features
log "Setting up monitoring features" "INFO"
init_monitoring

# Setup backup features
log "Setting up backup features" "INFO"
init_backup_system
setup_backup_features

# Initialize plugin system if enabled
if [ "${ENABLE_PLUGINS:-false}" = "true" ]; then
  log "Initializing plugin system" "INFO"
  if [ -x /usr/local/bin/entrypoint/plugins.sh ]; then
    /usr/local/bin/entrypoint/plugins.sh init
  fi
fi

# Execute startup hooks
if [ "${ENABLE_PLUGINS:-false}" = "true" ] && [ -x /usr/local/bin/entrypoint/plugins.sh ]; then
  log "Executing startup hooks" "INFO"
  /usr/local/bin/entrypoint/plugins.sh execute_hooks "startup"
fi

# Log completion
log "Configuration complete, starting supervisord" "INFO"

# Register shutdown handler
function shutdown_handler() {
  log "Shutdown signal received, cleaning up" "INFO"
  
  # Execute shutdown hooks
  if [ "${ENABLE_PLUGINS:-false}" = "true" ] && [ -x /usr/local/bin/entrypoint/plugins.sh ]; then
    /usr/local/bin/entrypoint/plugins.sh execute_hooks "shutdown"
  fi
  
  log "Shutdown complete" "INFO"
  exit 0
}

# Register signal handlers
trap shutdown_handler SIGTERM SIGINT

# Keep container running with supervisord
exec supervisord -c /etc/supervisor/conf.d/meowcoin.conf