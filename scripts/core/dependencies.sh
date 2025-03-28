#!/bin/bash
# scripts/core/dependencies.sh
# Dependency management and initialization order

# Source core modules
source /usr/local/bin/core/logging.sh
source /usr/local/bin/core/utils.sh

# Array of modules in dependency order
MODULES=(
    "logging"
    "utils"
    "config"
    "security"
    "monitor"
    "backup"
    "plugins"
)

# Map of module dependencies
declare -A MODULE_DEPS
MODULE_DEPS["logging"]=""
MODULE_DEPS["utils"]="logging"
MODULE_DEPS["config"]="utils logging"
MODULE_DEPS["security"]="utils logging config"
MODULE_DEPS["monitor"]="utils logging config"
MODULE_DEPS["backup"]="utils logging config"
MODULE_DEPS["plugins"]="utils logging config security"

# Map of initialization functions
declare -A INIT_FUNCTIONS
INIT_FUNCTIONS["logging"]="logging_init"
INIT_FUNCTIONS["utils"]="utils_init"
INIT_FUNCTIONS["config"]="config_init"
INIT_FUNCTIONS["security"]="security_init"
INIT_FUNCTIONS["monitor"]="monitor_init"
INIT_FUNCTIONS["backup"]="backup_init"
INIT_FUNCTIONS["plugins"]="plugins_init"

# Map of setup functions
declare -A SETUP_FUNCTIONS
SETUP_FUNCTIONS["logging"]=""
SETUP_FUNCTIONS["utils"]=""
SETUP_FUNCTIONS["config"]="setup_environment"
SETUP_FUNCTIONS["security"]="security_setup"
SETUP_FUNCTIONS["monitor"]="monitor_setup"
SETUP_FUNCTIONS["backup"]="backup_setup"
SETUP_FUNCTIONS["plugins"]="plugins_setup"

# Track module initialization status
declare -A MODULE_INITIALIZED
for module in "${MODULES[@]}"; do
    MODULE_INITIALIZED["$module"]=false
done

# Initialize all modules in dependency order
function initialize_all_modules() {
    for module in "${MODULES[@]}"; do
        initialize_module "$module"
    done
    
    return 0
}

# Initialize a specific module and its dependencies
function initialize_module() {
    local module="$1"
    
    # Check if already initialized
    if [ "${MODULE_INITIALIZED[$module]}" = "true" ]; then
        return 0
    fi
    
    log_info "Initializing module: $module" "dependencies"
    
    # Initialize dependencies first
    local deps="${MODULE_DEPS[$module]}"
    if [ ! -z "$deps" ]; then
        for dep in $deps; do
            initialize_module "$dep"
        done
    fi
    
    # Source the module if not already sourced
    local module_file="/usr/local/bin/core/${module}.sh"
    if [ -f "$module_file" ] && ! type "${INIT_FUNCTIONS[$module]}" >/dev/null 2>&1; then
        log_debug "Sourcing module: $module" "dependencies"
        source "$module_file"
    fi
    
    # Initialize the module
    local init_function="${INIT_FUNCTIONS[$module]}"
    if [ ! -z "$init_function" ] && type "$init_function" >/dev/null 2>&1; then
        log_debug "Calling initialization function: $init_function" "dependencies"
        "$init_function"
    fi
    
    # Mark as initialized
    MODULE_INITIALIZED["$module"]=true
    log_info "Module initialized: $module" "dependencies"
    
    return 0
}

# Set up all modules in dependency order
function setup_all_modules() {
    for module in "${MODULES[@]}"; do
        setup_module "$module"
    done
    
    return 0
}

# Set up a specific module
function setup_module() {
    local module="$1"
    
    # Ensure module is initialized
    if [ "${MODULE_INITIALIZED[$module]}" != "true" ]; then
        initialize_module "$module"
    fi
    
    # Call setup function if it exists
    local setup_function="${SETUP_FUNCTIONS[$module]}"
    if [ ! -z "$setup_function" ] && type "$setup_function" >/dev/null 2>&1; then
        log_info "Setting up module: $module" "dependencies"
        "$setup_function"
    fi
    
    return 0
}

# Export functions
export -f initialize_all_modules initialize_module setup_all_modules setup_module