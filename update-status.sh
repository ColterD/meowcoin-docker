#!/bin/bash

# Get node status information
STATUS="Meowcoin Node Status
-------------------
"

# Check if meowcoind is running
if pgrep -x "meowcoind" > /dev/null; then
    STATUS="${STATUS}Status: Running
"
    
    # Try to get blockchain info
    BLOCKCHAIN_INFO=$(su -c "meowcoin-cli -conf=/home/meowcoin/.meowcoin/meowcoin.conf getblockchaininfo 2>/dev/null" meowcoin || echo "{}")
    BLOCKS=$(echo "$BLOCKCHAIN_INFO" | jq -r ".blocks // \"Unknown\"")
    PROGRESS=$(echo "$BLOCKCHAIN_INFO" | jq -r ".verificationprogress // 0")
    PROGRESS=$(echo "$PROGRESS * 100" | bc -l | xargs printf "%.2f" 2>/dev/null || echo "0.00")
    
    # Try to get network info
    NETWORK_INFO=$(su -c "meowcoin-cli -conf=/home/meowcoin/.meowcoin/meowcoin.conf getnetworkinfo 2>/dev/null" meowcoin || echo "{}")
    VERSION=$(echo "$NETWORK_INFO" | jq -r ".version // \"Unknown\"")
    CONNECTIONS=$(echo "$NETWORK_INFO" | jq -r ".connections // \"Unknown\"")
    
    # Add info to status
    STATUS="${STATUS}Blocks: $BLOCKS
Version: $VERSION
Connections: $CONNECTIONS
Sync Progress: $PROGRESS%
"
    
    # Get memory info
    MEM_INFO=$(free -h | grep Mem)
    MEM_TOTAL=$(echo "$MEM_INFO" | awk '{print $2}')
    MEM_USED=$(echo "$MEM_INFO" | awk '{print $3}')
    STATUS="${STATUS}Memory Usage: $MEM_USED / $MEM_TOTAL
"
else
    STATUS="${STATUS}Status: Not Running
"
fi

# Write status to file
echo -e "$STATUS" > /var/www/html/status.txt