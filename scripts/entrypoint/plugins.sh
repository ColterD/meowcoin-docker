#!/bin/bash
set -e

# Enhanced plugin system for Meowcoin Docker
PLUGIN_DIR="/etc/meowcoin/plugins"
ENABLED_PLUGINS_DIR="/etc/meowcoin/plugins/enabled"
DISABLED_PLUGINS_DIR="/etc/meowcoin/plugins/disabled"
HOOK_REGISTRY="/tmp/plugin_hooks.json"
PLUGIN_LOG="/var/log/meowcoin/plugins.log"
PLUGIN_SANDBOX_ENABLED=true
PLUGIN_EXECUTION_TIMEOUT=30
PLUGIN_MEMORY_LIMIT="50M"
PLUGIN_CPU_LIMIT="50"
TRACE_ID="${TRACE_ID:-$(date +%s)-$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8)}"
HOOK_ARGS="$@"

# Helper function for logging
log() {
  echo "[$TRACE_ID][$(date -Iseconds)] $1" | tee -a $PLUGIN_LOG
}

# Error handling function for plugin errors
handle_plugin_error() {
  local PLUGIN_NAME="$1"
  local EXIT_CODE="$2"
  local ERROR_MESSAGE="$3"
  
  log "ERROR [$PLUGIN_NAME]: $ERROR_MESSAGE (exit code: $EXIT_CODE)"
  
  # Send alert if monitoring is configured
  if [ -x /usr/local/bin/monitoring/send-alert.sh ]; then
    /usr/local/bin/monitoring/send-alert.sh "Plugin error: $PLUGIN_NAME - $ERROR_MESSAGE" "plugin_error" "warning"
  fi
  
  # Record error in plugin registry
  if [ -f "$PLUGIN_DIR/.plugin_errors.json" ]; then
    local TEMP_FILE=$(mktemp)
    jq --arg plugin "$PLUGIN_NAME" \
       --arg time "$(date -Iseconds)" \
       --arg error "$ERROR_MESSAGE" \
       --arg code "$EXIT_CODE" \
       '.[$plugin] = {"last_error_time": $time, "error": $error, "exit_code": $code, "count": (if .[$plugin].count then .[$plugin].count + 1 else 1 end)}' \
       "$PLUGIN_DIR/.plugin_errors.json" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$PLUGIN_DIR/.plugin_errors.json"
  else
    echo "{\"$PLUGIN_NAME\": {\"last_error_time\": \"$(date -Iseconds)\", \"error\": \"$ERROR_MESSAGE\", \"exit_code\": \"$EXIT_CODE\", \"count\": 1}}" > "$PLUGIN_DIR/.plugin_errors.json"
  fi
  
  # If a plugin has too many errors, consider disabling it
  if [ -f "$PLUGIN_DIR/.plugin_errors.json" ]; then
    local ERROR_COUNT=$(jq -r ".[\"$PLUGIN_NAME\"].count // 0" "$PLUGIN_DIR/.plugin_errors.json")
    if [ $ERROR_COUNT -gt 5 ]; then
      log "Plugin $PLUGIN_NAME has failed $ERROR_COUNT times, disabling"
      disable_plugin "$PLUGIN_NAME"
    fi
  fi
}

# Initialize the plugin system with better resource isolation
function init_plugin_system() {
  mkdir -p $(dirname $PLUGIN_LOG)
  touch $PLUGIN_LOG
  chown meowcoin:meowcoin $PLUGIN_LOG
  
  log "Initializing plugin system"
  
  # Skip if plugins not enabled
  if [ "${ENABLE_PLUGINS:-false}" != "true" ]; then
    log "Plugins disabled, skipping"
    return 0
  fi
  
  # Check if plugin directory exists
  if [ ! -d "$PLUGIN_DIR" ]; then
    log "Plugin directory not found: $PLUGIN_DIR"
    mkdir -p "$PLUGIN_DIR"
    log "Created empty plugin directory"
  fi
  
  # Create enabled plugins directory
  mkdir -p "$ENABLED_PLUGINS_DIR"
  mkdir -p "$DISABLED_PLUGINS_DIR"
  
  # Initialize hook registry if it doesn't exist
  if [ ! -f "$HOOK_REGISTRY" ]; then
    echo "{}" > $HOOK_REGISTRY
  fi
  
  # Create plugin sandbox directories with proper permissions
  if [ "$PLUGIN_SANDBOX_ENABLED" = "true" ]; then
    mkdir -p /tmp/meowcoin/plugin_sandbox
    chmod 750 /tmp/meowcoin/plugin_sandbox
    mkdir -p /var/log/meowcoin/hooks
    chmod 750 /var/log/meowcoin/hooks
  fi
  
  # Create plugin data directory
  mkdir -p "$PLUGIN_DIR/data"
  chmod 750 "$PLUGIN_DIR/data"
  
  # Create plugin config directory
  mkdir -p "$PLUGIN_DIR/config"
  chmod 750 "$PLUGIN_DIR/config"
  
  # Load all plugins
  load_plugins
  
  log "Plugin system initialized with $(jq -r 'keys | length' $HOOK_REGISTRY) hooks"
}

# Setup cgroup v2 for plugin resource isolation
function setup_plugin_cgroup() {
  local PLUGIN_NAME="$1"
  
  if [ -d "/sys/fs/cgroup" ]; then
    log "Setting up cgroup for plugin: $PLUGIN_NAME"
    
    # Create plugin cgroup
    mkdir -p /sys/fs/cgroup/meowcoin-plugins/$PLUGIN_NAME 2>/dev/null || true
    
    if [ -d "/sys/fs/cgroup/meowcoin-plugins/$PLUGIN_NAME" ]; then
      # Set memory limit with buffer protection
      if [ -f "/sys/fs/cgroup/meowcoin-plugins/$PLUGIN_NAME/memory.max" ]; then
        echo "${PLUGIN_MEMORY_LIMIT}" > /sys/fs/cgroup/meowcoin-plugins/$PLUGIN_NAME/memory.max 2>/dev/null || true
        # Disable swap
        if [ -f "/sys/fs/cgroup/meowcoin-plugins/$PLUGIN_NAME/memory.swap.max" ]; then
          echo "0" > /sys/fs/cgroup/meowcoin-plugins/$PLUGIN_NAME/memory.swap.max 2>/dev/null || true
        fi
      fi
      
      # Set CPU limits with more granularity
      if [ -f "/sys/fs/cgroup/meowcoin-plugins/$PLUGIN_NAME/cpu.max" ]; then
        # Format: $quota $period
        echo "$PLUGIN_CPU_LIMIT 100000" > /sys/fs/cgroup/meowcoin-plugins/$PLUGIN_NAME/cpu.max 2>/dev/null || true
      fi
      
      # Set I/O limits if supported
      if [ -f "/sys/fs/cgroup/meowcoin-plugins/$PLUGIN_NAME/io.max" ]; then
        echo "250" > /sys/fs/cgroup/meowcoin-plugins/$PLUGIN_NAME/io.max 2>/dev/null || true
      fi
      
      log "Cgroup configured for plugin: $PLUGIN_NAME"
      return 0
    else
      log "Failed to create cgroup for plugin: $PLUGIN_NAME"
    fi
  fi
  
  log "Cgroups not available or not mounted"
  return 1
}

# Enhanced plugin validation with security checks
function validate_plugin() {
  local PLUGIN_PATH="$1"
  local PLUGIN_NAME=$(basename "$PLUGIN_PATH" .sh)
  
  log "Validating plugin: $PLUGIN_NAME"
  
  # Check if plugin is specifically disabled
  if [ -f "$PLUGIN_DIR/.$PLUGIN_NAME.disabled" ] || [ -f "$DISABLED_PLUGINS_DIR/$PLUGIN_NAME.sh" ]; then
    log "Plugin is explicitly disabled: $PLUGIN_NAME"
    return 1
  fi
  
  # Basic file checks
  if [ ! -f "$PLUGIN_PATH" ]; then
    log "Plugin file not found: $PLUGIN_PATH"
    return 1
  fi
  
  if [ ! -r "$PLUGIN_PATH" ]; then
    log "Plugin file not readable: $PLUGIN_PATH"
    return 1
  fi
  
  # Check file size
  local FILE_SIZE=$(wc -c < "$PLUGIN_PATH")
  if [ $FILE_SIZE -gt 100000 ]; then
    log "Plugin file size exceeds 100KB: $PLUGIN_PATH ($FILE_SIZE bytes)"
    return 1
  fi
  
  # Check for suspicious commands with more thorough pattern matching
  if grep -qE '\b(curl|wget|nc|ncat|telnet|ssh|scp|sftp|ftp|netcat|nc)\b' "$PLUGIN_PATH"; then
    log "Plugin contains networking commands, potential security risk"
    return 1
  fi
  
  # Check for suspicious shell escapes and command execution
  if grep -qE '\beval\b|\bexec\b|\bsystem\b|\bpopen\b|\`.*\`|\$\(.*\)' "$PLUGIN_PATH"; then
    log "Plugin contains potentially unsafe evaluation"
    return 1
  fi
  
  # Check for excessive privileges
  if grep -qE '\bsudo\b|\bsu\s|\bchroot\b|\bsetuid\b|\bsetgid\b' "$PLUGIN_PATH"; then
    log "Plugin attempts to escalate privileges"
    return 1
  fi
  
  # Check for system file access outside the allowed paths with more precise pattern matching
  if grep -qE '/(etc|var|root|boot|usr|lib|bin|sbin)/' "$PLUGIN_PATH" | grep -vE '/etc/meowcoin|/var/log/meowcoin|/home/meowcoin'; then
    log "Plugin attempts to access restricted system files"
    return 1
  fi
  
  # Check for infinite loops and forks
  if grep -qE 'while\s+:|while\s+true|until\s+false|for\(\(;;\)\)|fork\(\)|\&\s*$' "$PLUGIN_PATH"; then
    log "Plugin contains potential infinite loops or forks"
    return 1
  fi
  
  # Check for network socket operations
  if grep -qE 'socket\(|bind\(|listen\(|accept\(|connect\(' "$PLUGIN_PATH"; then
    log "Plugin contains network socket operations"
    return 1
  }
  
  # Check for risky file operations
  if grep -qE '\bchmod\s+777|\bchmod\s+a+|\bchmod\s+o+w' "$PLUGIN_PATH"; then
    log "Plugin contains risky file permission changes"
    return 1
  }
  
  # Check plugin syntax
  if ! bash -n "$PLUGIN_PATH" >/dev/null 2>&1; then
    log "Plugin contains syntax errors: $PLUGIN_NAME"
    return 1
  fi
  
  log "Plugin validation passed: $PLUGIN_NAME"
  return 0
}

# Load all plugins from the plugin directory with improved error handling
function load_plugins() {
  log "Loading plugins from $PLUGIN_DIR"
  
  # Count plugins
  PLUGIN_COUNT=$(find "$PLUGIN_DIR" -maxdepth 1 -name "*.sh" -type f | wc -l)
  ENABLED_COUNT=0
  FAILED_COUNT=0
  
  log "Found $PLUGIN_COUNT plugin(s)"
  
  if [ $PLUGIN_COUNT -eq 0 ]; then
    return 0
  fi
  
  # Source each plugin
  for PLUGIN in "$PLUGIN_DIR"/*.sh; do
    if [ -f "$PLUGIN" ]; then
      PLUGIN_NAME=$(basename "$PLUGIN" .sh)
      log "Processing plugin: $PLUGIN_NAME"
      
      # Check if plugin has execute permission
      if [ ! -x "$PLUGIN" ]; then
        log "Adding execute permission to plugin"
        chmod +x "$PLUGIN"
      fi
      
      # Validate plugin for security
      if ! validate_plugin "$PLUGIN"; then
        log "Skipping plugin due to security concerns: $PLUGIN_NAME"
        # Mark the plugin as disabled and move to disabled directory
        touch "$PLUGIN_DIR/.$PLUGIN_NAME.disabled"
        cp "$PLUGIN" "$DISABLED_PLUGINS_DIR/${PLUGIN_NAME}.sh"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        continue
      fi
      
      # Setup resource isolation with cgroups if available
      setup_plugin_cgroup "$PLUGIN_NAME"
      
      # Create plugin data directory with proper permissions
      mkdir -p "$PLUGIN_DIR/data/$PLUGIN_NAME"
      chmod 750 "$PLUGIN_DIR/data/$PLUGIN_NAME"
      
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
    startup|shutdown|post_sync|backup_pre|backup_post|backup_error|health_check|periodic)
      # Valid hook name
      ;;
    *)
      plugin_log "Tried to register invalid hook: \$HOOK_NAME" "ERROR"
      return 1
      ;;
  esac
  
  # Validate function name
  if [[ ! "\$FUNCTION_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
    plugin_log "Tried to register invalid function name: \$FUNCTION_NAME" "ERROR"
    return 1
  fi
  
  # Check if function exists
  if ! type "\$FUNCTION_NAME" &>/dev/null; then
    plugin_log "Tried to register non-existent function: \$FUNCTION_NAME" "ERROR"
    return 1
  fi
  
  # Add hook to registry
  local CURRENT_HOOKS=\$(cat $HOOK_REGISTRY)
  local NEW_HOOKS=\$(echo \$CURRENT_HOOKS | jq --arg hook "\$HOOK_NAME" --arg func "\$FUNCTION_NAME" --arg plugin "$PLUGIN_NAME" '. + {(\$hook): (.[(\$hook)] // []) + [{"plugin": \$plugin, "function": \$func}]}')
  echo \$NEW_HOOKS > $HOOK_REGISTRY
  
  plugin_log "Registered hook: \$HOOK_NAME -> \$FUNCTION_NAME"
  return 0
}

# Log function for plugins with sanitized output
function plugin_log() {
  # Sanitize input to prevent log injection
  local SANITIZED=\$(echo "\$1" | sed 's/[\\\`\$]//g')
  local LEVEL="\${2:-INFO}"
  local TIMESTAMP=\$(date -Iseconds)
  local TRACE_ID="${TRACE_ID}"
  
  echo "[\$TRACE_ID][\$TIMESTAMP] [$PLUGIN_NAME] [\$LEVEL] \$SANITIZED" >> $PLUGIN_LOG
  
  # Also output to stderr for critical issues
  if [ "\$LEVEL" = "ERROR" ] || [ "\$LEVEL" = "CRITICAL" ]; then
    echo "[\$TIMESTAMP] [$PLUGIN_NAME] [\$LEVEL] \$SANITIZED" >&2
  fi
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

# Get plugin config directory (safe)
function plugin_config_dir() {
  local CONFIG_DIR="$PLUGIN_DIR/config/$PLUGIN_NAME"
  mkdir -p "\$CONFIG_DIR"
  chmod 750 "\$CONFIG_DIR"
  echo "\$CONFIG_DIR"
}

# Get meowcoin data directory (safe)
function meowcoin_data_dir() {
  echo "/home/meowcoin/.meowcoin"
}

# Get meowcoin config (safe)
function meowcoin_config() {
  echo "/home/meowcoin/.meowcoin/meowcoin.conf"
}

# Send RPC command with error handling and timeouts
function meowcoin_rpc() {
  local CMD="\$1"
  shift
  
  # Validate command for basic safety
  if [[ ! "\$CMD" =~ ^[a-zA-Z0-9_]+$ ]]; then
    plugin_log "Invalid RPC command: \$CMD" "ERROR"
    return 1
  fi
  
  # Execute with timeout and capture both stdout and stderr
  local TMPFILE=\$(mktemp)
  local RESULT
  
  if timeout 10s meowcoin-cli -conf="\$(meowcoin_config)" "\$CMD" "\$@" > "\$TMPFILE" 2>&1; then
    RESULT=\$(cat "\$TMPFILE")
    rm -f "\$TMPFILE"
    echo "\$RESULT"
    return 0
  else
    local STATUS=\$?
    RESULT=\$(cat "\$TMPFILE")
    rm -f "\$TMPFILE"
    
    plugin_log "RPC command failed: \$CMD (status \$STATUS): \$RESULT" "ERROR"
    return \$STATUS
  fi
}

# Execute a command with timeout and resource limits
function plugin_exec() {
  # Create sandbox directory
  local SANDBOX_DIR="/tmp/meowcoin/plugin_sandbox/${PLUGIN_NAME}_\$(date +%s)"
  mkdir -p "\$SANDBOX_DIR"
  cd "\$SANDBOX_DIR"
  
  # Create log file for command output
  local CMD_LOG="\$SANDBOX_DIR/cmd.log"
  
  # Prepare command with proper quoting
  local CMD_STR="\$@"
  
  plugin_log "Executing command in sandbox: \$CMD_STR"
  
  # Prepare for cgroup usage if available
  local USE_CGROUP=false
  if [ -d "/sys/fs/cgroup/meowcoin-plugins/$PLUGIN_NAME" ]; then
    USE_CGROUP=true
  fi
  
  # Create temporary script that will be executed
  cat > "\$SANDBOX_DIR/exec.sh" <<SCRIPT
#!/bin/bash
set -e
cd "\$SANDBOX_DIR"
echo \$\$ > "\$SANDBOX_DIR/cmd.pid"
exec "\$@"
SCRIPT
  
  chmod +x "\$SANDBOX_DIR/exec.sh"
  
  # Execute with resource limits
  local EXIT_CODE=0
  
  if [ "\$USE_CGROUP" = "true" ]; then
    # Using cgroups for resource control
    echo \$\$ > /sys/fs/cgroup/meowcoin-plugins/$PLUGIN_NAME/cgroup.procs
    timeout ${PLUGIN_EXECUTION_TIMEOUT}s "\$SANDBOX_DIR/exec.sh" "\$@" > "\$CMD_LOG" 2>&1
    EXIT_CODE=\$?
    # Try to remove from cgroup
    echo \$\$ > /sys/fs/cgroup/cgroup.procs
  else
    # Fallback without cgroups
    timeout ${PLUGIN_EXECUTION_TIMEOUT}s nice -n 15 "\$SANDBOX_DIR/exec.sh" "\$@" > "\$CMD_LOG" 2>&1
    EXIT_CODE=\$?
  fi
  
  # Get command output
  local OUTPUT=\$(cat "\$CMD_LOG")
  
  # Log execution result
  if [ \$EXIT_CODE -eq 0 ]; then
    plugin_log "Command executed successfully"
  elif [ \$EXIT_CODE -eq 124 ]; then
    plugin_log "Command timed out after ${PLUGIN_EXECUTION_TIMEOUT} seconds" "ERROR"
  else
    plugin_log "Command failed with exit code \$EXIT_CODE" "ERROR"
    # Log the first few lines of output for debugging
    plugin_log "Command output (first 5 lines): \$(head -n 5 "\$CMD_LOG")" "ERROR"
  fi
  
  # Clean up sandbox (with secure deletion for sensitive data)
  find "\$SANDBOX_DIR" -type f -exec shred -u {} \; 2>/dev/null || true
  rm -rf "\$SANDBOX_DIR"
  
  # Return the original exit code
  return \$EXIT_CODE
}

# Get plugin configuration value with validation
function plugin_config_get() {
  local KEY="\$1"
  local DEFAULT="\$2"
  local CONFIG_FILE="$PLUGIN_DIR/config/$PLUGIN_NAME/$PLUGIN_NAME.conf"
  
  # Validate key
  if [[ ! "\$KEY" =~ ^[a-zA-Z0-9_\.]+$ ]]; then
    plugin_log "Invalid configuration key: \$KEY" "ERROR"
    return 1
  fi
  
  if [ -f "\$CONFIG_FILE" ] && grep -q "^\$KEY=" "\$CONFIG_FILE"; then
    grep "^\$KEY=" "\$CONFIG_FILE" | sed "s/^\$KEY=//"
  else
    echo "\$DEFAULT"
  fi
}

# Set plugin configuration value with validation
function plugin_config_set() {
  local KEY="\$1"
  local VALUE="\$2"
  local CONFIG_FILE="$PLUGIN_DIR/config/$PLUGIN_NAME/$PLUGIN_NAME.conf"
  
  # Validate key
  if [[ ! "\$KEY" =~ ^[a-zA-Z0-9_\.]+$ ]]; then
    plugin_log "Invalid configuration key: \$KEY" "ERROR"
    return 1
  fi
  
  # Ensure config directory exists
  mkdir -p "\$(dirname \$CONFIG_FILE)"
  
  if [ -f "\$CONFIG_FILE" ] && grep -q "^\$KEY=" "\$CONFIG_FILE"; then
    sed -i "s/^\$KEY=.*$/\$KEY=\$VALUE/" "\$CONFIG_FILE"
  else
    echo "\$KEY=\$VALUE" >> "\$CONFIG_FILE"
  fi
}

# Store plugin state data (for persistence)
function plugin_state_save() {
  local KEY="\$1"
  local VALUE="\$2"
  local STATE_FILE="\$(plugin_data_dir)/.state.json"
  
  # Validate key
  if [[ ! "\$KEY" =~ ^[a-zA-Z0-9_\.]+$ ]]; then
    plugin_log "Invalid state key: \$KEY" "ERROR"
    return 1
  fi
  
  # Initialize state file if doesn't exist
  if [ ! -f "\$STATE_FILE" ]; then
    echo "{}" > "\$STATE_FILE"
    chmod 640 "\$STATE_FILE"
  fi
  
  # Update state
  local TEMP_FILE=\$(mktemp)
  jq --arg key "\$KEY" --arg value "\$VALUE" '.[\$key] = \$value' "\$STATE_FILE" > "\$TEMP_FILE"
  mv "\$TEMP_FILE" "\$STATE_FILE"
}

# Retrieve plugin state data
function plugin_state_get() {
  local KEY="\$1"
  local DEFAULT="\$2"
  local STATE_FILE="\$(plugin_data_dir)/.state.json"
  
  # Validate key
  if [[ ! "\$KEY" =~ ^[a-zA-Z0-9_\.]+$ ]]; then
    plugin_log "Invalid state key: \$KEY" "ERROR"
    return 1
  fi
  
  if [ -f "\$STATE_FILE" ]; then
    local VALUE=\$(jq -r --arg key "\$KEY" '.[\$key] // "null"' "\$STATE_FILE")
    if [ "\$VALUE" = "null" ]; then
      echo "\$DEFAULT"
    else
      echo "\$VALUE"
    fi
  else
    echo "\$DEFAULT"
  fi
}

# Get a unique ID for tracking operations
function plugin_get_trace_id() {
  echo "$TRACE_ID"
}

# Get hook arguments
function plugin_get_hook_args() {
  echo "$HOOK_ARGS"
}

# Check if plugin has necessary resources
function plugin_check_resources() {
  local RESOURCE="\$1"
  
  case "\$RESOURCE" in
    "aws")
      if command -v aws >/dev/null 2>&1; then
        return 0
      else
        plugin_log "Resource 'aws' not available" "WARNING"
        return 1
      fi
      ;;
    "jq")
      if command -v jq >/dev/null 2>&1; then
        return 0
      else
        plugin_log "Resource 'jq' not available" "WARNING"
        return 1
      fi
      ;;
    "curl")
      if command -v curl >/dev/null 2>&1 && plugin_config_get "allow_network" "false" = "true"; then
        return 0
      else
        plugin_log "Resource 'curl' not available or network access not allowed" "WARNING"
        return 1
      fi
      ;;
    *)
      plugin_log "Unknown resource: \$RESOURCE" "WARNING"
      return 1
      ;;
  esac
}

# Send plugin metrics to monitoring system
function plugin_send_metric() {
  local METRIC_NAME="\$1"
  local METRIC_VALUE="\$2"
  local METRIC_TYPE="\${3:-gauge}"
  
  # Validate metric name
  if [[ ! "\$METRIC_NAME" =~ ^[a-zA-Z0-9_\.]+$ ]]; then
    plugin_log "Invalid metric name: \$METRIC_NAME" "ERROR"
    return 1
  fi
  
  # Prepare full metric name with plugin prefix
  local FULL_METRIC="plugin_${PLUGIN_NAME}_\${METRIC_NAME}"
  
  # Store metric in metrics directory
  local METRICS_DIR="/var/lib/meowcoin/metrics"
  if [ -d "\$METRICS_DIR" ]; then
    echo "\$(date +%s) \$METRIC_VALUE" >> "\$METRICS_DIR/\$FULL_METRIC.current"
    
    # Keep metrics file from growing too large
    if [ -f "\$METRICS_DIR/\$FULL_METRIC.current" ] && [ \$(wc -l < "\$METRICS_DIR/\$FULL_METRIC.current") -gt 1000 ]; then
      tail -n 1000 "\$METRICS_DIR/\$FULL_METRIC.current" > "\$METRICS_DIR/\$FULL_METRIC.current.tmp"
      mv "\$METRICS_DIR/\$FULL_METRIC.current.tmp" "\$METRICS_DIR/\$FULL_METRIC.current"
    fi
    
    plugin_log "Metric sent: \$FULL_METRIC = \$METRIC_VALUE (\$METRIC_TYPE)"
    return 0
  else
    plugin_log "Metrics directory not available" "WARNING"
    return 1
  fi
}
EOF
      
      # Source the plugin environment
      source "$PLUGIN_ENV"
      
      # Source the plugin with error handling
      (
        # Execute in subshell for isolation
        source "$PLUGIN"
        plugin_log "Plugin loaded successfully"
      )
      
      if [ $? -eq 0 ]; then
        log "Plugin loaded: $PLUGIN_NAME"
        ENABLED_COUNT=$((ENABLED_COUNT + 1))
      else
        log "Failed to load plugin: $PLUGIN_NAME"
        handle_plugin_error "$PLUGIN_NAME" "$?" "Failed to load plugin"
        FAILED_COUNT=$((FAILED_COUNT + 1))
      fi
    fi
  done
  
  log "Plugin loading completed: $ENABLED_COUNT enabled, $FAILED_COUNT failed"
}

# Execute hooks by name with improved error handling and resource control
function execute_hooks() {
  local HOOK_NAME="$1"
  shift
  
  # Skip if plugins not enabled
  if [ "${ENABLE_PLUGINS:-false}" != "true" ]; then
    return 0
  fi
  
  log "Executing hooks: $HOOK_NAME"
  
  # Check if hook registry exists
  if [ ! -f "$HOOK_REGISTRY" ]; then
    log "Hook registry not found: $HOOK_REGISTRY"
    return 1
  fi
  
  # Get hooks for this hook name
  local HOOKS=$(cat $HOOK_REGISTRY | jq -r --arg hook "$HOOK_NAME" '.[$hook] // [] | .[]')
  
  if [ -z "$HOOKS" ]; then
    log "No hooks registered for: $HOOK_NAME"
    return 0
  fi
  
  # Count successful and failed hooks
  local SUCCESS_COUNT=0
  local FAILURE_COUNT=0
  
  # Execute each hook with proper monitoring and resource controls
  while IFS= read -r HOOK; do
    local PLUGIN=$(echo $HOOK | jq -r '.plugin')
    local FUNCTION=$(echo $HOOK | jq -r '.function')
    
    log "Executing hook: $HOOK_NAME -> $PLUGIN.$FUNCTION"
    
    # Check if plugin is disabled
    if [ -f "$PLUGIN_DIR/.$PLUGIN.disabled" ] || [ -f "$DISABLED_PLUGINS_DIR/$PLUGIN.sh" ]; then
      log "Skipping disabled plugin: $PLUGIN"
      continue
    fi
    
    # Source plugin environment
    PLUGIN_ENV="/tmp/meowcoin/plugin_env_${PLUGIN}"
    if [ -f "$PLUGIN_ENV" ]; then
      source "$PLUGIN_ENV"
      
      # Execute function with resource restrictions and monitoring
      if type "$FUNCTION" &>/dev/null; then
        # Record start time
        local START_TIME=$(date +%s)
        
        # Create sandbox directory
        local SANDBOX_DIR="/tmp/meowcoin/plugin_sandbox/${PLUGIN}_${FUNCTION}_$(date +%s)"
        mkdir -p "$SANDBOX_DIR"
        
        # Create output log file
        local HOOK_LOG="/var/log/meowcoin/hooks/${PLUGIN}_${FUNCTION}_$(date +%s).log"
        mkdir -p "$(dirname "$HOOK_LOG")"
        
        # Add hook header
        echo "--- Hook execution: $PLUGIN.$FUNCTION ($HOOK_NAME) at $(date -Iseconds) ---" > "$HOOK_LOG"
        echo "Trace ID: $TRACE_ID" >> "$HOOK_LOG"
        
        # Create temporary script to execute hook with resource limitations
        cat > "$SANDBOX_DIR/exec_hook.sh" <<EOF
#!/bin/bash
set -e
cd "$(plugin_data_dir)" 2>/dev/null || cd /tmp
exec $FUNCTION
EOF
        chmod +x "$SANDBOX_DIR/exec_hook.sh"
        
        # Configure cgroup if available
        local USING_CGROUPS=false
        if [ -d "/sys/fs/cgroup/meowcoin-plugins/$PLUGIN" ]; then
          USING_CGROUPS=true
        fi
        
        # Execute hook with proper isolation and resource limits
        (
          if [ "$USING_CGROUPS" = "true" ]; then
            echo $$ > /sys/fs/cgroup/meowcoin-plugins/$PLUGIN/cgroup.procs 2>/dev/null || true
          fi
          
          # Change to plugin data directory
          cd "$(plugin_data_dir)" 2>/dev/null || cd /tmp
          
          # Redirect all output to hook log
          exec >> "$HOOK_LOG" 2>&1
          
          echo "Starting hook execution at $(date -Iseconds)"
          
          if [ "$PLUGIN_SANDBOX_ENABLED" = "true" ]; then
            timeout ${PLUGIN_EXECUTION_TIMEOUT}s "$SANDBOX_DIR/exec_hook.sh"
          else
            timeout ${PLUGIN_EXECUTION_TIMEOUT}s bash -c "$FUNCTION"
          fi
          
          echo "Hook execution completed successfully at $(date -Iseconds)"
        )
        
        HOOK_STATUS=$?
        local END_TIME=$(date +%s)
        local DURATION=$((END_TIME - START_TIME))
        
        # Record execution results
        echo "--- Hook completed with status $HOOK_STATUS in $DURATION seconds ---" >> "$HOOK_LOG"
        
        # Clean up cgroup if used
        if [ "$USING_CGROUPS" = "true" ]; then
          # Move process back to root cgroup
          echo $$ > /sys/fs/cgroup/cgroup.procs 2>/dev/null || true
        fi
        
        # Clean up sandbox with secure deletion
        find "$SANDBOX_DIR" -type f -exec shred -u {} \; 2>/dev/null || true
        rm -rf "$SANDBOX_DIR"
        
        if [ $HOOK_STATUS -ne 0 ]; then
          if [ $HOOK_STATUS -eq 124 ]; then
            log "Hook execution timed out after ${PLUGIN_EXECUTION_TIMEOUT}s: $handle_plugin_error "$PLUGIN" "$HOOK_STATUS" "Hook execution failed"
        fi
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
      else
        log "Hook executed successfully: $PLUGIN.$FUNCTION ($DURATION seconds)"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        
        # Record successful execution
        if [ -f "$PLUGIN_DIR/.plugin_success.json" ]; then
          local TEMP_FILE=$(mktemp)
          jq --arg plugin "$PLUGIN" \
             --arg func "$FUNCTION" \
             --arg time "$(date -Iseconds)" \
             --arg duration "$DURATION" \
             '.[$plugin][$func] = {"last_success": $time, "duration": $duration}' \
             "$PLUGIN_DIR/.plugin_success.json" > "$TEMP_FILE"
          mv "$TEMP_FILE" "$PLUGIN_DIR/.plugin_success.json"
        else
          echo "{\"$PLUGIN\": {\"$FUNCTION\": {\"last_success\": \"$(date -Iseconds)\", \"duration\": \"$DURATION\"}}}" > "$PLUGIN_DIR/.plugin_success.json"
        fi
      fi
      
      # Keep the log file for a limited time for debugging (last 20 per hook)
      find "/var/log/meowcoin/hooks" -name "${PLUGIN}_${FUNCTION}_*.log" -type f | \
        sort -r | tail -n +21 | xargs rm -f 2>/dev/null || true
    else
      log "Function not found: $FUNCTION"
      handle_plugin_error "$PLUGIN" "404" "Function not found: $FUNCTION"
      FAILURE_COUNT=$((FAILURE_COUNT + 1))
    fi
  else
    log "Plugin environment not found: $PLUGIN"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
  fi
done <<< "$HOOKS"
  
  log "Finished executing hooks: $HOOK_NAME ($SUCCESS_COUNT succeeded, $FAILURE_COUNT failed)"
  
  # Return status based on hook execution results
  if [ $FAILURE_COUNT -gt 0 ]; then
    return 1
  else
    return 0
  fi
}

# Function to disable a plugin
function disable_plugin() {
  local PLUGIN_NAME="$1"
  
  if [ ! -f "$PLUGIN_DIR/${PLUGIN_NAME}.sh" ] && [ ! -f "$ENABLED_PLUGINS_DIR/${PLUGIN_NAME}.sh" ]; then
    log "Plugin not found: $PLUGIN_NAME"
    return 1
  fi
  
  log "Disabling plugin: $PLUGIN_NAME"
  
  # Create disabled marker
  touch "$PLUGIN_DIR/.$PLUGIN_NAME.disabled"
  
  # Move to disabled directory
  if [ -f "$PLUGIN_DIR/${PLUGIN_NAME}.sh" ]; then
    cp "$PLUGIN_DIR/${PLUGIN_NAME}.sh" "$DISABLED_PLUGINS_DIR/${PLUGIN_NAME}.sh"
  elif [ -f "$ENABLED_PLUGINS_DIR/${PLUGIN_NAME}.sh" ]; then
    cp "$ENABLED_PLUGINS_DIR/${PLUGIN_NAME}.sh" "$DISABLED_PLUGINS_DIR/${PLUGIN_NAME}.sh"
  fi
  
  # Remove from enabled directory
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
  
  log "Plugin disabled: $PLUGIN_NAME"
  return 0
}

# Main dispatcher
if [ "$1" = "init" ]; then
  init_plugin_system
elif [ "$1" = "execute_hooks" ]; then
  shift
  execute_hooks "$@"
elif [ "$1" = "list" ]; then
  list_plugins
elif [ "$1" = "enable" ]; then
  enable_plugin "$2"
elif [ "$1" = "disable" ]; then
  disable_plugin "$2"
elif [ "$1" = "refresh" ]; then
  refresh_plugin "$2"
elif [ "$1" = "docs" ]; then
  generate_plugin_docs
elif [ "$1" = "metrics" ]; then
  get_plugin_metrics
else
  # Default action
  echo "Usage: $0 {init|execute_hooks <hook_name>|list|enable <plugin>|disable <plugin>|refresh <plugin>|docs|metrics}"
  exit 1
fi