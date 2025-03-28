#!/bin/bash
# scripts/core/version.sh
# Version management for Meowcoin Docker

# Source common utilities
source /usr/local/bin/core/utils.sh
source /usr/local/bin/core/backup.sh

# Default settings
VERSION_FILE="/meowcoin_version.txt"
VERSION_HISTORY_FILE="/var/lib/meowcoin/version_history.json"
ROLLBACK_ENABLED="${ROLLBACK_ENABLED:-true}"
BACKUP_BEFORE_UPDATE="${BACKUP_BEFORE_UPDATE:-true}"
MAX_VERSION_HISTORY="${MAX_VERSION_HISTORY:-5}"

# Initialize version management
function version_init() {
    log_info "Initializing version management system"
    
    # Create version history directory
    mkdir -p "$(dirname "$VERSION_HISTORY_FILE")"
    
    # Initialize version history if it doesn't exist
    if [[ ! -f "$VERSION_HISTORY_FILE" ]]; then
        initialize_version_history
    fi
    
    # Add current version to history
    add_version_to_history
    
    log_info "Version management initialized"
    return 0
}

# Initialize version history
function initialize_version_history() {
    local CURRENT_VERSION
    CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
    
    cat > "$VERSION_HISTORY_FILE" <<EOF
{
  "current": "$CURRENT_VERSION",
  "history": [
    {
      "version": "$CURRENT_VERSION",
      "installed_at": "$(date -Iseconds)",
      "status": "active"
    }
  ],
  "rollback_enabled": $ROLLBACK_ENABLED
}
EOF
    
    chmod 644 "$VERSION_HISTORY_FILE"
    
    return 0
}

# Add version to history
function add_version_to_history() {
    local CURRENT_VERSION
    CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
    
    # Read existing history
    local HISTORY
    HISTORY=$(cat "$VERSION_HISTORY_FILE" 2>/dev/null)
    
    if [[ -z "$HISTORY" ]]; then
        initialize_version_history
        return 0
    fi
    
    # Get current version from history
    local HISTORY_CURRENT
    HISTORY_CURRENT=$(echo "$HISTORY" | jq -r '.current')
    
    # If same version, do nothing
    if [[ "$CURRENT_VERSION" == "$HISTORY_CURRENT" ]]; then
        return 0
    fi
    
    # Add new version to history
    local NEW_HISTORY
    NEW_HISTORY=$(echo "$HISTORY" | jq \
        --arg ver "$CURRENT_VERSION" \
        --arg date "$(date -Iseconds)" \
        '.current = $ver | .history = ([{"version": $ver, "installed_at": $date, "status": "active"}] + .history)')
    
    # Limit history size
    NEW_HISTORY=$(echo "$NEW_HISTORY" | jq \
        --argjson max "$MAX_VERSION_HISTORY" \
        '.history = .history[0:$max]')
    
    # Write updated history
    echo "$NEW_HISTORY" > "$VERSION_HISTORY_FILE"
    chmod 644 "$VERSION_HISTORY_FILE"
    
    log_info "Added version $CURRENT_VERSION to history"
    return 0
}

# Check for version change
function check_version_change() {
    local CURRENT_VERSION
    CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
    
    # Read existing history
    local HISTORY
    HISTORY=$(cat "$VERSION_HISTORY_FILE" 2>/dev/null)
    
    if [[ -z "$HISTORY" ]]; then
        return 1
    fi
    
    # Get version from history
    local HISTORY_CURRENT
    HISTORY_CURRENT=$(echo "$HISTORY" | jq -r '.current')
    
    # If different version, return success
    if [[ "$CURRENT_VERSION" != "$HISTORY_CURRENT" ]]; then
        log_info "Version change detected: $HISTORY_CURRENT -> $CURRENT_VERSION"
        return 0
    fi
    
    return 1
}

# Handle version change
function handle_version_change() {
    local CURRENT_VERSION
    CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
    
    # Read existing history
    local HISTORY
    HISTORY=$(cat "$VERSION_HISTORY_FILE" 2>/dev/null)
    
    if [[ -z "$HISTORY" ]]; then
        initialize_version_history
        return 0
    fi
    
    # Get previous version
    local PREVIOUS_VERSION
    PREVIOUS_VERSION=$(echo "$HISTORY" | jq -r '.current')
    
    log_info "Handling version change: $PREVIOUS_VERSION -> $CURRENT_VERSION"
    
    # Create backup if enabled
    if [[ "$BACKUP_BEFORE_UPDATE" == "true" ]]; then
        log_info "Creating backup before update"
        backup_create "version_change"
    fi
    
    # Add new version to history
    add_version_to_history
    
    # Run update hooks if plugins enabled
    if type plugin_execute_hook >/dev/null 2>&1; then
        plugin_execute_hook "version_change" "$PREVIOUS_VERSION" "$CURRENT_VERSION"
    fi
    
    return 0
}

# Rollback to previous version
function rollback_version() {
    # Check if rollback is enabled
    if [[ "$ROLLBACK_ENABLED" != "true" ]]; then
        log_error "Rollback is not enabled"
        return 1
    fi
    
    # Read version history
    local HISTORY
    HISTORY=$(cat "$VERSION_HISTORY_FILE" 2>/dev/null)
    
    if [[ -z "$HISTORY" ]]; then
        log_error "No version history available for rollback"
        return 1
    fi
    
    # Get current and previous versions
    local CURRENT_VERSION
    CURRENT_VERSION=$(echo "$HISTORY" | jq -r '.current')
    
    # Need at least 2 versions in history
    local HISTORY_COUNT
    HISTORY_COUNT=$(echo "$HISTORY" | jq '.history | length')
    
    if [[ $HISTORY_COUNT -lt 2 ]]; then
        log_error "Not enough version history for rollback"
        return 1
    fi
    
    # Get previous version
    local PREVIOUS_VERSION
    PREVIOUS_VERSION=$(echo "$HISTORY" | jq -r '.history[1].version')
    
    log_info "Rolling back from $CURRENT_VERSION to $PREVIOUS_VERSION"
    
    # Create backup before rollback
    log_info "Creating backup before rollback"
    backup_create "rollback"
    
    # Update version history
    local NEW_HISTORY
    NEW_HISTORY=$(echo "$HISTORY" | jq \
        --arg ver "$PREVIOUS_VERSION" \
        '.current = $ver | .history = .history[1:] | .history[0].status = "active" | .history[0].rollback_date = now')
    
    # Write updated history
    echo "$NEW_HISTORY" > "$VERSION_HISTORY_FILE"
    
    # Run rollback hooks if plugins enabled
    if type plugin_execute_hook >/dev/null 2>&1; then
        plugin_execute_hook "version_rollback" "$CURRENT_VERSION" "$PREVIOUS_VERSION"
    fi
    
    log_info "Rollback completed. Please restart the container to apply changes."
    
    return 0
}

# Export functions
export -f version_init
export -f check_version_change
export -f handle_version_change
export -f rollback_version