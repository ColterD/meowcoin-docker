#!/bin/bash
# scripts/utils/generate-docs.sh
# Automatically generate documentation for the project

# Source utilities
source /usr/local/bin/core/utils.sh
source /usr/local/bin/core/logging.sh

# Output directory
DOCS_DIR="docs/auto-generated"
CONFIG_TEMPLATE="/etc/meowcoin/templates/meowcoin.conf.template"
ENV_DOCS_FILE="$DOCS_DIR/environment-variables.md"
SCRIPTS_DOCS_FILE="$DOCS_DIR/scripts-reference.md"
API_DOCS_FILE="$DOCS_DIR/api-reference.md"

# Initialize documentation generation
function docs_init() {
    mkdir -p "$DOCS_DIR"
    log_info "Documentation generator initialized" "docs"
    return 0
}

# Generate environment variable documentation
function generate_env_docs() {
    log_info "Generating environment variable documentation" "docs"
    
    # Create header
    cat > "$ENV_DOCS_FILE" <<EOF
# Meowcoin Docker Environment Variables

This document describes all environment variables that can be used to configure the Meowcoin Docker container.

## Core Settings

| Variable | Default | Description |
|----------|---------|-------------|
EOF
    
    # Extract environment variables from template
    grep -o '\${[A-Za-z0-9_]*\(:-[^}]*\)*}' "$CONFIG_TEMPLATE" | sort | uniq | while read -r VAR; do
        # Extract variable name
        VAR_NAME=$(echo "$VAR" | sed -E 's/\$\{([A-Za-z0-9_]*)(:-.*)?}/\1/')
        
        # Extract default value if present
        if echo "$VAR" | grep -q ":-"; then
            DEFAULT=$(echo "$VAR" | sed -E 's/\$\{[A-Za-z0-9_]*:-([^}]*)}/\1/')
        else
            DEFAULT="*Required*"
        fi
        
        # Get description from comments if available
        DESCRIPTION=$(grep -A 1 "$VAR_NAME" "$CONFIG_TEMPLATE" | grep "#" | sed 's/^#//' | tr -d '\n')
        if [ -z "$DESCRIPTION" ]; then
            DESCRIPTION="Configuration for $VAR_NAME"
        fi
        
        # Append to documentation
        echo "| $VAR_NAME | $DEFAULT | $DESCRIPTION |" >> "$ENV_DOCS_FILE"
    done
    
    log_info "Environment variable documentation generated: $ENV_DOCS_FILE" "docs"
    return 0
}

# Generate script reference documentation
function generate_script_docs() {
    log_info "Generating script reference documentation" "docs"
    
    # Create header
    cat > "$SCRIPTS_DOCS_FILE" <<EOF
# Meowcoin Docker Script Reference

This document provides a reference for all scripts included in the Meowcoin Docker container.

EOF
    
    # Find all scripts
    find /usr/local/bin -type f -name "*.sh" | sort | while read -r SCRIPT; do
        # Extract script name
        SCRIPT_NAME=$(basename "$SCRIPT")
        
        # Get description from script header
        DESCRIPTION=$(grep -A 2 "^#" "$SCRIPT" | grep -v "^#!" | head -1 | sed 's/^# //')
        if [ -z "$DESCRIPTION" ]; then
            DESCRIPTION="No description available"
        fi
        
        # Add script to documentation
        echo "## $SCRIPT_NAME" >> "$SCRIPTS_DOCS_FILE"
        echo "" >> "$SCRIPTS_DOCS_FILE"
        echo "**Path:** \`$SCRIPT\`" >> "$SCRIPTS_DOCS_FILE"
        echo "" >> "$SCRIPTS_DOCS_FILE"
        echo "$DESCRIPTION" >> "$SCRIPTS_DOCS_FILE"
        echo "" >> "$SCRIPTS_DOCS_FILE"
        
        # Extract functions
        echo "### Functions" >> "$SCRIPTS_DOCS_FILE"
        echo "" >> "$SCRIPTS_DOCS_FILE"
        grep -E "^function [a-zA-Z0-9_]+" "$SCRIPT" | sed 's/function \(.*\)().*/- \1/' >> "$SCRIPTS_DOCS_FILE"
        echo "" >> "$SCRIPTS_DOCS_FILE"
    done
    
    log_info "Script reference documentation generated: $SCRIPTS_DOCS_FILE" "docs"
    return 0
}

# Generate API reference documentation
function generate_api_docs() {
    log_info "Generating API reference documentation" "docs"
    
    # Create header
    cat > "$API_DOCS_FILE" <<EOF
# Meowcoin API Reference

This document provides a reference for the Meowcoin API endpoints available in the container.

## RPC API

The following RPC commands are available:

EOF
    
    # Get help from meowcoin-cli
    if meowcoin-cli help > /tmp/meowcoin-help 2>/dev/null; then
        # Extract commands and add to documentation
        grep "^  " /tmp/meowcoin-help | while read -r CMD; do
            echo "- \`$CMD\`" >> "$API_DOCS_FILE"
        done
        
        rm /tmp/meowcoin-help
    else
        echo "**Note:** API documentation could not be generated automatically. Please ensure the node is running." >> "$API_DOCS_FILE"
    fi
    
    log_info "API reference documentation generated: $API_DOCS_FILE" "docs"
    return 0
}

# Generate all documentation
function generate_all_docs() {
    docs_init
    generate_env_docs
    generate_script_docs
    generate_api_docs
    
    log_info "All documentation generated successfully" "docs"
    return 0
}

# Run documentation generation
generate_all_docs
exit $?