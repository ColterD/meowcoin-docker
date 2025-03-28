#!/bin/bash
# Plugin system for Meowcoin Docker
# Provides plugin loading, validation, and hook execution

# Source common utilities if not already loaded
[[ -z "$UTILS_LOADED" ]] && source "$(dirname "$0")/utils.sh"

# Define plugin system constants
PLUGIN_DIR="${PLUGIN_DIR:-/etc/meowcoin/plugins}"
PLUGIN_DATA_DIR="/var/lib/meowcoin/plugin-data"
PLUGIN_LOG_DIR="/var/log/meowcoin/plugins"
PLUGIN_ENABLED_DIR="/etc/meowcoin/plugins/enabled"
PLUGIN_STATE_DIR="/var/lib/meowcoin/plugin-state"
PLUGIN_HOOKS=(startup shutdown health_check backup_pre backup_post backup_error post_sync periodic)

# Initialize plugin system
function plugins_init() {
    log_info "Initializing plugin system"
    
    # Check if plugins are enabled
    if [[ "${ENABLE_PLUGINS:-false}" != "true" ]]; then
        log_info "Plugin system is disabled"
        return 0
    fi
    
    # Create plugin directories
    mkdir -p "$PLUGIN_DIR" "$PLUGIN_DATA_DIR" "$PLUGIN_LOG_DIR" "$PLUGIN_ENABLED_DIR" "$PLUGIN_STATE_DIR"
    chmod 750 "$PLUGIN_DIR" "$PLUGIN_DATA_DIR" "$PLUGIN_LOG_DIR" "$PLUGIN_ENABLED_DIR" "$PLUGIN_STATE_DIR"
    
    # Load plugins
    plugins_load
    
    log_info "Plugin system initialized"
    return 0
}

# Load and validate plugins
function plugins_load() {
    log_info "Loading plugins"
    
    # Check if plugin directory exists and has plugins
    if [[ ! -d "$PLUGIN_DIR" || -z "$(ls -A "$PLUGIN_DIR" 2>/dev/null)" ]]; then
        log_info "No plugins found in $PLUGIN_DIR"
        return 0
    fi
    
    # Process each plugin
    for PLUGIN_FILE in "$PLUGIN_DIR"/*.sh; do
        if [[ -f "$PLUGIN_FILE" ]]; then
            PLUGIN_NAME=$(basename "$PLUGIN_FILE" .sh)
            log_info "Processing plugin: $PLUGIN_NAME"
            
            # Validate plugin
            if plugins_validate "$PLUGIN_FILE"; then
                log_info "Plugin validated: $PLUGIN_NAME"
                
                # Create data directory for plugin
                PLUGIN_DATA_PATH="$PLUGIN_DATA_DIR/$PLUGIN_NAME"
                mkdir -p "$PLUGIN_DATA_PATH"
                chmod 750 "$PLUGIN_DATA_PATH"
                
                # Source plugin if it's enabled
                if [[ -L "$PLUGIN_ENABLED_DIR/$PLUGIN_NAME.sh" || "${ENABLE_ALL_PLUGINS:-false}" == "true" ]]; then
                    log_info "Loading plugin: $PLUGIN_NAME"
                    source "$PLUGIN_FILE"
                    
                    # Run plugin initialization if available
                    if declare -f "${PLUGIN_NAME}_init" > /dev/null; then
                        log_info "Initializing plugin: $PLUGIN_NAME"
                        ${PLUGIN_NAME}_init
                    fi
                else
                    log_info "Plugin not enabled: $PLUGIN_NAME"
                fi
            else
                log_warning "Plugin validation failed: $PLUGIN_NAME"
            fi
        fi
    done
    
    log_info "Plugin loading completed"
    return 0
}

# Validate plugin for security issues
function plugins_validate() {
    local PLUGIN_FILE="$1"
    local VALIDATION_PASSED=true
    
    # Check for dangerous commands
    local DANGEROUS_COMMANDS=("curl" "wget" "nc" "eval" "exec" "sudo" "su" "chroot" "dd" "mkfs" "rm -rf" ":(){ :|:& };:")
    
    for CMD in "${DANGEROUS_COMMANDS[@]}"; do
        if grep -q "$CMD" "$PLUGIN_FILE"; then
            log_warning "Plugin contains potentially dangerous command: $CMD"
            VALIDATION_PASSED=false
        fi
    done
    
    # Check for syntax errors
    if ! bash -n "$PLUGIN_FILE"; then
        log_error "Plugin contains syntax errors"
        VALIDATION_PASSED=false
    fi
    
    # Return validation result
    if [[ "$VALIDATION_PASSED" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Execute hook on all plugins
function plugins_execute_hooks() {
    local HOOK_NAME="$1"
    shift
    local HOOK_ARGS="$@"
    
    # Check if plugins are enabled
    if [[ "${ENABLE_PLUGINS:-false}" != "true" ]]; then
        return 0
    fi
    
    log_info "Executing plugin hook: $HOOK_NAME"
    
    # Find all registered hooks
    declare -a HOOK_FUNCTIONS
    
    # Loop through all loaded functions
    for FUNC in $(declare -F | cut -d' ' -f3 | grep "_${HOOK_NAME}$"); do
        HOOK_FUNCTIONS+=("$FUNC")
    done
    
    # Execute each hook function
    for FUNC in "${HOOK_FUNCTIONS[@]}"; do
        local PLUGIN_NAME=$(echo "$FUNC" | sed "s/_${HOOK_NAME}$//")
        log_info "Executing hook $HOOK_NAME for plugin $PLUGIN_NAME"
        
        # Create log file for this hook execution
        local LOG_FILE="$PLUGIN_LOG_DIR/${PLUGIN_NAME}_${HOOK_NAME}_$(date +%Y%m%d%H%M%S).log"
        
        # Execute hook with timeout and resource limits
        (
            # Set resource limits
            ulimit -v 51200    # 50MB memory
            ulimit -t 30       # 30 seconds CPU time
            ulimit -n 256      # 256 file descriptors
            
            # Execute hook and capture output
            if ! "$FUNC" "$HOOK_ARGS" > "$LOG_FILE" 2>&1; then
                log_warning "Hook execution failed: ${PLUGIN_NAME}_${HOOK_NAME}"
            fi
        ) &
        
        # Add PID to list
        HOOK_PIDS+=($!)
    done
    
    # Wait for all hooks to complete
    for PID in "${HOOK_PIDS[@]}"; do
        wait "$PID" || log_warning "Hook process $PID exited with non-zero status"
    done
    
    log_info "Hook execution completed: $HOOK_NAME"
    return 0
}

# Plugin management functions
function plugin_enable() {
    local PLUGIN_NAME="$1"
    local PLUGIN_FILE="$PLUGIN_DIR/${PLUGIN_NAME}.sh"
    
    if [[ -f "$PLUGIN_FILE" ]]; then
        # Create symlink to enable plugin
        ln -sf "$PLUGIN_FILE" "$PLUGIN_ENABLED_DIR/${PLUGIN_NAME}.sh"
        log_info "Plugin enabled: $PLUGIN_NAME"
        return 0
    else
        log_error "Plugin not found: $PLUGIN_NAME"
        return 1
    fi
}

function plugin_disable() {
    local PLUGIN_NAME="$1"
    
    if [[ -L "$PLUGIN_ENABLED_DIR/${PLUGIN_NAME}.sh" ]]; then
        # Remove symlink to disable plugin
        rm -f "$PLUGIN_ENABLED_DIR/${PLUGIN_NAME}.sh"
        log_info "Plugin disabled: $PLUGIN_NAME"
        return 0
    else
        log_error "Plugin not enabled: $PLUGIN_NAME"
        return 1
    fi
}

function plugin_list() {
    log_info "Installed plugins:"
    
    for PLUGIN_FILE in "$PLUGIN_DIR"/*.sh; do
        if [[ -f "$PLUGIN_FILE" ]]; then
            PLUGIN_NAME=$(basename "$PLUGIN_FILE" .sh)
            if [[ -L "$PLUGIN_ENABLED_DIR/${PLUGIN_NAME}.sh" ]]; then
                echo "  $PLUGIN_NAME [enabled]"
            else
                echo "  $PLUGIN_NAME [disabled]"
            fi
        fi
    done
    
    return 0
}

# Helper functions for use in plugins
function plugin_log() {
    local MESSAGE="$1"
    local LEVEL="${2:-INFO}"
    local PLUGIN_NAME="${FUNCNAME[1]%_*}"
    
    if [[ -z "$PLUGIN_NAME" || "$PLUGIN_NAME" == "plugin_log" ]]; then
        PLUGIN_NAME="${BASH_SOURCE[1]##*/}"
        PLUGIN_NAME="${PLUGIN_NAME%.sh}"
    fi
    
    log "$MESSAGE" "$LEVEL" "plugin:$PLUGIN_NAME"
}

function plugin_get_data_dir() {
    local PLUGIN_NAME="${FUNCNAME[1]%_*}"
    if [[ -z "$PLUGIN_NAME" || "$PLUGIN_NAME" == "plugin_get_data_dir" ]]; then
        PLUGIN_NAME="${BASH_SOURCE[1]##*/}"
        PLUGIN_NAME="${PLUGIN_NAME%.sh}"
    fi
    
    echo "$PLUGIN_DATA_DIR/$PLUGIN_NAME"
}

function plugin_get_state_dir() {
    local PLUGIN_NAME="${FUNCNAME[1]%_*}"
    if [[ -z "$PLUGIN_NAME" || "$PLUGIN_NAME" == "plugin_get_state_dir" ]]; then
        PLUGIN_NAME="${BASH_SOURCE[1]##*/}"
        PLUGIN_NAME="${PLUGIN_NAME%.sh}"
    fi
    
    mkdir -p "$PLUGIN_STATE_DIR/$PLUGIN_NAME"
    echo "$PLUGIN_STATE_DIR/$PLUGIN_NAME"
}

function plugin_state_save() {
    local KEY="$1"
    local VALUE="$2"
    local PLUGIN_NAME="${FUNCNAME[1]%_*}"
    
    if [[ -z "$PLUGIN_NAME" || "$PLUGIN_NAME" == "plugin_state_save" ]]; then
        PLUGIN_NAME="${BASH_SOURCE[1]##*/}"
        PLUGIN_NAME="${PLUGIN_NAME%.sh}"
    fi
    
    local STATE_DIR="$PLUGIN_STATE_DIR/$PLUGIN_NAME"
    mkdir -p "$STATE_DIR"
    echo "$VALUE" > "$STATE_DIR/$KEY"
    
    return $?
}

function plugin_state_get() {
    local KEY="$1"
    local DEFAULT="$2"
    local PLUGIN_NAME="${FUNCNAME[1]%_*}"
    
    if [[ -z "$PLUGIN_NAME" || "$PLUGIN_NAME" == "plugin_state_get" ]]; then
        PLUGIN_NAME="${BASH_SOURCE[1]##*/}"
        PLUGIN_NAME="${PLUGIN_NAME%.sh}"
    fi
    
    local STATE_DIR="$PLUGIN_STATE_DIR/$PLUGIN_NAME"
    local STATE_FILE="$STATE_DIR/$KEY"
    
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo "$DEFAULT"
    fi
}

function plugin_send_metric() {
    local NAME="$1"
    local VALUE="$2"
    local TYPE="${3:-gauge}"
    local PLUGIN_NAME="${FUNCNAME[1]%_*}"
    
    if [[ -z "$PLUGIN_NAME" || "$PLUGIN_NAME" == "plugin_send_metric" ]]; then
        PLUGIN_NAME="${BASH_SOURCE[1]##*/}"
        PLUGIN_NAME="${PLUGIN_NAME%.sh}"
    fi
    
    # Pass to main metrics system
    if type record_metric >/dev/null 2>&1; then
        record_metric "plugin_${PLUGIN_NAME}_${NAME}" "$VALUE" "$TYPE"
    fi
}

function plugin_get_hook_args() {
    echo "$HOOK_ARGS"
}

function plugin_get_trace_id() {
    echo "$TRACE_ID"
}

# Export functions
export PLUGINS_LOADED=true