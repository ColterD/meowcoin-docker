#!/bin/bash

# MeowCoin Platform Restore Script
# This script restores backups of the database and blockchain data

set -e

# Check if backup file is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <backup_file>"
  echo "Example: $0 /backups/meowcoin_backup_20250501_120000.tar.gz"
  exit 1
fi

BACKUP_FILE=$1

# Configuration
TEMP_DIR="/tmp/meowcoin_restore"
POSTGRES_CONTAINER="meowcoin-platform_postgres_1"
MEOWCOIN_CONTAINER="meowcoin-platform_meowcoin-node_1"
POSTGRES_USER="postgres"
POSTGRES_PASSWORD="postgres"
DATABASES=("meowcoin_auth" "meowcoin_blockchain" "meowcoin_analytics" "meowcoin_notifications")

# Check if backup file exists
if [ ! -f "${BACKUP_FILE}" ]; then
  echo "Error: Backup file ${BACKUP_FILE} not found"
  exit 1
fi

echo "Starting restore process at $(date)"

# Create temporary directory
mkdir -p ${TEMP_DIR}

# Extract backup archive
echo "Extracting backup archive..."
tar -xzf ${BACKUP_FILE} -C ${TEMP_DIR}

# Get the backup date directory
BACKUP_DATE=$(ls ${TEMP_DIR})

# Restore PostgreSQL databases
echo "Restoring PostgreSQL databases..."
for db in "${DATABASES[@]}"; do
  if [ -f "${TEMP_DIR}/${BACKUP_DATE}/${db}_${BACKUP_DATE}.dump" ]; then
    echo "  Restoring $db..."
    docker cp ${TEMP_DIR}/${BACKUP_DATE}/${db}_${BACKUP_DATE}.dump ${POSTGRES_CONTAINER}:/tmp/
    docker exec ${POSTGRES_CONTAINER} bash -c "pg_restore -U ${POSTGRES_USER} -d ${db} -c -C /tmp/${db}_${BACKUP_DATE}.dump"
    docker exec ${POSTGRES_CONTAINER} rm /tmp/${db}_${BACKUP_DATE}.dump
  else
    echo "  Warning: Backup for $db not found"
  fi
done

# Restore TimescaleDB
echo "Restoring TimescaleDB..."
if [ -f "${TEMP_DIR}/${BACKUP_DATE}/meowcoin_metrics_${BACKUP_DATE}.dump" ]; then
  docker cp ${TEMP_DIR}/${BACKUP_DATE}/meowcoin_metrics_${BACKUP_DATE}.dump ${POSTGRES_CONTAINER}:/tmp/
  docker exec ${POSTGRES_CONTAINER} bash -c "pg_restore -U ${POSTGRES_USER} -d meowcoin_metrics -c -C /tmp/meowcoin_metrics_${BACKUP_DATE}.dump"
  docker exec ${POSTGRES_CONTAINER} rm /tmp/meowcoin_metrics_${BACKUP_DATE}.dump
else
  echo "  Warning: Backup for TimescaleDB not found"
fi

# Restore MeowCoin wallet
echo "Restoring MeowCoin wallet..."
if [ -f "${TEMP_DIR}/${BACKUP_DATE}/wallet_${BACKUP_DATE}.dat" ]; then
  # Stop the MeowCoin node
  echo "  Stopping MeowCoin node..."
  docker exec ${MEOWCOIN_CONTAINER} meowcoin-cli -conf=/etc/meowcoin/meowcoin.conf stop
  sleep 10
  
  # Copy the wallet file
  docker cp ${TEMP_DIR}/${BACKUP_DATE}/wallet_${BACKUP_DATE}.dat ${MEOWCOIN_CONTAINER}:/root/.meowcoin/wallet.dat
  
  # Restart the MeowCoin node
  echo "  Starting MeowCoin node..."
  docker restart ${MEOWCOIN_CONTAINER}
else
  echo "  Warning: Backup for MeowCoin wallet not found"
fi

# Clean up
echo "Cleaning up temporary files..."
rm -rf ${TEMP_DIR}

echo "Restore completed at $(date)"