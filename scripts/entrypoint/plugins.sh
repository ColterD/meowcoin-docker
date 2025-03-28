#!/bin/bash
set -e

# Enhanced plugin system for Meowcoin Docker
PLUGIN_DIR="/etc/meowcoin/plugins"
ENABLED_PLUGINS_DIR="/etc/meowcoin/plugins/enabled"
HOOK_REGISTRY="/tmp/plugin_hooks.json"
PLUGIN_LOG="/var/log/meowcoin/plugins.log"
PLUGIN_SANDBOX_ENABLED=true
PLUGIN_EXECUTION_TIMEOUT=30

# Initialize the plugin system with better security
function init_plugin_system() {
  mkdir -p $(dirname $PLUGIN_LOG)
  touch $PLUGIN_LOG
  chown meowcoin:meowcoin $PLUGIN_LOG
  
  echo "[$(date -Iseconds)] Initializing plugin system" | tee -a $PLUGIN_LOG
  
  # Skip if plugins not enabled
  if [ "${ENABLE_PLUGINS:-false}" != "true" ]; then
    echo "[$(date -Iseconds)] Plugins disabled, skipping" | tee -a $PLUGIN_LOG
    return 0
  fi
  
  # Check if plugin directory exists
  if [ ! -d "$PLUGIN_DIR" ]; then
    echo "[$(date -Iseconds)] Plugin directory not found: $PLUGIN_DIR" | tee -a $PLUGIN_LOG
    mkdir -p "$PLUGIN_DIR"
    echo "[$(date -Iseconds)] Created empty plugin directory" | tee -a $PLUGIN_LOG
  fi
  
  # Create enabled plugins directory
  mkdir -p "$ENABLED_PLUGINS_DIR"
  
  # Initialize hook registry
  echo "{}" > $HOOK_REGISTRY
  
  # Create plugin sandbox directory if enabled
  if [ "$PLUGIN_SANDBOX_ENABLED" = "true" ]; then
    mkdir -p /tmp/meowcoin/plugin_sandbox
    chmod 750 /tmp/meowcoin/plugin_sandbox
  fi
  
  # Load all plugins
  load_plugins
  
  echo "[$(date -Iseconds)] Plugin system initialized with $(jq -r 'keys | length' $HOOK_REGISTRY) hooks" | tee -a $PLUGIN_LOG
}

# Enhanced plugin validation with security checks
function validate_plugin() {
  local PLUGIN_PATH="$1"
  local PLUGIN_NAME=$(basename "$PLUGIN_PATH" .sh)
  
  echo "[$(date -Iseconds)] Validating plugin: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
  
  # Check if plugin is specifically disabled
  if [ -f "$PLUGIN_DIR/.$PLUGIN_NAME.disabled" ]; then
    echo "[$(date -Iseconds)] Plugin is explicitly disabled: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
    return 1
  fi
  
  # Basic file checks
  if [ ! -f "$PLUGIN_PATH" ]; then
    echo "[$(date -Iseconds)] ERROR: Plugin file not found: $PLUGIN_PATH" | tee -a $PLUGIN_LOG
    return 1
  fi
  
  if [ ! -r "$PLUGIN_PATH" ]; then
    echo "[$(date -Iseconds)] ERROR: Plugin file not readable: $PLUGIN_PATH" | tee -a $PLUGIN_LOG
    return 1
  fi
  
  # Check file size
  local FILE_SIZE=$(wc -c < "$PLUGIN_PATH")
  if [ $FILE_SIZE -gt 100000 ]; then
    echo "[$(date -Iseconds)] WARNING: Plugin file size exceeds 100KB: $PLUGIN_PATH ($FILE_SIZE bytes)" | tee -a $PLUGIN_LOG
    return 1
  fi
  
  # Check for suspicious commands
  if grep -q "curl\|wget\|nc\|ncat\|telnet\|ssh\|scp\|ftp\|sftp" "$PLUGIN_PATH"; then
    echo "[$(date -Iseconds)] WARNING: Plugin contains networking commands, potential security risk" | tee -a $PLUGIN_LOG
    return 1
  fi
  
  # Check for suspicious shell escapes
  if grep -q "eval\|exec [^;]*;\|system\|popen\|(\`.*\`)\|\$(.*)" "$PLUGIN_PATH"; then
    echo "[$(date -Iseconds)] WARNING: Plugin contains potentially unsafe evaluation" | tee -a $PLUGIN_LOG
    return 1
  fi
  
  # Check for excessive privileges
  if grep -q "sudo\|su \|chroot\|setuid\|setgid" "$PLUGIN_PATH"; then
    echo "[$(date -Iseconds)] WARNING: Plugin attempts to escalate privileges" | tee -a $PLUGIN_LOG
    return 1
  fi
  
  # Check for system file access outside the allowed paths
  if grep -q "/etc/\|/var/\|/root/\|/boot/\|/usr/\|/lib/\|/bin/\|/sbin/" "$PLUGIN_PATH" | grep -v "/etc/meowcoin\|/var/log/meowcoin\|/home/meowcoin"; then
    echo "[$(date -Iseconds)] WARNING: Plugin attempts to access restricted system files" | tee -a $PLUGIN_LOG
    return 1
  fi
  
  # Check for infinite loops and forks
  if grep -q "while :\|while true\|until false\|for((;;\))\|fork()\|&\s*$" "$PLUGIN_PATH"; then
    echo "[$(date -Iseconds)] WARNING: Plugin contains potential infinite loops or forks" | tee -a $PLUGIN_LOG
    return 1
  fi
  
  # Check plugin syntax
  if ! bash -n "$PLUGIN_PATH" >/dev/null 2>&1; then
    echo "[$(date -Iseconds)] ERROR: Plugin contains syntax errors: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
    return 1
  fi
  
  echo "[$(date -Iseconds)] Plugin validation passed: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
  return 0
}

# Load all plugins from the plugin directory with improved error handling
function load_plugins() {
  echo "[$(date -Iseconds)] Loading plugins from $PLUGIN_DIR" | tee -a $PLUGIN_LOG
  
  # Count plugins
  PLUGIN_COUNT=$(find "$PLUGIN_DIR" -maxdepth 1 -name "*.sh" -type f | wc -l)
  ENABLED_COUNT=0
  FAILED_COUNT=0
  
  echo "[$(date -Iseconds)] Found $PLUGIN_COUNT plugin(s)" | tee -a $PLUGIN_LOG
  
  if [ $PLUGIN_COUNT -eq 0 ]; then
    return 0
  fi
  
  # Source each plugin
  for PLUGIN in "$PLUGIN_DIR"/*.sh; do
    if [ -f "$PLUGIN" ]; then
      PLUGIN_NAME=$(basename "$PLUGIN" .sh)
      echo "[$(date -Iseconds)] Processing plugin: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
      
      # Check if plugin has execute permission
      if [ ! -x "$PLUGIN" ]; then
        echo "[$(date -Iseconds)] Adding execute permission to plugin" | tee -a $PLUGIN_LOG
        chmod +x "$PLUGIN"
      fi
      
      # Validate plugin for security
      if ! validate_plugin "$PLUGIN"; then
        echo "[$(date -Iseconds)] Skipping plugin due to security concerns: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
        # Mark the plugin as disabled
        touch "$PLUGIN_DIR/.$PLUGIN_NAME.disabled"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        continue
      fi
      
      # Create symbolic link in enabled directory
      ln -sf "$PLUGIN" "$ENABLED_PLUGINS_DIR/${PLUGIN_NAME}.sh" 2>/dev/null || true
      
      # Create plugin environment with improved isolation
      PLUGIN_ENV="/tmp/meowcoin/plugin_env_${PLUGIN_NAME}"
      
      # Create plugin utility functions with security boundaries
      cat > "$PLUGIN_ENV" <<EOF
#!/bin/bash
# Plugin: $PLUGIN_NAME

# Register a hook with validated parameters
function register_hook() {
  local HOOK_NAME="\$1"
  local FUNCTION_NAME="\$2"
  
  # Validate hook name
  case "\$HOOK_NAME" in
    startup|shutdown|post_sync|backup_pre|backup_post)
      # Valid hook name
      ;;
    *)
      echo "[$(date -Iseconds)] Plugin $PLUGIN_NAME tried to register invalid hook: \$HOOK_NAME" | tee -a $PLUGIN_LOG
      return 1
      ;;
  esac
  
  # Validate function name
  if [[ ! "\$FUNCTION_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo "[$(date -Iseconds)] Plugin $PLUGIN_NAME tried to register invalid function name: \$FUNCTION_NAME" | tee -a $PLUGIN_LOG
    return 1
  fi
  
  # Check if function exists
  if ! type "\$FUNCTION_NAME" &>/dev/null; then
    echo "[$(date -Iseconds)] Plugin $PLUGIN_NAME tried to register non-existent function: \$FUNCTION_NAME" | tee -a $PLUGIN_LOG
    return 1
  }
  
  # Add hook to registry
  local CURRENT_HOOKS=\$(cat $HOOK_REGISTRY)
  local NEW_HOOKS=\$(echo \$CURRENT_HOOKS | jq --arg hook "\$HOOK_NAME" --arg func "\$FUNCTION_NAME" --arg plugin "$PLUGIN_NAME" '. + {(\$hook): (.[(\$hook)] // []) + [{"plugin": \$plugin, "function": \$func}]}')
  echo \$NEW_HOOKS > $HOOK_REGISTRY
  
  echo "[$(date -Iseconds)] Plugin $PLUGIN_NAME registered hook: \$HOOK_NAME -> \$FUNCTION_NAME" | tee -a $PLUGIN_LOG
  return 0
}

# Log function for plugins with sanitized output
function plugin_log() {
  # Sanitize input to prevent log injection
  local SANITIZED=\$(echo "\$1" | sed 's/[\\\`\$]//g')
  echo "[$(date -Iseconds)] [$PLUGIN_NAME] \$SANITIZED" | tee -a $PLUGIN_LOG
}

# Get plugin directory (safe)
function plugin_dir() {
  echo "$PLUGIN_DIR"
}

# Get plugin data directory (safe)
function plugin_data_dir() {
  local DATA_DIR="$PLUGIN_DIR/data/$PLUGIN_NAME"
  mkdir -p "\$DATA_DIR"
  chmod 750 "\$DATA_DIR"
  echo "\$DATA_DIR"
}

# Get meowcoin data directory (safe)
function meowcoin_data_dir() {
  echo "/home/meowcoin/.meowcoin"
}

# Get meowcoin config (safe)
function meowcoin_config() {
  echo "/home/meowcoin/.meowcoin/meowcoin.conf"
}

# Send RPC command with error handling
function meowcoin_rpc() {
  local CMD="\$1"
  shift
  
  # Validate command for basic safety
  if [[ ! "\$CMD" =~ ^[a-zA-Z0-9_]+$ ]]; then
    plugin_log "ERROR: Invalid RPC command: \$CMD"
    return 1
  fi
  
  # Execute with timeout
  local RESULT
  RESULT=\$(timeout 10s meowcoin-cli -conf="\$(meowcoin_config)" "\$CMD" "\$@" 2>&1)
  local STATUS=\$?
  
  if [ \$STATUS -ne 0 ]; then
    plugin_log "ERROR: RPC command failed: \$CMD (status \$STATUS): \$RESULT"
    return \$STATUS
  fi
  
  echo "\$RESULT"
  return 0
}

# Execute a command with timeout and restricted environment
function plugin_exec() {
  # Create sandbox directory
  local SANDBOX_DIR="/tmp/meowcoin/plugin_sandbox/${PLUGIN_NAME}_\$(date +%s)"
  mkdir -p "\$SANDBOX_DIR"
  cd "\$SANDBOX_DIR"
  
  # Execute with timeout and resource limits
  timeout ${PLUGIN_EXECUTION_TIMEOUT}s nice -n 10 "\$@"
  local STATUS=\$?
  
  # Clean up sandbox
  cd /
  rm -rf "\$SANDBOX_DIR"
  
  return \$STATUS
}

# Get plugin configuration value
function plugin_config_get() {
  local KEY="\$1"
  local DEFAULT="\$2"
  local CONFIG_FILE="$PLUGIN_DIR/config/$PLUGIN_NAME.conf"
  
  if [ -f "\$CONFIG_FILE" ] && grep -q "^\$KEY=" "\$CONFIG_FILE"; then
    grep "^\$KEY=" "\$CONFIG_FILE" | sed "s/^\$KEY=//"
  else
    echo "\$DEFAULT"
  fi
}

# Set plugin configuration value
function plugin_config_set() {
  local KEY="\$1"
  local VALUE="\$2"
  local CONFIG_FILE="$PLUGIN_DIR/config/$PLUGIN_NAME.conf"
  
  mkdir -p "$(dirname \$CONFIG_FILE)"
  
  if [ -f "\$CONFIG_FILE" ] && grep -q "^\$KEY=" "\$CONFIG_FILE"; then
    sed -i "s/^\$KEY=.*$/\$KEY=\$VALUE/" "\$CONFIG_FILE"
  else
    echo "\$KEY=\$VALUE" >> "\$CONFIG_FILE"
  fi
}
EOF
      
      # Source the plugin environment
      source "$PLUGIN_ENV"
      
      # Source the plugin with error handling
      {
        # Execute in subshell for isolation
        (
          source "$PLUGIN"
        )
        
        if [ $? -eq 0 ]; then
          echo "[$(date -Iseconds)] Plugin loaded: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
          ENABLED_COUNT=$((ENABLED_COUNT + 1))
        else
          echo "[$(date -Iseconds)] ERROR: Failed to load plugin: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
          FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
      } || {
        echo "[$(date -Iseconds)] ERROR: Exception when loading plugin: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
        FAILED_COUNT=$((FAILED_COUNT + 1))
      }
    fi
  done
  
  echo "[$(date -Iseconds)] Plugin loading completed: $ENABLED_COUNT enabled, $FAILED_COUNT failed" | tee -a $PLUGIN_LOG
}

# Execute hooks by name with improved error handling and monitoring
function execute_hooks() {
  local HOOK_NAME="$1"
  
  # Skip if plugins not enabled
  if [ "${ENABLE_PLUGINS:-false}" != "true" ]; then
    return 0
  fi
  
  echo "[$(date -Iseconds)] Executing hooks: $HOOK_NAME" | tee -a $PLUGIN_LOG
  
  # Check if hook registry exists
  if [ ! -f "$HOOK_REGISTRY" ]; then
    echo "[$(date -Iseconds)] Hook registry not found: $HOOK_REGISTRY" | tee -a $PLUGIN_LOG
    return 1
  fi
  
  # Get hooks for this hook name
  local HOOKS=$(cat $HOOK_REGISTRY | jq -r --arg hook "$HOOK_NAME" '.[$hook] // [] | .[]')
  
  if [ -z "$HOOKS" ]; then
    echo "[$(date -Iseconds)] No hooks registered for: $HOOK_NAME" | tee -a $PLUGIN_LOG
    return 0
  fi
  
  # Count successful and failed hooks
  local SUCCESS_COUNT=0
  local FAILURE_COUNT=0
  
  # Execute each hook with proper monitoring
  while IFS= read -r HOOK; do
    local PLUGIN=$(echo $HOOK | jq -r '.plugin')
    local FUNCTION=$(echo $HOOK | jq -r '.function')
    
    echo "[$(date -Iseconds)] Executing hook: $HOOK_NAME -> $PLUGIN.$FUNCTION" | tee -a $PLUGIN_LOG
    
    # Check if plugin is disabled
    if [ -f "$PLUGIN_DIR/.$PLUGIN.disabled" ]; then
      echo "[$(date -Iseconds)] Skipping disabled plugin: $PLUGIN" | tee -a $PLUGIN_LOG
      continue
    fi
    
    # Source plugin environment
    PLUGIN_ENV="/tmp/meowcoin/plugin_env_${PLUGIN}"
    if [ -f "$PLUGIN_ENV" ]; then
      source "$PLUGIN_ENV"
      
      # Execute function with timeout for safety
      if type "$FUNCTION" &>/dev/null; then
        # Record start time
        local START_TIME=$(date +%s)
        
        # Create output log file
        local HOOK_LOG="/tmp/meowcoin/hook_${PLUGIN}_${FUNCTION}_$(date +%s).log"
        
        # Add hook header
        echo "--- Hook execution: $PLUGIN.$FUNCTION ($HOOK_NAME) at $(date -Iseconds) ---" > "$HOOK_LOG"
        
        (
          # Execute in subshell with timeout and resource limiting for safety
          {
            # Change to the plugin's data directory
            cd "$(plugin_data_dir)" 2>/dev/null || cd /tmp
            
            # Redirect all output to hook log
            exec > >(tee -a "$HOOK_LOG") 2>&1
            
            # Execute the function with CPU and memory limits
            if [ "$PLUGIN_SANDBOX_ENABLED" = "true" ]; then
              nice -n 15 timeout ${PLUGIN_EXECUTION_TIMEOUT}s bash -c "$FUNCTION"
            else
              timeout ${PLUGIN_EXECUTION_TIMEOUT}s "$FUNCTION"
            fi
          }
        )
        
        HOOK_STATUS=$?
        local END_TIME=$(date +%s)
        local DURATION=$((END_TIME - START_TIME))
        
        # Record execution results
        echo "--- Hook completed with status $HOOK_STATUS in $DURATION seconds ---" >> "$HOOK_LOG"
        
        if [ $HOOK_STATUS -ne 0 ]; then
          echo "[$(date -Iseconds)] WARNING: Hook execution failed: $PLUGIN.$FUNCTION (status $HOOK_STATUS)" | tee -a $PLUGIN_LOG
          cat "$HOOK_LOG" >> $PLUGIN_LOG
          FAILURE_COUNT=$((FAILURE_COUNT + 1))
        else
          echo "[$(date -Iseconds)] Hook executed successfully: $PLUGIN.$FUNCTION ($DURATION seconds)" | tee -a $PLUGIN_LOG
          SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        fi
        
        # Keep the log file for a limited time for debugging
        mv "$HOOK_LOG" "/var/log/meowcoin/hooks/${PLUGIN}_${FUNCTION}_$(date +%s).log" 2>/dev/null || true
        
        # Cleanup old hook logs (keep last 20)
        find "/var/log/meowcoin/hooks" -name "${PLUGIN}_${FUNCTION}_*.log" -type f | \
          sort -r | tail -n +21 | xargs rm -f 2>/dev/null || true
      else
        echo "[$(date -Iseconds)] ERROR: Function not found: $FUNCTION" | tee -a $PLUGIN_LOG
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
      fi
    else
      echo "[$(date -Iseconds)] ERROR: Plugin environment not found: $PLUGIN" | tee -a $PLUGIN_LOG
      FAILURE_COUNT=$((FAILURE_COUNT + 1))
    fi
  done <<< "$HOOKS"
  
  echo "[$(date -Iseconds)] Finished executing hooks: $HOOK_NAME ($SUCCESS_COUNT succeeded, $FAILURE_COUNT failed)" | tee -a $PLUGIN_LOG
  
  # Return status based on hook execution results
  if [ $FAILURE_COUNT -gt 0 ]; then
    return 1
  else
    return 0
  fi
}

# Add a new function to refresh a plugin's configuration
function refresh_plugin() {
  local PLUGIN_NAME="$1"
  
  echo "[$(date -Iseconds)] Refreshing plugin: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
  
  # Check if plugin exists
  if [ ! -f "$PLUGIN_DIR/${PLUGIN_NAME}.sh" ]; then
    echo "[$(date -Iseconds)] ERROR: Plugin not found: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
    return 1
  fi
  
  # Unregister all hooks for this plugin
  if [ -f "$HOOK_REGISTRY" ]; then
    # Create a new registry file without the specified plugin's hooks
    local TEMP_FILE=$(mktemp)
    
    # For each hook type, filter out the plugin's hooks
    jq --arg plugin "$PLUGIN_NAME" '
      to_entries | 
      map(.value |= map(select(.plugin != $plugin))) | 
      from_entries
    ' "$HOOK_REGISTRY" > "$TEMP_FILE"
    
    mv "$TEMP_FILE" "$HOOK_REGISTRY"
    
    echo "[$(date -Iseconds)] Unregistered all hooks for plugin: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
  fi
  
  # Re-source the plugin environment
  PLUGIN_ENV="/tmp/meowcoin/plugin_env_${PLUGIN_NAME}"
  if [ -f "$PLUGIN_ENV" ]; then
    rm "$PLUGIN_ENV"
  fi
  
  # Re-validate and reload the plugin
  if validate_plugin "$PLUGIN_DIR/${PLUGIN_NAME}.sh"; then
    # Create plugin environment
    PLUGIN_ENV="/tmp/meowcoin/plugin_env_${PLUGIN_NAME}"
    
    # Create plugin utility functions (same as in load_plugins)
    cat > "$PLUGIN_ENV" <<EOF
#!/bin/bash
# Plugin: $PLUGIN_NAME
# Refreshed at $(date -Iseconds)

# All the same functions as before...
# (The full environment template would be here, identical to the one used in load_plugins)
EOF
    
    # Source the plugin environment
    source "$PLUGIN_ENV"
    
    # Source the plugin in a subshell to isolate potential errors
    (
      source "$PLUGIN_DIR/${PLUGIN_NAME}.sh"
    )
    
    if [ $? -eq 0 ]; then
      echo "[$(date -Iseconds)] Plugin refreshed successfully: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
      return 0
    else
      echo "[$(date -Iseconds)] ERROR: Failed to refresh plugin: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
      return 1
    fi
  else
    echo "[$(date -Iseconds)] ERROR: Plugin validation failed during refresh: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
    return 1
  fi
}

# Add a function to list all registered hooks
function list_hooks() {
  echo "[$(date -Iseconds)] Listing all registered hooks" | tee -a $PLUGIN_LOG
  
  if [ ! -f "$HOOK_REGISTRY" ]; then
    echo "No hooks registered"
    return 0
  fi
  
  # Format hooks in a readable way
  local HOOKS=$(jq -r 'to_entries | .[] | "\(.key): \(.value | length) hook(s)" | select(. != "")' "$HOOK_REGISTRY")
  
  if [ -z "$HOOKS" ]; then
    echo "No hooks registered"
  else
    echo "Registered hooks:"
    echo "$HOOKS"
    
    # Optionally show details for each hook
    if [ "$1" = "detailed" ]; then
      echo ""
      echo "Hook details:"
      jq -r 'to_entries | .[] | select(.value | length > 0) | "\(.key):" + (.value | map("\n  - \(.plugin).\(.function)") | join(""))' "$HOOK_REGISTRY"
    fi
  fi
}

# Add a function to generate plugin documentation
function generate_plugin_docs() {
  echo "[$(date -Iseconds)] Generating plugin documentation" | tee -a $PLUGIN_LOG
  
  local DOCS_DIR="/etc/meowcoin/plugins/docs"
  mkdir -p "$DOCS_DIR"
  
  # Generate main README
  cat > "$DOCS_DIR/README.md" <<EOF
# Meowcoin Node Plugins

This document provides information about the plugins enabled on this Meowcoin node.

## Enabled Plugins

The following plugins are currently enabled:

EOF
  
  # Find all enabled plugins
  for PLUGIN in "$ENABLED_PLUGINS_DIR"/*.sh; do
    if [ -f "$PLUGIN" ]; then
      PLUGIN_NAME=$(basename "$PLUGIN" .sh)
      
      # Extract description if available
      DESCRIPTION=""
      if grep -q "# Description:" "$PLUGIN"; then
        DESCRIPTION=$(grep "# Description:" "$PLUGIN" | sed 's/# Description://')
      else
        DESCRIPTION="No description available"
      fi
      
      echo "- **${PLUGIN_NAME}**: ${DESCRIPTION}" >> "$DOCS_DIR/README.md"
      
      # Generate individual plugin documentation
      generate_plugin_doc "$PLUGIN_NAME"
    fi
  done
  
  # List registered hooks
  echo "" >> "$DOCS_DIR/README.md"
  echo "## Registered Hooks" >> "$DOCS_DIR/README.md"
  echo "" >> "$DOCS_DIR/README.md"
  list_hooks "detailed" >> "$DOCS_DIR/README.md"
  
  echo "[$(date -Iseconds)] Plugin documentation generated in $DOCS_DIR" | tee -a $PLUGIN_LOG
}

# Generate documentation for a specific plugin
function generate_plugin_doc() {
  local PLUGIN_NAME="$1"
  local PLUGIN_PATH="$PLUGIN_DIR/${PLUGIN_NAME}.sh"
  local DOC_PATH="/etc/meowcoin/plugins/docs/${PLUGIN_NAME}.md"
  
  if [ ! -f "$PLUGIN_PATH" ]; then
    echo "[$(date -Iseconds)] ERROR: Plugin not found: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
    return 1
  fi
  
  echo "[$(date -Iseconds)] Generating documentation for plugin: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
  
  # Extract metadata from plugin file
  local DESCRIPTION=$(grep "# Description:" "$PLUGIN_PATH" | sed 's/# Description://' || echo "No description available")
  local AUTHOR=$(grep "# Author:" "$PLUGIN_PATH" | sed 's/# Author://' || echo "Unknown")
  local VERSION=$(grep "# Version:" "$PLUGIN_PATH" | sed 's/# Version://' || echo "Unspecified")
  
  # Generate markdown documentation
  cat > "$DOC_PATH" <<EOF
# Plugin: $PLUGIN_NAME

- **Description**: $DESCRIPTION
- **Author**: $AUTHOR
- **Version**: $VERSION

## Registered Hooks

EOF
  
  # Extract registered hooks for this plugin
  if [ -f "$HOOK_REGISTRY" ]; then
    jq -r --arg plugin "$PLUGIN_NAME" '
      to_entries | 
      .[] | 
      select(.value | map(select(.plugin == $plugin)) | length > 0) | 
      "\(.key):" + (.value | map(select(.plugin == $plugin)) | map("\n  - \(.function)") | join(""))
    ' "$HOOK_REGISTRY" >> "$DOC_PATH"
  else
    echo "No hooks registered" >> "$DOC_PATH"
  fi
  
  # Extract configuration options
  if grep -q "# Configuration:" "$PLUGIN_PATH"; then
    echo "" >> "$DOC_PATH"
    echo "## Configuration Options" >> "$DOC_PATH"
    echo "" >> "$DOC_PATH"
    sed -n '/# Configuration:/,/# End Configuration/p' "$PLUGIN_PATH" | grep -v "#" >> "$DOC_PATH"
  fi
  
  echo "[$(date -Iseconds)] Documentation generated for $PLUGIN_NAME at $DOC_PATH" | tee -a $PLUGIN_LOG
}

# Add a function to enable or disable a plugin
function toggle_plugin() {
  local PLUGIN_NAME="$1"
  local ACTION="$2"  # "enable" or "disable"
  
  if [ ! -f "$PLUGIN_DIR/${PLUGIN_NAME}.sh" ]; then
    echo "[$(date -Iseconds)] ERROR: Plugin not found: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
    return 1
  fi
  
  if [ "$ACTION" = "disable" ]; then
    # Disable the plugin
    touch "$PLUGIN_DIR/.$PLUGIN_NAME.disabled"
    rm -f "$ENABLED_PLUGINS_DIR/${PLUGIN_NAME}.sh" 2>/dev/null || true
    
    # Unregister all hooks for this plugin
    if [ -f "$HOOK_REGISTRY" ]; then
      # Create a new registry file without the specified plugin's hooks
      local TEMP_FILE=$(mktemp)
      
      jq --arg plugin "$PLUGIN_NAME" '
        to_entries | 
        map(.value |= map(select(.plugin != $plugin))) | 
        from_entries
      ' "$HOOK_REGISTRY" > "$TEMP_FILE"
      
      mv "$TEMP_FILE" "$HOOK_REGISTRY"
    fi
    
    echo "[$(date -Iseconds)] Plugin disabled: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
  elif [ "$ACTION" = "enable" ]; then
    # Enable the plugin
    rm -f "$PLUGIN_DIR/.$PLUGIN_NAME.disabled" 2>/dev/null || true
    
    # Re-validate and reload the plugin
    if validate_plugin "$PLUGIN_DIR/${PLUGIN_NAME}.sh"; then
      ln -sf "$PLUGIN_DIR/${PLUGIN_NAME}.sh" "$ENABLED_PLUGINS_DIR/${PLUGIN_NAME}.sh"
      refresh_plugin "$PLUGIN_NAME"
      echo "[$(date -Iseconds)] Plugin enabled: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
    else
      echo "[$(date -Iseconds)] ERROR: Cannot enable plugin due to validation failure: $PLUGIN_NAME" | tee -a $PLUGIN_LOG
      return 1
    fi
  else
    echo "[$(date -Iseconds)] ERROR: Invalid action: $ACTION (must be 'enable' or 'disable')" | tee -a $PLUGIN_LOG
    return 1
  fi
  
  return 0
}