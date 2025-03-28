#!/bin/bash
# scripts/utils/run.sh
# Utility script to run Meowcoin Docker container with different profiles

# Usage function
function usage() {
    echo "Usage: $0 {default|monitoring|minimal|debug}"
    exit 1
}

# Parse arguments
if [ $# -lt 1 ]; then
    usage
fi

# Set environment file path
ENV_FILE=".env"

# Handle profiles
case "$1" in
    default)
        echo "Starting container with default profile"
        docker-compose up -d
        ;;
    monitoring)
        echo "Starting container with monitoring profile"
        docker-compose --profile monitoring up -d
        ;;
    minimal)
        echo "Starting container with minimal profile"
        cat > "$ENV_FILE" <<EOF
ENABLE_METRICS=false
ENABLE_BACKUPS=false
ENABLE_FAIL2BAN=false
ENABLE_JWT_AUTH=false
ENABLE_SSL=false
ENABLE_READONLY_FS=false
ENABLE_PLUGINS=false
ENABLE_PRUNING=false
EOF
        docker-compose --env-file "$ENV_FILE" up -d
        ;;
    debug)
        echo "Starting container with debug profile"
        cat > "$ENV_FILE" <<EOF
DEBUG_MODE=true
ENABLE_METRICS=true
ENABLE_BACKUPS=true
ENABLE_FAIL2BAN=true
EOF
        docker-compose --env-file "$ENV_FILE" up -d
        docker exec -it meowcoin-node /usr/local/bin/utils/debug.sh enable
        ;;
    *)
        usage
        ;;
esac

echo "Container started. View logs with: docker-compose logs -f"
exit 0