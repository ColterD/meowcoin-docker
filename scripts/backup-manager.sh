#!/bin/bash

# Load helper functions
source /scripts/functions.sh

# Default configuration
BACKUP_ENABLED=${BACKUP_ENABLED:-true}
BACKUP_INTERVAL=${BACKUP_INTERVAL:-daily}
BACKUP_DIR="${MEOWCOIN_DATA}/backups"

# Set interval in seconds based on configuration
case "$BACKUP_INTERVAL" in
    hourly)
        INTERVAL=3600
        ;;
    daily)
        INTERVAL=86400
        ;;
    weekly)
        INTERVAL=604800
        ;;
    *)
        log_warn "Unknown backup interval: $BACKUP_INTERVAL, using daily"
        INTERVAL=86400
        ;;
esac

# Main backup loop
run_backup_manager() {
    if [ "$BACKUP_ENABLED" != "true" ]; then
        log_info "Backup service disabled, exiting"
        return 0
    fi
    
    log_info "Starting backup manager (interval: $BACKUP_INTERVAL)"
    
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    # Initialize last backup time
    local last_backup=0
    
    # Check if we have previous backups
    local latest_backup=$(find "$BACKUP_DIR" -name "meowcoin_backup_*.tar.gz" -type f -printf '%T@ %p\n' | sort -nr | head -n1)
    if [ -n "$latest_backup" ]; then
        last_backup=$(echo "$latest_backup" | cut -d' ' -f1 | cut -d'.' -f1)
        log_info "Found latest backup from $(date -d @$last_backup)"
    fi
    
    # Main loop
    while true; do
        local current_time=$(date +%s)
        
        # Check if it's time for a backup
        if [ $((current_time - last_backup)) -ge $INTERVAL ]; then
            log_info "Running scheduled backup..."
            
            # Create backup without stopping the node
            if create_backup; then
                last_backup=$current_time
                log_info "Next backup scheduled at $(date -d @$((current_time + INTERVAL)))"
            else
                log_error "Backup failed, will retry in 15 minutes"
                sleep 900  # Wait 15 minutes before retry
                continue
            fi
        fi
        
        # Sleep for a while before checking again
        # We check every 15 minutes to see if a backup is needed
        sleep 900
    done
}

# Handle signals
trap "log_info 'Received signal, exiting backup manager...'; exit 0" SIGTERM SIGINT

# Start backup manager
run_backup_manager