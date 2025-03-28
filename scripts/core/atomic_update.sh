#!/bin/bash
# scripts/core/atomic_update.sh
# Atomic update manager for Meowcoin Docker

# Source common utilities
source /usr/local/bin/core/utils.sh
source /usr/local/bin/core/backup.sh
source /usr/local/bin/core/version.sh

# Default settings
ATOMIC_UPDATE_ENABLED="${ATOMIC_UPDATE_ENABLED:-true}"
UPDATE_LOG_FILE="/var/log/meowcoin/updates.log"
UPDATE_STATUS_FILE="/var/lib/meowcoin/update_status.json"
BLUE_GREEN_MODE="${BLUE_GREEN_MODE:-false}"
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-300}"
HEALTH_CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-10}"

# Initialize atomic update system
function atomic_update_init() {
    log_info "Initializing atomic update system"
    
    # Create log file
    mkdir -p "$(dirname "$UPDATE_LOG_FILE")"
    touch "$UPDATE_LOG_FILE"
    chmod 640 "$UPDATE_LOG_FILE"
    chown meowcoin:meowcoin "$UPDATE_LOG_FILE"
    
    # Create status file
    if [[ ! -f "$UPDATE_STATUS_FILE" ]]; then
        initialize_update_status
    fi
    
    log_info "Atomic update system initialized"
    return 0
}

# Initialize update status
function initialize_update_status() {
    mkdir -p "$(dirname "$UPDATE_STATUS_FILE")"
    
    local CURRENT_VERSION
    CURRENT_VERSION=$(cat "/meowcoin_version.txt" 2>/dev/null || echo "unknown")
    
    cat > "$UPDATE_STATUS_FILE" <<EOF
{
  "enabled": $ATOMIC_UPDATE_ENABLED,
  "blue_green": $BLUE_GREEN_MODE,
  "current_version": "$CURRENT_VERSION",
  "last_update": null,
  "update_history": [],
  "status": "initialized"
}
EOF
    
    chmod 644 "$UPDATE_STATUS_FILE"
    chown meowcoin:meowcoin "$UPDATE_STATUS_FILE"
    
    return 0
}

# Update status file
function update_atomic_status() {
    local STATUS="$1"
    local MESSAGE="$2"
    local SUCCESS="${3:-true}"
    
    # Read existing status
    local CURRENT_STATUS
    CURRENT_STATUS=$(cat "$UPDATE_STATUS_FILE" 2>/dev/null)
    
    if [[ -z "$CURRENT_STATUS" ]]; then
        initialize_update_status
        CURRENT_STATUS=$(cat "$UPDATE_STATUS_FILE")
    fi
    
    # Get current version
    local CURRENT_VERSION
    CURRENT_VERSION=$(cat "/meowcoin_version.txt" 2>/dev/null || echo "unknown")
    
    # Update status with history entry
    local NEW_STATUS
    NEW_STATUS=$(echo "$CURRENT_STATUS" | jq \
        --arg status "$STATUS" \
        --arg msg "$MESSAGE" \
        --arg ver "$CURRENT_VERSION" \
        --arg time "$(date -Iseconds)" \
        --argjson success "$SUCCESS" \
        '.status = $status | 
         .current_version = $ver | 
         .last_update = $time | 
         .update_history = ([{"timestamp": $time, "version": $ver, "status": $status, "message": $msg, "success": $success}] + .update_history | .[0:10])')
    
    echo "$NEW_STATUS" > "$UPDATE_STATUS_FILE"
    chmod 644 "$UPDATE_STATUS_FILE"
    chown meowcoin:meowcoin "$UPDATE_STATUS_FILE"
    
    return 0
}

# Run atomic update process
function run_atomic_update() {
    # Check if atomic updates are enabled
    if [[ "$ATOMIC_UPDATE_ENABLED" != "true" ]]; then
        log_info "Atomic updates are disabled"
        return 0
    fi
    
    # Check for version change
    if ! check_version_change; then
        log_info "No version change detected, skipping atomic update"
        return 0
    fi
    
    # Get current and new versions
    local PREVIOUS_VERSION
    local CURRENT_VERSION
    PREVIOUS_VERSION=$(jq -r '.current' "$VERSION_HISTORY_FILE" 2>/dev/null || echo "unknown")
    CURRENT_VERSION=$(cat "/meowcoin_version.txt" 2>/dev/null || echo "unknown")
    
    log_info "Starting atomic update from $PREVIOUS_VERSION to $CURRENT_VERSION"
    update_atomic_status "updating" "Starting update from $PREVIOUS_VERSION to $CURRENT_VERSION"
    
    # Create backup before update
    if [[ "$BACKUP_BEFORE_UPDATE" == "true" ]]; then
        log_info "Creating backup before update"
        if ! backup_create "pre_update"; then
            log_error "Backup creation failed, aborting update"
            update_atomic_status "failed" "Backup creation failed" "false"
            return 1
        fi
    fi
    
    # Choose update strategy
    if [[ "$BLUE_GREEN_MODE" == "true" ]]; then
        run_blue_green_update
    else
        run_in_place_update
    fi
    
    local UPDATE_RESULT=$?
    
    # Update version history
    handle_version_change
    
    # Return result
    return $UPDATE_RESULT
}

# Run in-place update
function run_in_place_update() {
    log_info "Running in-place update"
    update_atomic_status "in_place_update" "Performing in-place update"
    
    # Stop Meowcoin daemon
    log_info "Stopping Meowcoin daemon"
    supervisorctl stop meowcoin
    
    # Wait for daemon to stop
    local WAIT_TIME=0
    while pgrep -x "meowcoind" >/dev/null && [[ $WAIT_TIME -lt 60 ]]; do
        sleep 5
        WAIT_TIME=$((WAIT_TIME + 5))
    done
    
    # If still running after timeout, force kill
    if pgrep -x "meowcoind" >/dev/null; then
        log_warning "Daemon did not stop gracefully, force killing"
        pkill -9 -x "meowcoind"
        sleep 5
    fi
    
    # Start Meowcoin daemon
    log_info "Starting Meowcoin daemon with new version"
    supervisorctl start meowcoin
    
    # Wait for daemon to start and verify health
    log_info "Waiting for daemon to start and verify health"
    local START_TIME=$(date +%s)
    local CURRENT_TIME=$START_TIME
    local HEALTHY=false
    
    while [[ $((CURRENT_TIME - START_TIME)) -lt $HEALTH_CHECK_TIMEOUT ]]; do
        # Check if daemon is running
        if ! pgrep -x "meowcoind" >/dev/null; then
            log_error "Daemon failed to start"
            supervisorctl status meowcoin
            update_atomic_status "failed" "Daemon failed to start" "false"
            return 1
        fi
        
        # Check health after 30 seconds of uptime
        if [[ $((CURRENT_TIME - START_TIME)) -gt 30 ]]; then
            if /usr/local/bin/monitoring/health-check.sh > /dev/null 2>&1; then
                HEALTHY=true
                break
            fi
        fi
        
        # Wait before next check
        sleep $HEALTH_CHECK_INTERVAL
        CURRENT_TIME=$(date +%s)
    done
    
    # If not healthy after timeout, consider update failed
    if [[ "$HEALTHY" != "true" ]]; then
        log_error "Daemon is not healthy after update"
        update_atomic_status "failed" "Daemon is not healthy after update" "false"
        
        # Trigger rollback
        log_warning "Update failed, rolling back to previous version"
        rollback_version
        
        return 1
    fi
    
    # Update completed successfully
    log_info "Update completed successfully"
    update_atomic_status "complete" "Update to $(cat /meowcoin_version.txt) completed successfully"
    
    return 0
}

# Run blue-green update (maintains two instances for zero-downtime)
function run_blue_green_update() {
    log_info "Running blue-green update (zero-downtime)"
    update_atomic_status "blue_green_update" "Performing blue-green (zero-downtime) update"
    
    # Not implemented in this version due to complexity
    # This would involve running a second Meowcoin instance and switching over
    
    log_warning "Blue-green updates not fully implemented, falling back to in-place update"
    run_in_place_update
    return $?
}

# Export functions
export -f atomic_update_init
export -f run_atomic_update