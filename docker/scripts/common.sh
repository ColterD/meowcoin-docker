#!/bin/bash
# Common functions for Meowcoin Docker scripts

# Logging functions
log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $*"
}

log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $*"
}

log_warning() {
    echo -e "\033[0;33m[WARNING]\033[0m $*" >&2
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $*" >&2
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a port is available
port_is_available() {
    local port=$1
    if command_exists nc; then
        nc -z 127.0.0.1 "$port" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            return 1  # Port is in use
        else
            return 0  # Port is available
        fi
    else
        # Fallback if nc is not available
        if command_exists lsof; then
            lsof -i:"$port" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                return 1  # Port is in use
            else
                return 0  # Port is available
            fi
        else
            # If neither nc nor lsof is available, assume port is available
            log_warning "Cannot check if port $port is available (nc and lsof not found)"
            return 0
        fi
    fi
}

# Function to generate a secure random string
generate_random_string() {
    local length=${1:-32}
    if command_exists openssl; then
        openssl rand -hex $((length/2))
    else
        # Fallback if openssl is not available
        head -c $((length/2)) /dev/urandom | xxd -p
    fi
}

# Function to check if a directory is writable
is_writable() {
    local dir=$1
    if [ -w "$dir" ]; then
        return 0
    else
        return 1
    fi
}

# Function to check if a file exists and is readable
is_readable() {
    local file=$1
    if [ -r "$file" ]; then
        return 0
    else
        return 1
    fi
}

# Function to check if a variable is set
is_set() {
    local var_name=$1
    if [ -z "${!var_name+x}" ]; then
        return 1
    else
        return 0
    fi
}

# Function to get available memory in MB
get_available_memory() {
    if command_exists free; then
        free -m | awk '/^Mem:/ {print $7}'
    else
        # Fallback for systems without free command
        if [ -f /proc/meminfo ]; then
            awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo
        else
            # Default to a conservative value if we can't determine
            echo "1024"
        fi
    fi
}

# Function to get number of CPU cores
get_cpu_cores() {
    if command_exists nproc; then
        nproc
    else
        # Fallback for systems without nproc
        if [ -f /proc/cpuinfo ]; then
            grep -c ^processor /proc/cpuinfo
        else
            # Default to 1 if we can't determine
            echo "1"
        fi
    fi
}

# Function to calculate optimal dbcache based on available memory
calculate_optimal_dbcache() {
    local available_mem=$(get_available_memory)
    local total_mem=$available_mem
    
    # Use 25% of available memory for dbcache, with limits
    local dbcache=$((total_mem / 4))
    
    # Minimum 128MB, maximum 4GB
    if [ $dbcache -lt 128 ]; then
        dbcache=128
    elif [ $dbcache -gt 4096 ]; then
        dbcache=4096
    fi
    
    echo $dbcache
}

# Function to calculate optimal maxmempool based on available memory
calculate_optimal_maxmempool() {
    local available_mem=$(get_available_memory)
    
    # Use 10% of available memory for maxmempool, with limits
    local maxmempool=$((available_mem / 10))
    
    # Minimum 50MB, maximum 1GB
    if [ $maxmempool -lt 50 ]; then
        maxmempool=50
    elif [ $maxmempool -gt 1000 ]; then
        maxmempool=1000
    fi
    
    echo $maxmempool
}

# Function to calculate optimal max connections based on available resources
calculate_optimal_maxconnections() {
    local available_mem=$(get_available_memory)
    local cpu_cores=$(get_cpu_cores)
    
    # Base calculation on memory and CPU cores
    local maxconnections=$((cpu_cores * 10))
    
    # Adjust based on available memory
    if [ $available_mem -lt 1024 ]; then
        # Less than 1GB RAM
        maxconnections=$((maxconnections / 2))
    elif [ $available_mem -gt 8192 ]; then
        # More than 8GB RAM
        maxconnections=$((maxconnections * 2))
    fi
    
    # Minimum 10, maximum 125
    if [ $maxconnections -lt 10 ]; then
        maxconnections=10
    elif [ $maxconnections -gt 125 ]; then
        maxconnections=125
    fi
    
    echo $maxconnections
}