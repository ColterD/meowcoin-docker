#!/bin/bash
# Immediate backup script for Meowcoin Docker

# Source core libraries
source /usr/local/bin/core/utils.sh
source /usr/local/bin/core/backup.sh

# Initialize backup system
backup_init

# Create backup with timestamp
backup_create "manual"

exit $?