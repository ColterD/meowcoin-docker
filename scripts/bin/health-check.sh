#!/bin/bash
# scripts/bin/health-check.sh
# Health check script for Meowcoin Docker

# Source core libraries
source /usr/local/bin/core/utils.sh
source /usr/local/bin/core/monitor.sh

# Run health check
run_health_check

# Return the result
exit $?