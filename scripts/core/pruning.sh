# scripts/core/pruning.sh
#!/bin/bash
# Blockchain pruning utilities for Meowcoin Docker

# Source common utilities
source /usr/local/bin/core/utils.sh

# Default settings
PRUNING_ENABLED="${ENABLE_PRUNING:-false}"
PRUNING_KEEP_BLOCKS="${PRUNING_KEEP_BLOCKS:-10000}"
PRUNING_INTERVAL_HOURS="${PRUNING_INTERVAL_HOURS:-168}" # Default: weekly
PRUNING_LOG_FILE="/var/log/meowcoin/pruning.log"
PRUNING_STATUS_FILE="/var/lib/meowcoin/pruning_status.json"
DATA_DIR="/home/meowcoin/.meowcoin"
CONFIG_FILE="$DATA_DIR/meowcoin.conf"

# Initialize pruning system
function pruning_init() {
    log_info "Initializing blockchain pruning system"
    
    # Create log file
    mkdir -p "$(dirname "$PRUNING_LOG_FILE")"
    touch "$PRUNING_LOG_FILE"
    chown meowcoin:meowcoin "$PRUNING_LOG_FILE"
    
    # Check if pruning is enabled
    if [[ "$PRUNING_ENABLED" != "true" ]]; then
        log_info "Pruning is disabled"
        return 0
    fi
    
    # Set up scheduled pruning if cron is available
    if [[ -d "/etc/cron.d" ]]; then
        setup_pruning_schedule
    else
        log_warning "Cron not available, cannot schedule automatic pruning"
    fi
    
    # Initialize pruning status file
    if [[ ! -f "$PRUNING_STATUS_FILE" ]]; then
        initialize_pruning_status
    fi
    
    log_info "Pruning system initialized with keep_blocks=$PRUNING_KEEP_BLOCKS"
    return 0
}

# Setup pruning schedule
function setup_pruning_schedule() {
    local HOURS="$((PRUNING_INTERVAL_HOURS % 24))"
    local DAYS="$((PRUNING_INTERVAL_HOURS / 24))"
    
    if [[ $DAYS -gt 0 ]]; then
        # Schedule at specific day and hour
        CRON_SCHEDULE="0 $HOURS */$DAYS * *"
    else
        # Schedule at specific hour every day
        CRON_SCHEDULE="0 */$HOURS * * *"
    fi
    
    # Create cron job
    cat > /etc/cron.d/meowcoin-pruning <<EOF
# Meowcoin blockchain pruning
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=""
HOME=/home/meowcoin

# Pruning schedule (currently: $PRUNING_INTERVAL_HOURS hours)
$CRON_SCHEDULE meowcoin /usr/local/bin/jobs/pruning.sh run > $PRUNING_LOG_FILE 2>&1
EOF
    
    chmod 644 /etc/cron.d/meowcoin-pruning
    log_info "Automatic pruning scheduled: $CRON_SCHEDULE (every $PRUNING_INTERVAL_HOURS hours)"
    
    return 0
}

# Initialize pruning status
function initialize_pruning_status() {
    mkdir -p "$(dirname "$PRUNING_STATUS_FILE")"
    
    cat > "$PRUNING_STATUS_FILE" <<EOF
{
  "enabled": $PRUNING_ENABLED,
  "keep_blocks": $PRUNING_KEEP_BLOCKS,
  "last_pruned": null,
  "next_scheduled": null,
  "total_pruned": 0,
  "space_saved": 0,
  "status": "initialized"
}
EOF
    
    chown meowcoin:meowcoin "$PRUNING_STATUS_FILE"
    chmod 644 "$PRUNING_STATUS_FILE"
    
    return 0
}

# Update pruning status
function update_pruning_status() {
    local STATUS="$1"
    local LAST_PRUNED="$2"
    local BLOCKS_PRUNED="$3"
    local SPACE_SAVED="$4"
    
    # Read existing status
    local CURRENT_STATUS
    CURRENT_STATUS=$(cat "$PRUNING_STATUS_FILE" 2>/dev/null)
    
    # Get previous total pruned
    local TOTAL_PRUNED=0
    if [[ -n "$CURRENT_STATUS" ]]; then
        TOTAL_PRUNED=$(echo "$CURRENT_STATUS" | jq -r '.total_pruned // 0')
    fi
    
    # Calculate new total pruned
    TOTAL_PRUNED=$((TOTAL_PRUNED + BLOCKS_PRUNED))
    
    # Calculate next scheduled pruning
    local NEXT_SCHEDULED
    if [[ -n "$LAST_PRUNED" ]]; then
        NEXT_SCHEDULED=$(date -d "$LAST_PRUNED + $PRUNING_INTERVAL_HOURS hours" +%s)
    else
        NEXT_SCHEDULED=$(date -d "now + $PRUNING_INTERVAL_HOURS hours" +%s)
    fi
    
    # Update status file
    cat > "$PRUNING_STATUS_FILE" <<EOF
{
  "enabled": $PRUNING_ENABLED,
  "keep_blocks": $PRUNING_KEEP_BLOCKS,
  "last_pruned": $(if [[ -n "$LAST_PRUNED" ]]; then echo "\"$LAST_PRUNED\""; else echo "null"; fi),
  "next_scheduled": $NEXT_SCHEDULED,
  "total_pruned": $TOTAL_PRUNED,
  "space_saved": "$SPACE_SAVED",
  "status": "$STATUS"
}
EOF
    
    chown meowcoin:meowcoin "$PRUNING_STATUS_FILE"
    chmod 644 "$PRUNING_STATUS_FILE"
    
    return 0
}

# Run pruning operation
function run_pruning() {
    if [[ "$PRUNING_ENABLED" != "true" ]]; then
        log_info "Pruning is disabled, skipping operation"
        return 0
    fi
    
    log_info "Starting blockchain pruning operation"
    
    # Check if node is running
    if ! pgrep -x "meowcoind" >/dev/null; then
        log_error "Meowcoin daemon is not running, cannot prune"
        update_pruning_status "error" "" 0 "0"
        return 1
    fi
    
    # Check if node is in sync
    local BLOCKCHAIN_INFO
    BLOCKCHAIN_INFO=$(meowcoin-cli getblockchaininfo 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to get blockchain info, cannot prune"
        update_pruning_status "error" "" 0 "0"
        return 1
    fi
    
    local BLOCKS
    BLOCKS=$(echo "$BLOCKCHAIN_INFO" | jq -r '.blocks')
    
    local HEADERS
    HEADERS=$(echo "$BLOCKCHAIN_INFO" | jq -r '.headers')
    
    if [[ $((HEADERS - BLOCKS)) -gt 6 ]]; then
        log_warning "Node is not fully synced (blocks: $BLOCKS, headers: $HEADERS), skipping pruning"
        update_pruning_status "waiting_sync" "" 0 "0"
        return 1
    fi
    
    # Check if we have enough blocks to prune
    if [[ $BLOCKS -lt $((PRUNING_KEEP_BLOCKS + 1000)) ]]; then
        log_info "Not enough blocks to prune (have $BLOCKS, need at least $((PRUNING_KEEP_BLOCKS + 1000)))"
        update_pruning_status "waiting_blocks" "" 0 "0"
        return 0
    fi
    
    # Get disk usage before pruning
    local BEFORE_SIZE
    BEFORE_SIZE=$(du -sm "$DATA_DIR/blocks" 2>/dev/null | cut -f1)
    
    # Set pruning mode if needed
    if ! grep -q "^prune=" "$CONFIG_FILE"; then
        log_info "Enabling pruning mode with keep_blocks=$PRUNING_KEEP_BLOCKS"
        echo "prune=$PRUNING_KEEP_BLOCKS" >> "$CONFIG_FILE"
        
        # Restart daemon to apply pruning setting
        log_info "Restarting daemon to apply pruning setting"
        supervisorctl stop meowcoin >/dev/null
        sleep 5
        supervisorctl start meowcoin >/dev/null
        
        # Wait for daemon to start
        log_info "Waiting for daemon to restart..."
        local WAIT_TIME=0
        while ! pgrep -x "meowcoind" >/dev/null && [[ $WAIT_TIME -lt 60 ]]; do
            sleep 5
            WAIT_TIME=$((WAIT_TIME + 5))
        done
        
        # Wait additional time for RPC to be available
        sleep 10
    fi
    
    # Execute pruning operation
    log_info "Executing blockchain pruning..."
    local PRUNE_RESULT
    PRUNE_RESULT=$(meowcoin-cli pruneblockchain $((BLOCKS - PRUNING_KEEP_BLOCKS)) 2>&1)
    
    if [[ $? -ne 0 ]]; then
        log_error "Pruning operation failed: $PRUNE_RESULT"
        update_pruning_status "error" "$(date -Iseconds)" 0 "0"
        return 1
    fi
    
    # Get disk usage after pruning
    local AFTER_SIZE
    AFTER_SIZE=$(du -sm "$DATA_DIR/blocks" 2>/dev/null | cut -f1)
    
    # Calculate space saved
    local SPACE_SAVED=$((BEFORE_SIZE - AFTER_SIZE))
    
    log_info "Pruning operation completed successfully"
    log_info "Blocks pruned: $((BLOCKS - PRUNING_KEEP_BLOCKS))"
    log_info "Space saved: ${SPACE_SAVED}MB"
    
    # Update pruning status
    update_pruning_status "completed" "$(date -Iseconds)" $((BLOCKS - PRUNING_KEEP_BLOCKS)) "${SPACE_SAVED}MB"
    
    return 0
}

# Export functions
export -f pruning_init
export -f run_pruning
export -f update_pruning_status