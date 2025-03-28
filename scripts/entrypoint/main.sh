# scripts/entrypoint/main.sh
#!/bin/bash
set -e

# Import modules
source /usr/local/bin/entrypoint/config.sh
source /usr/local/bin/entrypoint/security.sh
source /usr/local/bin/entrypoint/monitoring.sh
source /usr/local/bin/entrypoint/backup.sh
source /usr/local/bin/entrypoint/plugins.sh

# Log startup with timestamp
echo "[$(date -Iseconds)] Starting Meowcoin node container"
echo "[$(date -Iseconds)] Meowcoin version: $(cat /meowcoin_version.txt)"

# Setup environment
setup_environment
validate_configuration
setup_security_features
setup_monitoring_features
setup_backup_features

# Initialize plugin system if enabled
init_plugin_system

# Execute startup hooks
execute_hooks "startup"

# Log completion
echo "[$(date -Iseconds)] Configuration complete, starting supervisord"

# Register shutdown handler
trap "execute_hooks shutdown" SIGTERM SIGINT

# Keep container running with supervisord
exec supervisord -c /etc/supervisor/conf.d/meowcoin.conf