#!/bin/bash
# scripts/core/plugin_isolation.sh
# Enhanced isolation for plugins

# Source common utilities
source /usr/local/bin/core/utils.sh

# Default settings
PLUGINS_ISOLATION="${PLUGINS_ISOLATION:-true}"
PLUGIN_DIR="${PLUGIN_DIR:-/etc/meowcoin/plugins}"
PLUGIN_NAMESPACE_DIR="/var/run/meowcoin/plugin_namespaces"

# Initialize plugin isolation
function plugin_isolation_init() {
    log_info "Initializing plugin isolation system"
    
    # Check if isolation is enabled
    if [[ "$PLUGINS_ISOLATION" != "true" ]]; then
        log_info "Plugin isolation is disabled"
        return 0
    fi
    
    # Create namespace directory
    mkdir -p "$PLUGIN_NAMESPACE_DIR"
    chmod 750 "$PLUGIN_NAMESPACE_DIR"
    
    log_info "Plugin isolation system initialized"
    return 0
}

# Run plugin in isolated environment
function run_isolated_plugin() {
    local PLUGIN_NAME="$1"
    local HOOK_NAME="$2"
    shift 2
    local ARGS="$@"
    
    # Check if isolation is enabled
    if [[ "$PLUGINS_ISOLATION" != "true" ]]; then
        # Run plugin directly without isolation
        ${PLUGIN_NAME}_${HOOK_NAME} $ARGS
        return $?
    fi
    
    log_info "Running plugin $PLUGIN_NAME hook $HOOK_NAME in isolation"
    
    # Create namespace directory for this plugin
    local PLUGIN_NS_DIR="$PLUGIN_NAMESPACE_DIR/$PLUGIN_NAME"
    mkdir -p "$PLUGIN_NS_DIR"
    chmod 750 "$PLUGIN_NS_DIR"
    
    # Create temporary script for isolation
    local TEMP_SCRIPT=$(mktemp)
    chmod 700 "$TEMP_SCRIPT"
    
    # Write isolation script
    cat > "$TEMP_SCRIPT" <<EOF
#!/bin/bash
# Isolated environment for plugin $PLUGIN_NAME

# Source plugin
source "$PLUGIN_DIR/$PLUGIN_NAME.sh"

# Run hook with arguments
${PLUGIN_NAME}_${HOOK_NAME} $ARGS
exit \$?
EOF
    
    # Run in isolated environment with unshare if available
    if command -v unshare >/dev/null 2>&1; then
        # Run with namespace isolation
        unshare --mount --uts --ipc --pid --mount-proc --fork \
            --map-root-user \
            --root="$PLUGIN_NS_DIR" \
            "$TEMP_SCRIPT" 2>&1
        local RESULT=$?
    else
        # Fallback to basic isolation
        "$TEMP_SCRIPT" 2>&1
        local RESULT=$?
    fi
    
    # Clean up
    rm -f "$TEMP_SCRIPT"
    
    return $RESULT
}

# Export functions
export -f plugin_isolation_init
export -f run_isolated_plugin