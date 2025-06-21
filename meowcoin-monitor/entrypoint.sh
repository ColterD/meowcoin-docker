#!/bin/sh
set -e

echo "🔍 Meowcoin Monitor Starting..."

# --- Configuration ---
MEOWCOIN_RPC_PORT=${MEOWCOIN_RPC_PORT:-9766}
MONITOR_INTERVAL=${MONITOR_INTERVAL:-180}
CREDENTIALS_FILE="/data/.credentials"

# The 'depends_on' in docker-compose handles waiting for the meowcoin-core service
# to be healthy before this container starts.

while true; do
  echo ""
  echo "===================="
  echo "📊 Meowcoin Status"
  echo "⏰ $(date)"
  echo "===================="
  
  if [ -f "$CREDENTIALS_FILE" ]; then
    # Load credentials
    source "$CREDENTIALS_FILE"
    
    # Perform a full, authenticated health check
    JSON_RPC='{"jsonrpc":"1.0","id":"curltext","method":"getblockchaininfo","params":[]}'
    RESPONSE=$(curl -s --user "${RPC_USER}:${RPC_PASSWORD}" --data-binary "${JSON_RPC}" http://meowcoin-core:${MEOWCOIN_RPC_PORT})

    if echo "${RESPONSE}" | jq -e '.error == null' >/dev/null; then
      BLOCKS=$(echo "${RESPONSE}" | jq '.result.blocks')
      HEADERS=$(echo "${RESPONSE}" | jq '.result.headers')
      DIFFICULTY=$(echo "${RESPONSE}" | jq '.result.difficulty')
      
      echo "✅ RPC Server:   ONLINE"
      echo "📦 Version:      $(cat /data/VERSION)"
      echo "🔗 Blocks:       ${BLOCKS}"
      echo "📋 Headers:      ${HEADERS}"
      echo "💪 Difficulty:   ${DIFFICULTY}"
    else
      ERROR_MSG=$(echo "${RESPONSE}" | jq -r '.error.message')
      echo "🟡 RPC Status:   UNHEALTHY or STARTING"
      echo "   Error: ${ERROR_MSG}"
    fi
  else
    echo "🟡 Credentials not found. Waiting for node to generate them..."
  fi
  
  # Show disk usage of the data directory
  if [ -d /data ]; then
    SIZE=$(du -sh /data 2>/dev/null | cut -f1)
    echo "💾 Data Size:    ${SIZE}"
    
    # Show file count in the data directory
    FILES=$(find /data -type f 2>/dev/null | wc -l)
    echo "📁 Files: $FILES"
  fi
  
  echo "===================="
  sleep ${MONITOR_INTERVAL}
done 
