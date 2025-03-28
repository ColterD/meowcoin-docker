#!/bin/bash
# Security check script for Meowcoin Docker

source /usr/local/bin/core/utils.sh
source /usr/local/bin/core/security.sh

function usage() {
    echo "Usage: $0 {certificates|integrity|permissions|all}"
    exit 1
}

# Check arguments
if [[ $# -lt 1 ]]; then
    usage
fi

# Initialize security system
security_init

# Run requested check
case "$1" in
    certificates)
        security_check_certificates
        ;;
    integrity)
        security_check_integrity
        ;;
    permissions)
        security_check_permissions
        ;;
    all)
        security_check_certificates
        security_check_integrity
        security_check_permissions
        ;;
    *)
        usage
        ;;
esac

exit $?