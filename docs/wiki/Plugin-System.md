
# Plugin System

The Meowcoin Docker container supports a flexible plugin system for extending functionality without modifying the core container code.

## Enabling Plugins

To enable the plugin system, add the following to your `docker-compose.yml`:

```yaml
services:
  meowcoin:
    # ... other configuration ...
    volumes:
      - meowcoin-data:/home/meowcoin/.meowcoin
      - ./plugins:/etc/meowcoin/plugins  # Mount your plugins directory
    environment:
      - ENABLE_PLUGINS=true
```

## Creating Plugins

Plugins are shell scripts that are loaded at container startup. Create your plugin files in the mounted plugins directory:

```bash
#!/bin/bash
# my-custom-plugin.sh

# This function will be called when the container starts
function on_startup() {
  plugin_log "Starting my custom plugin"
  # Add custom functionality here
}

# This function will be called when the container shuts down
function on_shutdown() {
  plugin_log "Shutting down my custom plugin"
  # Cleanup operations
}

# Register hooks to container lifecycle events
register_hook "startup" on_startup
register_hook "shutdown" on_shutdown
```

## Available Hooks

The following hooks are available for plugins:

- `startup`: Called when the container starts  
- `shutdown`: Called when the container stops  
- `post_sync`: Called when blockchain sync completes  
- `backup_pre`: Called before backup creation  
- `backup_post`: Called after backup completion  

## Plugin API

Plugins have access to several helper functions:

- `plugin_log "message"`: Write messages to the container log  
- `plugin_dir`: Get the plugin directory path  
- `meowcoin_data_dir`: Get the Meowcoin data directory  
- `meowcoin_config`: Get the path to the Meowcoin configuration file  
- `meowcoin_rpc "command" "param1" "param2"`: Execute RPC commands  
- `plugin_exec "command"`: Execute a command with safety timeout  

## Security Considerations

Plugins are validated for security concerns. Plugins that attempt to:

- Execute networking commands (curl, wget, nc)  
- Use potentially unsafe evaluation (eval, exec)  
- Escalate privileges (sudo, su)  
- Access restricted system files  

will be disabled automatically for security reasons.

## Example Plugins

### Performance Monitoring Plugin

```bash
#!/bin/bash
# performance-monitor.sh

function collect_metrics() {
  plugin_log "Collecting performance metrics"
  
  # Get blockchain info
  BLOCKINFO=$(meowcoin_rpc getblockchaininfo)
  BLOCKS=$(echo $BLOCKINFO | jq -r '.blocks')
  
  # Log results
  plugin_log "Current block height: $BLOCKS"
  
  # Record to metrics file
  echo "$(date -Iseconds) blocks=$BLOCKS" >> $(meowcoin_data_dir)/metrics.log
}

# Register to run after startup
register_hook "startup" collect_metrics

# Run periodically via cron
if [ ! -f /etc/cron.d/metrics-collector ]; then
  echo "*/15 * * * * meowcoin /etc/meowcoin/plugins/performance-monitor.sh" > /etc/cron.d/metrics-collector
  chmod 644 /etc/cron.d/metrics-collector
fi
```

### Custom Notification Plugin

```bash
#!/bin/bash
# notifications.sh

function send_notification() {
  EVENT=$1
  MESSAGE=$2
  
  plugin_log "Notification: $EVENT - $MESSAGE"
  
  # Add your notification logic here
  # E.g., webhook, local file, etc.
  echo "$(date -Iseconds) [$EVENT] $MESSAGE" >> $(meowcoin_data_dir)/notifications.log
}

function on_startup() {
  send_notification "startup" "Meowcoin node started"
}

function on_shutdown() {
  send_notification "shutdown" "Meowcoin node stopped"
}

function pre_backup() {
  send_notification "backup" "Starting blockchain backup"
}

function post_backup() {
  send_notification "backup" "Completed blockchain backup"
}

# Register all hooks
register_hook "startup" on_startup
register_hook "shutdown" on_shutdown
register_hook "backup_pre" pre_backup
register_hook "backup_post" post_backup
```
