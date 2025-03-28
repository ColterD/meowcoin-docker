
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

# Description: A simple plugin that monitors blockchain height
# Author: Your Name
# Version: 1.0.0
# Requires: jq

function on_startup() {
  plugin_log "Starting my custom plugin"
  # Add custom functionality here
}

function on_shutdown() {
  plugin_log "Shutting down my custom plugin"
  # Cleanup operations
}

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
- `backup_error`: Called when a backup operation fails  
- `health_check`: Called during health checks  
- `periodic`: Called on a regular schedule (if enabled)

## Plugin API

Plugins have access to several helper functions:

- `plugin_log "message" ["level"]`
- `plugin_dir`
- `plugin_data_dir`
- `plugin_config_dir`
- `meowcoin_data_dir`
- `meowcoin_config`
- `meowcoin_rpc "command" "param1" "param2"`
- `plugin_exec "command"`
- `plugin_config_get "key" ["default"]`
- `plugin_config_set "key" "value"`
- `plugin_state_save "key" "value"`
- `plugin_state_get "key" ["default"]`
- `plugin_get_trace_id`
- `plugin_get_hook_args`
- `plugin_check_resources "resource"`
- `plugin_send_metric "name" "value" ["type"]`

## Security Considerations

Plugins are validated for security concerns. Plugins that attempt to:

- Execute networking commands (`curl`, `wget`, `nc`)
- Use potentially unsafe evaluation (`eval`, `exec`)
- Escalate privileges (`sudo`, `su`)
- Access restricted system files

will be disabled automatically for security reasons.

## Advanced Plugin Example: Chain Analysis

```bash
#!/bin/bash
# plugins/chain-analyzer.sh

# Description: Analyzes blockchain metrics and reports anomalies
# Author: Your Name
# Version: 1.0.0
# Requires: jq

function initialize() {
  plugin_log "Initializing chain analyzer plugin"
  plugin_state_save "last_analysis" "0"
}

function analyze_chain() {
  plugin_log "Running chain analysis"
  BLOCKCHAIN_INFO=$(meowcoin_rpc getblockchaininfo)
  if [ $? -ne 0 ]; then
    plugin_log "Failed to get blockchain info" "ERROR"
    return 1
  fi
  BLOCKS=$(echo $BLOCKCHAIN_INFO | jq -r '.blocks')
  SIZE=$(echo $BLOCKCHAIN_INFO | jq -r '.size_on_disk')
  AVG_BLOCK_SIZE=$(echo "scale=2; $SIZE / $BLOCKS" | bc)
  plugin_log "Average block size: $AVG_BLOCK_SIZE bytes"
  plugin_send_metric "avg_block_size" "$AVG_BLOCK_SIZE"
  plugin_state_save "last_analysis" "$(date +%s)"
  plugin_state_save "last_block_count" "$BLOCKS"
  return 0
}

function detect_block_changes() {
  CURRENT_BLOCKS=$(meowcoin_rpc getblockcount)
  if [ $? -ne 0 ]; then
    plugin_log "Failed to get block count" "ERROR"
    return 1
  fi
  LAST_BLOCKS=$(plugin_state_get "last_block_count" "0")
  NEW_BLOCKS=$((CURRENT_BLOCKS - LAST_BLOCKS))
  if [ $NEW_BLOCKS -gt 0 ]; then
    plugin_log "Detected $NEW_BLOCKS new blocks"
    for ((i=0; i<$NEW_BLOCKS && i<10; i++)); do
      BLOCK_HEIGHT=$((CURRENT_BLOCKS - i))
      BLOCK_HASH=$(meowcoin_rpc getblockhash $BLOCK_HEIGHT)
      BLOCK_INFO=$(meowcoin_rpc getblock $BLOCK_HASH)
      TX_COUNT=$(echo $BLOCK_INFO | jq -r '.nTx')
      BLOCK_SIZE=$(echo $BLOCK_INFO | jq -r '.size')
      plugin_log "Block $BLOCK_HEIGHT: $TX_COUNT transactions, $BLOCK_SIZE bytes"
      plugin_send_metric "last_block_txcount" "$TX_COUNT"
      plugin_send_metric "last_block_size" "$BLOCK_SIZE"
    done
    plugin_state_save "last_block_count" "$CURRENT_BLOCKS"
  fi
  return 0
}

function on_health_check() {
  HEALTH_STATUS=$1
  if [ "$HEALTH_STATUS" = "healthy" ]; then
    plugin_log "Node is healthy, running analysis"
    analyze_chain
  else
    plugin_log "Node reports issues, skipping analysis"
  fi
}

register_hook "startup" initialize
register_hook "periodic" detect_block_changes
register_hook "health_check" on_health_check
```

## Plugin Resource Isolation

Plugins run with resource limits:

- Memory: 50MB per plugin  
- CPU: 50% of one core  
- Timeout: 30 seconds per hook  
- I/O: 250 operations per second

## Plugin Management

```bash
# List all plugins
docker exec meowcoin-node /usr/local/bin/entrypoint/plugins.sh list

# Enable a plugin
docker exec meowcoin-node /usr/local/bin/entrypoint/plugins.sh enable my-plugin

# Disable a plugin
docker exec meowcoin-node /usr/local/bin/entrypoint/plugins.sh disable my-plugin

# Refresh a plugin
docker exec meowcoin-node /usr/local/bin/entrypoint/plugins.sh refresh my-plugin

# Generate docs
docker exec meowcoin-node /usr/local/bin/entrypoint/plugins.sh docs

# View metrics
docker exec meowcoin-node /usr/local/bin/entrypoint/plugins.sh metrics
```

## Debugging Plugins

Plugin logs:

- Main log: `/var/log/meowcoin/plugins.log`
- Hook logs: `/var/log/meowcoin/hooks/plugin_name_function_timestamp.log`
- Plugin data: `/etc/meowcoin/plugins/data/plugin_name/`

Use `plugin_log` for debugging within your plugin.
