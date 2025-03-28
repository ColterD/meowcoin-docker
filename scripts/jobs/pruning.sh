#!/bin/bash
# scripts/jobs/pruning.sh
# Job script for blockchain pruning

source /usr/local/bin/core/utils.sh
source /usr/local/bin/core/pruning.sh

function usage() {
    echo "Usage: $0 {run|status}"
    exit 1
}

# Check arguments
if [[ $# -lt 1 ]]; then
    usage
fi

# Initialize pruning system
pruning_init

# Run requested operation
case "$1" in
    run)
        run_pruning
        ;;
    status)
        cat "$PRUNING_STATUS_FILE"
        ;;
    *)
        usage
        ;;
esac

exit $?