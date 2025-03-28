#!/bin/bash
# scripts/core/utils.sh
# Core utilities and helper functions for Meowcoin Docker

# Import logging module if available
if [ -f "$(dirname "$0")/logging.sh" ]; then
    source "$(dirname "$0")/logging.sh"
fi

# Flag to track initialization
UTILS_LOADED=false

# Initialize utilities
function utils_init() {
    # Create necessary directories
    mkdir -p /var/lib/meowcoin
    
    # Set up trace ID for request tracking
    if [ -z "$TRACE_ID" ]; then
        export TRACE_ID=$(date +%s)-$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8)
    fi
    
    # Initialize logging if not already done
    if type logging_init >/dev/null 2>&1; then
        logging_init
    fi
    
    # Set debug mode from environment
    DEBUG_MODE="${DEBUG_MODE:-false}"
    [ "$DEBUG_MODE" = "true" ] && log_info "Debug mode enabled" "utils"
    
    # Mark utils as loaded
    UTILS_LOADED=true
    
    log_info "Utilities initialized" "utils"
    return 0
}

# Enhanced error handling with retry capability
function retry_with_backoff() {
    local MAX_ATTEMPTS=${RETRY_MAX_ATTEMPTS:-3}
    local INITIAL_BACKOFF=${RETRY_INITIAL_BACKOFF:-1}
    local MAX_BACKOFF=${RETRY_MAX_BACKOFF:-30}
    local ATTEMPT=1
    local BACKOFF=$INITIAL_BACKOFF
    local COMMAND="$1"
    local CMD_DESC="${2:-command}"
    
    log_info "Executing '$CMD_DESC' with retry (max $MAX_ATTEMPTS attempts)" "utils"
    
    while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
        log_debug "Attempt $ATTEMPT of $MAX_ATTEMPTS for '$CMD_DESC'" "utils"
        
        if eval "$COMMAND"; then
            log_info "Command '$CMD_DESC' successful on attempt $ATTEMPT" "utils"
            return 0
        else
            local EXIT_CODE=$?
            log_warning "Command '$CMD_DESC' failed on attempt $ATTEMPT with code $EXIT_CODE" "utils"
            
            if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
                log_error "Command '$CMD_DESC' failed after $MAX_ATTEMPTS attempts" "utils"
                return $EXIT_CODE
            fi
            
            log_info "Retrying in $BACKOFF seconds..." "utils"
            sleep $BACKOFF
            
            # Exponential backoff with maximum cap
            BACKOFF=$((BACKOFF * 2))
            [ $BACKOFF -gt $MAX_BACKOFF ] && BACKOFF=$MAX_BACKOFF
            
            ATTEMPT=$((ATTEMPT + 1))
        fi
    done
    
    return 1
}

# Toggle debug mode
function toggle_debug_mode() {
    if [ "${DEBUG_MODE:-false}" = "true" ]; then
        export DEBUG_MODE=false
        log_info "Debug mode disabled" "utils"
    else
        export DEBUG_MODE=true
        log_info "Debug mode enabled" "utils"
    fi
    
    return 0
}

# Get debug status
function get_debug_status() {
    echo "${DEBUG_MODE:-false}"
    return 0
}

# Export functions
export UTILS_LOADED
export -f utils_init retry_with_backoff toggle_debug_mode get_debug_status