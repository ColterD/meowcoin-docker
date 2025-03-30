#!/bin/bash
set -e

# Source helper functions
source /scripts/functions.sh

log_info "Starting Meowcoin Web API service"

# Create API directory if it doesn't exist
mkdir -p /var/www/html/api
chown meowcoin:meowcoin /var/www/html/api

# Function to handle disk usage API request
handle_disk_usage_request() {
    log_info "Processing disk usage request"
    
    # Get the main directories to check
    local paths=(
        "/home/meowcoin/.meowcoin"
        "/home/meowcoin/.meowcoin/blocks"
        "/home/meowcoin/.meowcoin/chainstate"
        "/home/meowcoin/.meowcoin/database"
        "/data"
        "/data/backups"
        "/var/log"
        "/config"
    )
    
    # Initialize JSON array
    local json_paths="["
    local first=true
    
    # Check each path
    for path in "${paths[@]}"; do
        if [ -e "$path" ]; then
            # Get size in bytes
            local size=$(du -sb "$path" 2>/dev/null | awk '{print $1}')
            
            # If we got a valid size
            if [ -n "$size" ]; then
                if [ "$first" = true ]; then
                    first=false
                else
                    json_paths+=","
                fi
                
                # Add to JSON
                json_paths+="{\"path\":\"$path\",\"sizeBytes\":$size}"
                
                # Get subdirectories if it's the main blockchain dir
                if [ "$path" = "/home/meowcoin/.meowcoin" ]; then
                    # Check important subdirectories that might be large
                    for subdir in $(find "$path" -maxdepth 1 -type d | grep -v "^$path$" | grep -v "/blocks$" | grep -v "/chainstate$" | grep -v "/database$"); do
                        local subsize=$(du -sb "$subdir" 2>/dev/null | awk '{print $1}')
                        if [ -n "$subsize" ] && [ "$subsize" -gt 10485760 ]; then # Only add if > 10MB
                            json_paths+=",{\"path\":\"$subdir\",\"sizeBytes\":$subsize}"
                        fi
                    done
                fi
            fi
        fi
    done
    
    json_paths+="]"
    
    # Create full JSON response
    local response="{\"success\":true,\"paths\":$json_paths}"
    
    # Write to response file
    echo "$response" > /var/www/html/api/disk_usage.json
    log_info "Disk usage analysis complete"
}

# Function to handle logs API request
handle_logs_request() {
    local since="$1"
    local response=""
    
    log_info "Processing logs request since: $since"
    
    # Get logs from docker container
    local logs=""
    # Get docker logs with timestamp
    logs=$(docker logs --tail 100 meowcoin-node 2>&1)
    
    # Convert logs to JSON array
    if [ -n "$logs" ]; then
        local logs_json="["
        local first=true
        
        while IFS= read -r line; do
            if [ "$first" = true ]; then
                first=false
            else
                logs_json+=","
            fi
            
            # Escape quotes and backslashes
            line=$(echo "$line" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
            logs_json+="\"$line\""
        done <<< "$logs"
        
        logs_json+="]"
        
        response="{\"success\":true,\"logs\":$logs_json,\"timestamp\":$(date +%s000)}"
    else
        response="{\"success\":true,\"logs\":[],\"timestamp\":$(date +%s000)}"
    fi
    
    # Write to response file
    echo "$response" > /var/www/html/api/logs_response.json
    log_info "Logs request processed"
}

# Function to handle node update request
handle_update_request() {
    local version="$1"
    local response=""
    
    log_info "Received update request for version: $version"
    
    # Basic validation
    if [ -z "$version" ]; then
        response='{"success":false,"message":"No version specified"}'
        echo "$response" > /var/www/html/api/update_response.json
        return
    fi
    
    # Create update flag file with version
    echo "$version" > "${MEOWCOIN_DATA}/.meowcoin/update.flag"
    
    response='{"success":true,"message":"Update initiated. The node will restart when complete."}'
    echo "$response" > /var/www/html/api/update_response.json
    log_info "Update request processed for version: $version"
}

# Function to handle control API requests
handle_control_request() {
    local action="$1"
    local response=""
    
    case "$action" in
        restart)
            log_info "Received restart request from web UI"
            response='{"success":true,"message":"Restart initiated"}'
            # Schedule restart in background
            (
                sleep 1
                log_info "Executing restart sequence"
                # Use docker command to restart the container
                docker restart meowcoin-node
                log_info "Container restart command executed"
            ) &
            ;;
        shutdown)
            log_info "Received shutdown request from web UI"
            response='{"success":true,"message":"Shutdown initiated"}'
            # Schedule shutdown in background
            (
                sleep 1
                log_info "Executing shutdown sequence"
                # Use docker command to stop the container
                docker stop meowcoin-node
                log_info "Container stop command executed"
            ) &
            ;;
        *)
            log_error "Unknown action requested: $action"
            response='{"success":false,"message":"Unknown action"}'
            ;;
    esac
    
    echo "$response" > /var/www/html/api/control_response.json
}

# Function to handle settings API requests
handle_settings_request() {
    local request="$1"
    local max_connections=$(echo "$request" | jq -r '.maxConnections')
    local enable_txindex=$(echo "$request" | jq -r '.enableTxindex')
    local response=""
    
    log_info "Received settings update request: maxConnections=$max_connections, enableTxindex=$enable_txindex"
    
    # Validate input
    if ! [[ "$max_connections" =~ ^[0-9]+$ ]] || [ "$max_connections" -lt 1 ] || [ "$max_connections" -gt 125 ]; then
        response='{"success":false,"message":"Invalid maxConnections value"}'
        echo "$response" > /var/www/html/api/settings_response.json
        return
    fi
    
    if [[ "$enable_txindex" != "0" && "$enable_txindex" != "1" ]]; then
        response='{"success":false,"message":"Invalid enableTxindex value"}'
        echo "$response" > /var/www/html/api/settings_response.json
        return
    fi
    
    # Update meowcoin.conf
    local conf_file="${MEOWCOIN_CONFIG}/meowcoin.conf"
    
    # Create backup of config
    cp "$conf_file" "${conf_file}.bak"
    
    # Update settings
    if grep -q "^maxconnections=" "$conf_file"; then
        sed -i "s/^maxconnections=.*/maxconnections=$max_connections/" "$conf_file"
    else
        echo "maxconnections=$max_connections" >> "$conf_file"
    fi
    
    if grep -q "^txindex=" "$conf_file"; then
        sed -i "s/^txindex=.*/txindex=$enable_txindex/" "$conf_file"
    else
        echo "txindex=$enable_txindex" >> "$conf_file"
    fi
    
    log_info "Updated configuration settings"
    
    # Set restart flag if needed
    touch "${MEOWCOIN_DATA}/.meowcoin/config_updated.flag"
    
    response='{"success":true,"message":"Settings updated. A restart may be required for changes to take effect."}'
    echo "$response" > /var/www/html/api/settings_response.json
}

# Process API requests
process_api_requests() {
    # Check for control request
    if [ -f "/var/www/html/api/control_request.json" ]; then
        local action=$(jq -r '.action' "/var/www/html/api/control_request.json")
        handle_control_request "$action"
        rm -f "/var/www/html/api/control_request.json"
    fi
    
    # Check for settings request
    if [ -f "/var/www/html/api/settings_request.json" ]; then
        local request=$(cat "/var/www/html/api/settings_request.json")
        handle_settings_request "$request"
        rm -f "/var/www/html/api/settings_request.json"
    fi
    
    # Check for update request
    if [ -f "/var/www/html/api/update_request.json" ]; then
        local version=$(jq -r '.version' "/var/www/html/api/update_request.json")
        handle_update_request "$version"
        rm -f "/var/www/html/api/update_request.json"
    fi
    
    # Check for logs request
    if [ -f "/var/www/html/api/logs_request.json" ]; then
        local since=$(jq -r '.since' "/var/www/html/api/logs_request.json")
        handle_logs_request "$since"
        rm -f "/var/www/html/api/logs_request.json"
    fi
    
    # Check for disk usage request
    if [ -f "/var/www/html/api/disk_usage_request.flag" ]; then
        handle_disk_usage_request
        rm -f "/var/www/html/api/disk_usage_request.flag"
    fi
}

# Initial disk usage scan
handle_disk_usage_request

# Main loop
while true; do
    # Skip if shutdown flag exists
    if [ -f "${MEOWCOIN_DATA}/.meowcoin/shutdown.flag" ]; then
        log_info "Shutdown flag detected, stopping Web API service"
        exit 0
    fi
    
    # Process any API requests
    process_api_requests
    
    # Periodically update disk usage (every 15 minutes)
    if [ ! -f "/var/www/html/api/disk_usage.json" ] || [ "$(find /var/www/html/api/disk_usage.json -mmin +15 2>/dev/null)" ]; then
        handle_disk_usage_request
    fi
    
    # Sleep for a bit
    sleep 1
done