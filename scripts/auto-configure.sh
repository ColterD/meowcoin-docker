#!/bin/bash

# Load helper functions
source /scripts/functions.sh

log_info "Auto-configuring Meowcoin node..."

# Get system memory in MB
get_system_memory() {
    free -m | grep "Mem:" | awk '{print $2}'
}

# Configure memory-related settings based on available RAM
configure_memory() {
    local total_mem=$1
    local dbcache_size
    local maxmempool_size
    
    log_info "System memory: ${total_mem}MB"
    
    # Calculate dbcache (15% of total RAM, min 50MB, max 4GB)
    dbcache_size=$(( total_mem * 15 / 100 ))
    dbcache_size=$(( dbcache_size < 50 ? 50 : dbcache_size ))
    dbcache_size=$(( dbcache_size > 4000 ? 4000 : dbcache_size ))
    
    # Calculate maxmempool (10% of total RAM, min 50MB, max 1GB)
    maxmempool_size=$(( total_mem * 10 / 100 ))
    maxmempool_size=$(( maxmempool_size < 50 ? 50 : maxmempool_size ))
    maxmempool_size=$(( maxmempool_size > 1000 ? 1000 : maxmempool_size ))
    
    log_info "Setting dbcache=${dbcache_size}MB, maxmempool=${maxmempool_size}MB"
    
    # Update configuration
    local config_file="${MEOWCOIN_CONFIG}/meowcoin.conf"
    if [ -f "$config_file" ]; then
        if grep -q "^dbcache=" "$config_file"; then
            sed -i "s/^dbcache=.*/dbcache=${dbcache_size}/" "$config_file"
        else
            echo "dbcache=${dbcache_size}" >> "$config_file"
        fi
        
        if grep -q "^maxmempool=" "$config_file"; then
            sed -i "s/^maxmempool=.*/maxmempool=${maxmempool_size}/" "$config_file"
        else
            echo "maxmempool=${maxmempool_size}" >> "$config_file"
        fi
    fi
    
    return 0
}

# Configure max connections based on available bandwidth
configure_connections() {
    local max_conn=${MAX_CONNECTIONS:-"auto"}
    
    if [ "$max_conn" = "auto" ]; then
        # Auto-detect based on memory
        local mem_mb=$(get_system_memory)
        
        if [ $mem_mb -lt 1024 ]; then
            max_conn=20
        elif [ $mem_mb -lt 2048 ]; then
            max_conn=40
        elif [ $mem_mb -lt 4096 ]; then
            max_conn=70
        else
            max_conn=125
        fi
    fi
    
    # Ensure max_conn is within valid range
    max_conn=$(( max_conn < 10 ? 10 : max_conn ))
    max_conn=$(( max_conn > 125 ? 125 : max_conn ))
    
    log_info "Setting maxconnections=${max_conn}"
    
    # Update configuration
    local config_file="${MEOWCOIN_CONFIG}/meowcoin.conf"
    if [ -f "$config_file" ]; then
        if grep -q "^maxconnections=" "$config_file"; then
            sed -i "s/^maxconnections=.*/maxconnections=${max_conn}/" "$config_file"
        else
            echo "maxconnections=${max_conn}" >> "$config_file"
        fi
    fi
    
    return 0
}

# Configure transaction indexing
configure_txindex() {
    local txindex=${ENABLE_TXINDEX:-1}
    local config_file="${MEOWCOIN_CONFIG}/meowcoin.conf"
    
    # Validate input
    if [ "$txindex" != "0" ] && [ "$txindex" != "1" ]; then
        log_warn "Invalid ENABLE_TXINDEX value: ${txindex}. Using default (1)"
        txindex=1
    fi
    
    log_info "Setting txindex=${txindex}"
    
    # Update configuration
    if [ -f "$config_file" ]; then
        if grep -q "^txindex=" "$config_file"; then
            sed -i "s/^txindex=.*/txindex=${txindex}/" "$config_file"
        else
            echo "txindex=${txindex}" >> "$config_file"
        fi
    fi
    
    return 0
}

# Configure node operation mode
configure_mode() {
    local mode=${MEOWCOIN_MODE:-"full"}
    local config_file="${MEOWCOIN_CONFIG}/meowcoin.conf"
    
    case "$mode" in
        minimal)
            log_info "Configuring for minimal mode (reduced disk usage)"
            # Disable transaction index
            sed -i "s/^txindex=.*/txindex=0/" "$config_file"
            # Enable pruning (keep ~10GB of data)
            if grep -q "^prune=" "$config_file"; then
                sed -i "s/^prune=.*/prune=10000/" "$config_file"
            else
                echo "prune=10000" >> "$config_file"
            fi
            ;;
            
        full|*)
            log_info "Configuring for full node mode"
            # Ensure pruning is disabled
            if grep -q "^prune=" "$config_file"; then
                sed -i "s/^prune=.*/prune=0/" "$config_file"
            else
                echo "prune=0" >> "$config_file"
            fi
            ;;
    esac
    
    return 0
}

# Main configuration function
main() {
    # Ensure configuration directory exists
    mkdir -p "${MEOWCOIN_CONFIG}"
    
    # Apply custom config (creates default if needed)
    apply_custom_config
    
    # Get system memory
    local system_memory=$(get_system_memory)
    
    # Configure based on system resources
    configure_memory "$system_memory"
    configure_connections
    configure_txindex
    configure_mode
    
    log_info "Auto-configuration complete"
    return 0
}

# Run main function
main