#!/bin/bash
set -e

# Source helper functions
source /scripts/functions.sh

log_info "Starting Meowcoin node monitor"

# Create API directory if it doesn't exist
mkdir -p /var/www/html/api
chown meowcoin:meowcoin /var/www/html/api

# Main monitoring loop
while true; do
  # Skip if shutdown flag exists
  if [ -f "${MEOWCOIN_DATA}/.meowcoin/shutdown.flag" ]; then
    log_info "Shutdown flag detected, stopping monitor"
    exit 0
  fi
  
  # Initialize status object
  STATUS="{}"
  
  # Check if daemon is running
  if pgrep -x "meowcoind" > /dev/null; then
    # Get blockchain info
    BLOCKCHAIN_INFO=$(gosu meowcoin meowcoin-cli -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" getblockchaininfo 2>/dev/null || echo "{}")
    NETWORK_INFO=$(gosu meowcoin meowcoin-cli -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" getnetworkinfo 2>/dev/null || echo "{}")
    MINING_INFO=$(gosu meowcoin meowcoin-cli -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" getmininginfo 2>/dev/null || echo "{}")
    
    # Parse blockchain info
    BLOCKS=$(echo "$BLOCKCHAIN_INFO" | jq -r ".blocks // 0")
    HEADERS=$(echo "$BLOCKCHAIN_INFO" | jq -r ".headers // 0")
    VERIFICATION_PROGRESS=$(echo "$BLOCKCHAIN_INFO" | jq -r ".verificationprogress // 0")
    # Use awk for calculation
    PROGRESS_PCT=$(awk "BEGIN { printf \"%.2f\", $VERIFICATION_PROGRESS * 100 }" 2>/dev/null || echo "0.00")
    
    # Parse network info
    VERSION=$(echo "$NETWORK_INFO" | jq -r ".version // \"Unknown\"")
    SUBVERSION=$(echo "$NETWORK_INFO" | jq -r ".subversion // \"Unknown\"")
    CONNECTIONS=$(echo "$NETWORK_INFO" | jq -r ".connections // 0")
    
    # Parse mining info
    DIFFICULTY=$(echo "$MINING_INFO" | jq -r ".difficulty // 0")
    HASHRATE=$(echo "$MINING_INFO" | jq -r ".networkhashps // 0")
    
    # Get latest block time
    if [ "$BLOCKS" -gt 0 ]; then
      BEST_BLOCK_HASH=$(echo "$BLOCKCHAIN_INFO" | jq -r ".bestblockhash // \"\"")
      if [ -n "$BEST_BLOCK_HASH" ]; then
        BLOCK_INFO=$(gosu meowcoin meowcoin-cli -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" getblock "$BEST_BLOCK_HASH" 2>/dev/null || echo "{}")
        LATEST_BLOCK_TIME=$(echo "$BLOCK_INFO" | jq -r ".time // 0")
        TRANSACTIONS=$(echo "$BLOCK_INFO" | jq -r ".tx | length // 0")
      else
        LATEST_BLOCK_TIME=0
        TRANSACTIONS=0
      fi
    else
      LATEST_BLOCK_TIME=0
      TRANSACTIONS=0
    fi
    
    # Determine status
    if [ "$BLOCKS" -lt "$HEADERS" ]; then
      NODE_STATUS="syncing"
    elif [ "$CONNECTIONS" -eq 0 ]; then
      NODE_STATUS="no_connections"
    else
      NODE_STATUS="running"
    fi
    
    # Get system info
    MEM_INFO=$(free -m | grep Mem)
    MEM_TOTAL=$(echo "$MEM_INFO" | awk '{print $2}')
    MEM_USED=$(echo "$MEM_INFO" | awk '{print $3}')
    # Use awk for calculation with validation
    if [ "$MEM_TOTAL" -gt 0 ]; then
      MEM_PERCENT=$(awk "BEGIN { printf \"%.2f\", $MEM_USED * 100 / $MEM_TOTAL }" 2>/dev/null || echo "0.00")
    else
      MEM_PERCENT="0.00"
    fi
    
    # Get disk space info
    DISK_INFO=$(df -h "${MEOWCOIN_DATA}" | tail -n 1)
    DISK_SIZE=$(echo "$DISK_INFO" | awk '{print $2}')
    DISK_USED=$(echo "$DISK_INFO" | awk '{print $3}')
    DISK_PERCENT=$(echo "$DISK_INFO" | awk '{print $5}' | sed 's/%//')
    
    # Create status JSON
    STATUS=$(jq -n \
      --arg status "$NODE_STATUS" \
      --arg blocks "$BLOCKS" \
      --arg headers "$HEADERS" \
      --arg progress "$PROGRESS_PCT" \
      --arg version "$VERSION" \
      --arg subversion "$SUBVERSION" \
      --arg connections "$CONNECTIONS" \
      --arg memused "$MEM_USED" \
      --arg memtotal "$MEM_TOTAL" \
      --arg mempercent "$MEM_PERCENT" \
      --arg disksize "$DISK_SIZE" \
      --arg diskused "$DISK_USED" \
      --arg diskpercent "$DISK_PERCENT" \
      --argjson difficulty "$DIFFICULTY" \
      --argjson hashrate "$HASHRATE" \
      --argjson latestBlockTime "$LATEST_BLOCK_TIME" \
      --argjson transactions "$TRANSACTIONS" \
      --arg time "$(date '+%Y-%m-%d %H:%M:%S')" \
      '{
        "status": $status,
        "blockchain": {
          "blocks": $blocks,
          "headers": $headers,
          "progress": $progress
        },
        "node": {
          "version": $version,
          "subversion": $subversion,
          "connections": $connections
        },
        "network": {
          "difficulty": $difficulty,
          "hashrate": $hashrate,
          "latestBlockTime": $latestBlockTime,
          "transactions": $transactions
        },
        "system": {
          "memory": {
            "used": $memused,
            "total": $memtotal,
            "percent": $mempercent
          },
          "disk": {
            "size": $disksize,
            "used": $diskused,
            "percent": $diskpercent
          }
        },
        "updated": $time
      }')
  else
    # Daemon not running
    STATUS=$(jq -n \
      --arg time "$(date '+%Y-%m-%d %H:%M:%S')" \
      '{
        "status": "stopped",
        "updated": $time
      }')
  fi
  
  # Write status to file
  echo "$STATUS" > /var/www/html/api/status.json
  
  # Sleep for a bit before next update
  sleep 5
done