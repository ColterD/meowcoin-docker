#!/bin/bash
set -e

# Source helper functions
source /scripts/functions.sh

# Check if Meowcoin daemon is running
if ! pgrep -x "meowcoind" > /dev/null; then
  log_error "Meowcoin daemon is not running"
  exit 1
fi

# Check if Meowcoin daemon is responsive
if ! timeout 5 gosu meowcoin meowcoin-cli -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" getblockchaininfo > /dev/null 2>&1; then
  log_error "Meowcoin daemon is not responsive"
  exit 1
fi

# Check if web server is running
if ! pgrep -x "nginx" > /dev/null; then
  log_error "Web server is not running"
  exit 1
fi

# Check disk space
DISK_USAGE=$(df -h "${MEOWCOIN_DATA}" | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "${DISK_USAGE}" -gt 95 ]; then
  log_error "Disk usage is critically high: ${DISK_USAGE}%"
  exit 1
fi

# All checks passed
exit 0