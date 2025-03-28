#!/bin/bash
# Blockchain status checking

# Check blockchain status
function check_blockchain_status() {
  # Check blockchain info
  BLOCKCHAIN_INFO=$(execute_rpc getblockchaininfo)
  if [ $? -ne 0 ]; then
    log "Cannot get blockchain info from node"
    
    # Check for specific RPC issues
    if execute_rpc -getinfo 2>&1 | grep -q "Connection refused"; then
      log "RPC connection refused - check if RPC server is running and accessible"
      send_alert "rpc_connection" "RPC connection refused" "critical"
    elif execute_rpc -getinfo 2>&1 | grep -q "incorrect password"; then
      log "RPC authentication failed - check credentials"
      send_alert "rpc_auth" "RPC authentication failed" "critical"
    else
      log "Unknown RPC error, node may be starting or under heavy load"
      send_alert "rpc_error" "Cannot connect to RPC API" "critical"
    fi
    
    # Write status file
    cat > "$STATUS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "trace_id": "$DISTRIBUTED_TRACE_ID",
  "status": "error",
  "error": "Cannot connect to RPC",
  "check_time": $(date +%s)
}
EOF
    
    return 1
  fi
  
  # Extract blockchain data
  BLOCKS=$(extract_json_value "$BLOCKCHAIN_INFO" "blocks" "0")
  HEADERS=$(extract_json_value "$BLOCKCHAIN_INFO" "headers" "0")
  VERIFICATION_PROGRESS=$(extract_json_value "$BLOCKCHAIN_INFO" "verificationprogress" "0")
  CHAIN=$(extract_json_value "$BLOCKCHAIN_INFO" "chain" "unknown")
  
  # Calculate blocks behind
  BLOCKS_BEHIND=$((HEADERS - BLOCKS))
  
  # Check mempool info
  MEMPOOL_INFO=$(execute_rpc getmempoolinfo)
  if [ $? -ne 0 ]; then
    log "Cannot get mempool info from node"
    
    # Write status file
    cat > "$STATUS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "trace_id": "$DISTRIBUTED_TRACE_ID",
  "status": "error",
  "error": "Cannot get mempool info",
  "check_time": $(date +%s)
}
EOF
    
    send_alert "mempool_info_error" "Cannot retrieve mempool information" "warning"
    return 1
  fi
  
  # Extract mempool data
  MEMPOOL_SIZE=$(extract_json_value "$MEMPOOL_INFO" "size" "0")
  MEMPOOL_BYTES=$(extract_json_value "$MEMPOOL_INFO" "bytes" "0")
  MEMPOOL_USAGE=$(extract_json_value "$MEMPOOL_INFO" "usage" "0")
  MEMPOOL_MAX_MEM=$(extract_json_value "$MEMPOOL_INFO" "maxmempool" "300000000")
  
  # Record all core metrics
  record_metric "blocks" "$BLOCKS"
  record_metric "headers" "$HEADERS"
  record_metric "blocks_behind" "$BLOCKS_BEHIND"
  record_metric "mempool_size" "$MEMPOOL_SIZE"
  record_metric "mempool_bytes" "$MEMPOOL_BYTES"
  record_metric "verification_progress" "$VERIFICATION_PROGRESS"
  record_metric "mempool_usage" "$MEMPOOL_USAGE"
  
  # Check for stalled sync validation
      if [ -f "/tmp/meowcoin_last_verification" ]; then
        LAST_VERIFICATION=$(cat /tmp/meowcoin_last_verification)
        if (( $(echo "$VERIFICATION_PROGRESS - $LAST_VERIFICATION < 0.0001" | bc -l) )); then
          log "Verification progress also stalled"
          send_alert "sync_frozen" "Blockchain verification appears frozen" "critical"
        fi
      fi
    fi
    
    # Update last check time and values
    echo "$CURRENT_TIME" > /tmp/meowcoin_last_check_time
    echo "$VERIFICATION_PROGRESS" > /tmp/meowcoin_last_verification
  fi
  
  # Update last block
  echo "$BLOCKS" > /tmp/meowcoin_last_block
  
  return 0
}