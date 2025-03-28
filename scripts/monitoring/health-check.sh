#!/bin/bash
# scripts/monitoring/health-check.sh
# Unified health check script using the new library approach

# Source common library functions
source /usr/local/bin/lib/utils.sh
source /usr/local/bin/lib/monitoring.sh

# Main health check function
function main() {
  # Initialize monitoring system
  init_monitoring
  
  # Run health check
  run_health_check
  
  # Return the result
  return $?
}

# Run the main function
main
exit $?