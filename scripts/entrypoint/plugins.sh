#!/bin/bash

# Plugin system for Meowcoin Docker
PLUGIN_DIR="/etc/meowcoin/plugins"
HOOK_REGISTRY="/tmp/plugin_hooks.json"

# Initialize the plugin system
function init_plugin_system() {
  echo "[$(date -Iseconds)] Initializing plugin system" | tee -a $LOG_FILE
  
  # Skip if plugins not enabled
  if [ "${ENABLE_PLUGINS:-false}" != "true" ]; then
    echo "[$(date -Iseconds)] Plugins disabled, skipping" | tee -a $LOG_FILE
    return 0
  fi
  
  # Check if plugin directory exists
  if [ ! -d "$PLUGIN_DIR" ]; then
    echo "[$(date -Iseconds)] Plugin directory not found: $PLUGIN_DIR" | tee -a $LOG_FILE
    mkdir -p "$PLUGIN_DIR"
    echo "[$(date -Iseconds)] Created empty plugin directory" | tee -a $LOG_FILE
    return 0
  fi
  
  # Initialize hook registry
  echo "{}" > $HOOK_REGISTRY
  
  # Load all plugins
  load_plugins
}

# Validate a plugin for security issues
function validate_plugin() {
  local PLUGIN_PATH="$1"
  
  echo "[$(date -Iseconds)] Validating plugin: $(basename $PLUGIN_PATH)" | tee -a $LOG_FILE
  
  # Check for suspicious commands
  if grep -q "curl\|wget\|nc\|ncat\|telnet" "$PLUGIN_PATH"; then
    echo "[$(date -Iseconds)] WARNING: Plugin contains networking commands, potential security risk" | tee -a $LOG_FILE
    return 1
  fi
  
  # Check for suspicious shell escapes
  if grep -q "eval\|exec [^;]*;" "$PLUGIN_PATH"; then
    echo "[$(date -Iseconds)] WARNING: Plugin contains potentially unsafe evaluation" | tee -a $LOG_FILE
    return 1
  fi
  
  # Check for excessive privileges
  if grep -q "sudo\|su " "$PLUGIN_PATH"; then
    echo "[$(date -Iseconds)] WARNING: Plugin attempts to escalate privileges" | tee -a $LOG_FILE
    return 1
  fi
  
  # Check for system file access outside the allowed paths
  if grep -q "/etc/\|/var/\|/root/\|/boot/" "$PLUGIN_PATH" | grep -v "/etc/meowcoin\|/var/log/meowcoin"; then
    echo "[$(date -Iseconds)] WARNING: Plugin attempts to access restricted system files" | tee -a $LOG_FILE
    return 1
  fi
  
  echo "[$(date -Iseconds)] Plugin validation passed: $(basename $PLUGIN_PATH)" | tee -a $LOG_FILE
  return 0
}

# Load all plugins from the plugin directory
function load_plugins() {
  echo "[$(date -Iseconds)] Loading plugins from $PLUGIN_DIR" | tee -a $LOG_FILE
  
  # Count plugins
  PLUGIN_COUNT=$(find "$PLUGIN_DIR" -name "*.sh" -type f | wc -l)
  echo "[$(date -Iseconds)] Found $PLUGIN_COUNT plugin(s)" | tee -a $LOG_FILE
  
  if [ $PLUGIN_COUNT -eq 0 ]; then
    return 0
  fi
  
  # Source each plugin
  for PLUGIN in "$PLUGIN_DIR"/*.sh; do
    if [ -f "$PLUGIN" ]; then
      echo "[$(date -Iseconds)] Processing plugin: $(basename $PLUGIN)" | tee -a $LOG_FILE
      
      # Check if plugin has execute permission
      if [ ! -x "$PLUGIN" ]; then
        echo "[$(date -Iseconds)] Adding execute permission to plugin" | tee -a $LOG_FILE
        chmod +x "$PLUGIN"
      fi
      
      # Validate plugin for security
      if ! validate_plugin "$PLUGIN"; then
        echo "[$(date -Iseconds)] Skipping plugin due to security concerns: $(basename $PLUGIN)" | tee -a $LOG_FILE
        # Rename the plugin to prevent future loading
        mv "$PLUGIN" "${PLUGIN}.disabled"
        echo "[$(date -Iseconds)] Plugin has been disabled: $(basename $PLUGIN).disabled" | tee -a $LOG_FILE
        continue
      fi
      
      # Create plugin environment
      PLUGIN_NAME=$(basename "$PLUGIN" .sh)
      PLUGIN_ENV="/tmp/plugin_env_${PLUGIN_NAME}"
      
      # Create plugin utility functions
      cat > "$PLUGIN_ENV" <<EOF
#!/bin/bash

# Plugin: $PLUGIN_NAME

# Register a hook
function register_hook() {
  local HOOK_NAME="\$1"
  local FUNCTION_NAME="\$2"
  
  # Validate hook name
  case "\$HOOK_NAME" in
    startup|shutdown|post_sync|backup_pre|backup_post)
      # Valid hook name
      ;;
    *)
      echo "[$(date -Iseconds)] Plugin $PLUGIN_NAME tried to register invalid hook: \$HOOK_NAME" | tee -a $LOG_FILE
      return 1
      ;;
  esac
  
  # Add hook to registry
  local CURRENT_HOOKS=\$(cat $HOOK_REGISTRY)
  local NEW_HOOKS=\$(echo \$CURRENT_HOOKS | jq --arg hook "\$HOOK_NAME" --arg func "\$FUNCTION_NAME" --arg plugin "$PLUGIN_NAME" '. + {(\$hook): (.[(\$hook)] // []) + [{"plugin": \$plugin, "function": \$func}]}')
  echo \$NEW_HOOKS > $HOOK_REGISTRY
  
  echo "[$(date -Iseconds)] Plugin $PLUGIN_NAME registered hook: \$HOOK_NAME -> \$FUNCTION_NAME" | tee -a $LOG_FILE
  return 0
}

# Log function for plugins
function plugin_log() {
  echo "[$(date -Iseconds)] [$PLUGIN_NAME] \$1" | tee -a $LOG_FILE
}

# Get plugin directory
function plugin_dir() {
  echo "$PLUGIN_DIR"
}

# Get meowcoin data directory
function meowcoin_data_dir() {
  echo "/home/meowcoin/.meowcoin"
}

# Get meowcoin config
function meowcoin_config() {
  echo "/home/meowcoin/.meowcoin/meowcoin.conf"
}

# Send RPC command
function meowcoin_rpc() {
  local CMD="\$1"
  shift
  meowcoin-cli -conf="\$(meowcoin_config)" "\$CMD" "\$@"
}

# Execute a command with timeout and restricted environment
function plugin_exec() {
  timeout 10s \$@
}
EOF
      
      # Source the plugin environment
      source "$PLUGIN_ENV"
      
      # Source the plugin with error handling
      {
        source "$PLUGIN"
        echo "[$(date -Iseconds)] Plugin loaded: $PLUGIN_NAME" | tee -a $LOG_FILE
      } || {
        echo "[$(date -Iseconds)] ERROR: Failed to load plugin: $PLUGIN_NAME" | tee -a $LOG_FILE
      }
    fi
  done
}

# Execute hooks by name
function execute_hooks() {
  local HOOK_NAME="$1"
  
  # Skip if plugins not enabled
  if [ "${ENABLE_PLUGINS:-false}" != "true" ]; then
    return 0
  fi
  
  echo "[$(date -Iseconds)] Executing hooks: $HOOK_NAME" | tee -a $LOG_FILE
  
  # Check if hook registry exists
  if [ ! -f "$HOOK_REGISTRY" ]; then
    echo "[$(date -Iseconds)] Hook registry not found: $HOOK_REGISTRY" | tee -a $LOG_FILE
    return 1
  fi
  
  # Get hooks for this hook name
  local HOOKS=$(cat $HOOK_REGISTRY | jq -r --arg hook "$HOOK_NAME" '.[$hook] // [] | .[]')
  
  if [ -z "$HOOKS" ]; then
    echo "[$(date -Iseconds)] No hooks registered for: $HOOK_NAME" | tee -a $LOG_FILE
    return 0
  fi
  
  # Execute each hook
  while IFS= read -r HOOK; do
    local PLUGIN=$(echo $HOOK | jq -r '.plugin')
    local FUNCTION=$(echo $HOOK | jq -r '.function')
    
    echo "[$(date -Iseconds)] Executing hook: $HOOK_NAME -> $PLUGIN.$FUNCTION" | tee -a $LOG_FILE
    
    # Source plugin environment
    PLUGIN_ENV="/tmp/plugin_env_${PLUGIN}"
    if [ -f "$PLUGIN_ENV" ]; then
      source "$PLUGIN_ENV"
      
      # Execute function with timeout for safety
      if type "$FUNCTION" &>/dev/null; then
        (
          # Execute in subshell with timeout for safety
          timeout 30s "$FUNCTION" 2>&1 | tee -a $LOG_FILE
        )
        HOOK_STATUS=$?
        if [ $HOOK_STATUS -eq 124 ]; then
          echo "[$(date -Iseconds)] WARNING: Hook execution timed out: $PLUGIN.$FUNCTION" | tee -a $LOG_FILE
        elif [ $HOOK_STATUS -ne 0 ]; then
          echo "[$(date -Iseconds)] WARNING: Hook execution failed: $PLUGIN.$FUNCTION (status $HOOK_STATUS)" | tee -a $LOG_FILE
        fi
      else
        echo "[$(date -Iseconds)] ERROR: Function not found: $FUNCTION" | tee -a $LOG_FILE
      fi
    else
      echo "[$(date -Iseconds)] ERROR: Plugin environment not found: $PLUGIN" | tee -a $LOG_FILE
    fi
  done <<< "$HOOKS"
  
  echo "[$(date -Iseconds)] Finished executing hooks: $HOOK_NAME" | tee -a $LOG_FILE
}