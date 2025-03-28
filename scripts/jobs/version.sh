#!/bin/bash
# scripts/jobs/version.sh
# Job script for version management

source /usr/local/bin/core/utils.sh
source /usr/local/bin/core/version.sh

function usage() {
    echo "Usage: $0 {history|rollback}"
    exit 1
}

# Check arguments
if [[ $# -lt 1 ]]; then
    usage
fi

# Initialize version system
version_init

# Run requested operation
case "$1" in
    history)
        cat "$VERSION_HISTORY_FILE"
        ;;
    rollback)
        rollback_version
        ;;
    *)
        usage
        ;;
esac

exit $?