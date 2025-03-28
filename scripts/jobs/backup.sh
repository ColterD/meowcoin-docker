#!/bin/bash
# Backup job script for Meowcoin Docker

source /usr/local/bin/core/utils.sh
source /usr/local/bin/core/backup.sh

function usage() {
    echo "Usage: $0 {create|verify|cleanup} [secondary]"
    exit 1
}

# Check arguments
if [[ $# -lt 1 ]]; then
    usage
fi

# Initialize backup system
backup_init

# Run requested operation
case "$1" in
    create)
        BACKUP_TYPE="${2:-primary}"
        backup_create "$BACKUP_TYPE"
        ;;
    verify)
        backup_verify
        ;;
    cleanup)
        backup_cleanup
        ;;
    *)
        usage
        ;;
esac

exit $?