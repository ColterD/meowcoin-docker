#!/bin/bash
# scripts/core/logging.sh
# Centralized logging system for Meowcoin Docker

# Default settings
LOG_DIR="/var/log/meowcoin"
MAIN_LOG="$LOG_DIR/meowcoin.log"
MAX_LOG_SIZE_MB=10
MAX_LOG_FILES=5

# Initialize logging system
function logging_init() {
    # Create log directories with proper permissions
    mkdir -p "$LOG_DIR"
    chmod 750 "$LOG_DIR"
    chown meowcoin:meowcoin "$LOG_DIR"
    
    # Create log files
    touch "$MAIN_LOG"
    chmod 640 "$MAIN_LOG"
    chown meowcoin:meowcoin "$MAIN_LOG"
    
    # Setup log rotation
    setup_log_rotation
    
    # Export functions
    export LOG_DIR MAIN_LOG
    
    return 0
}

# Setup log rotation with logrotate
function setup_log_rotation() {
    if [ -d "/etc/logrotate.d" ]; then
        cat > /etc/logrotate.d/meowcoin <<EOF
$LOG_DIR/*.log {
    size ${MAX_LOG_SIZE_MB}M
    rotate $MAX_LOG_FILES
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
    create 0640 meowcoin meowcoin
}
EOF
        chmod 644 /etc/logrotate.d/meowcoin
    else
        echo "WARNING: logrotate directory not found, log rotation not configured" >&2
    fi
}

# Enhanced logging function with additional metadata
function log() {
    local MESSAGE="$1"
    local LEVEL="${2:-INFO}"
    local SOURCE="${3:-main}"
    local LOG_FILE="${4:-$MAIN_LOG}"
    local TIMESTAMP=$(date -Iseconds)
    
    # Format log message
    local FORMATTED_MSG="[$TIMESTAMP][$LEVEL][$SOURCE] $MESSAGE"
    
    # Write to log file
    echo "$FORMATTED_MSG" >> "$LOG_FILE"
    
    # Output to stderr for warning/error levels
    if [[ "$LEVEL" == "ERROR" || "$LEVEL" == "CRITICAL" || "$LEVEL" == "WARNING" ]]; then
        echo "$FORMATTED_MSG" >&2
    fi
    
    # Output to stdout for debug mode
    if [[ "${DEBUG_MODE:-false}" == "true" ]]; then
        echo "$FORMATTED_MSG"
    fi
}

# Log level convenience functions
function log_debug() { log "$1" "DEBUG" "${2:-main}" "${3:-$MAIN_LOG}"; }
function log_info() { log "$1" "INFO" "${2:-main}" "${3:-$MAIN_LOG}"; }
function log_warning() { log "$1" "WARNING" "${2:-main}" "${3:-$MAIN_LOG}"; }
function log_error() { log "$1" "ERROR" "${2:-main}" "${3:-$MAIN_LOG}"; }
function log_critical() { log "$1" "CRITICAL" "${2:-main}" "${3:-$MAIN_LOG}"; }

# Capture stdout and stderr to log file
function capture_output() {
    local COMMAND="$1"
    local LOG_FILE="${2:-$MAIN_LOG}"
    local LOG_LEVEL="${3:-INFO}"
    local SOURCE="${4:-command}"
    
    log "Executing command: $COMMAND" "$LOG_LEVEL" "$SOURCE" "$LOG_FILE"
    
    # Execute command and capture output
    local OUTPUT
    if OUTPUT=$($COMMAND 2>&1); then
        log "Command executed successfully" "DEBUG" "$SOURCE" "$LOG_FILE"
        log "$OUTPUT" "$LOG_LEVEL" "$SOURCE" "$LOG_FILE"
        return 0
    else
        local EXIT_CODE=$?
        log "Command failed with exit code $EXIT_CODE" "ERROR" "$SOURCE" "$LOG_FILE"
        log "$OUTPUT" "ERROR" "$SOURCE" "$LOG_FILE"
        return $EXIT_CODE
    fi
}

# Export functions
export -f logging_init log log_debug log_info log_warning log_error log_critical capture_output