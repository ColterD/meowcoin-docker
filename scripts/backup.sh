#!/bin/bash

# MeowCoin Platform Backup Script
# This script creates backups of the database and blockchain data

set -e

# Configuration
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
POSTGRES_CONTAINER="meowcoin-platform_postgres_1"
MEOWCOIN_CONTAINER="meowcoin-platform_meowcoin-node_1"
POSTGRES_USER="postgres"
POSTGRES_PASSWORD="postgres"
DATABASES=("meowcoin_auth" "meowcoin_blockchain" "meowcoin_analytics" "meowcoin_notifications")

# Create backup directory if it doesn't exist
mkdir -p ${BACKUP_DIR}
mkdir -p ${BACKUP_DIR}/${DATE}

echo "Starting backup process at $(date)"

# Backup PostgreSQL databases
echo "Backing up PostgreSQL databases..."
for db in "${DATABASES[@]}"; do
  echo "  Backing up $db..."
  docker exec ${POSTGRES_CONTAINER} pg_dump -U ${POSTGRES_USER} -d ${db} -F c -f /tmp/${db}_${DATE}.dump
  docker cp ${POSTGRES_CONTAINER}:/tmp/${db}_${DATE}.dump ${BACKUP_DIR}/${DATE}/
  docker exec ${POSTGRES_CONTAINER} rm /tmp/${db}_${DATE}.dump
done

# Backup TimescaleDB
echo "Backing up TimescaleDB..."
docker exec ${POSTGRES_CONTAINER} pg_dump -U ${POSTGRES_USER} -d meowcoin_metrics -F c -f /tmp/meowcoin_metrics_${DATE}.dump
docker cp ${POSTGRES_CONTAINER}:/tmp/meowcoin_metrics_${DATE}.dump ${BACKUP_DIR}/${DATE}/
docker exec ${POSTGRES_CONTAINER} rm /tmp/meowcoin_metrics_${DATE}.dump

# Backup MeowCoin blockchain data
echo "Backing up MeowCoin blockchain data..."
docker exec ${MEOWCOIN_CONTAINER} meowcoin-cli -conf=/etc/meowcoin/meowcoin.conf backupwallet /tmp/wallet_${DATE}.dat
docker cp ${MEOWCOIN_CONTAINER}:/tmp/wallet_${DATE}.dat ${BACKUP_DIR}/${DATE}/
docker exec ${MEOWCOIN_CONTAINER} rm /tmp/wallet_${DATE}.dat

# Create a tar archive of all backups
echo "Creating archive of all backups..."
tar -czf ${BACKUP_DIR}/meowcoin_backup_${DATE}.tar.gz -C ${BACKUP_DIR} ${DATE}

# Clean up
echo "Cleaning up temporary files..."
rm -rf ${BACKUP_DIR}/${DATE}

# Keep only the last 7 backups
echo "Removing old backups..."
ls -t ${BACKUP_DIR}/meowcoin_backup_*.tar.gz | tail -n +8 | xargs -r rm

echo "Backup completed at $(date)"
echo "Backup saved to ${BACKUP_DIR}/meowcoin_backup_${DATE}.tar.gz"