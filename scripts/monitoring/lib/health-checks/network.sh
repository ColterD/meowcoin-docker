#!/bin/bash
# Network status checking

# Check network connectivity
function check_network_connectivity() {
  local NETWORK_OK=true
  local CONNECTIVITY_TEST_HOSTS=("1.1.1.1" "8.8.8.8")
  
  # Test DNS resolution first
  if ! nslookup -timeout=2 google.com >/dev/null 2>&1 && ! nslookup -timeout=2 cloudflare.com >/dev/null 2>&1; then
    log "DNS resolution issues detected"
    NETWORK_OK=false
    send_alert "network_dns" "DNS resolution issues detected" "warning"
  fi
  
  # Test connectivity to important resources
  for HOST in "${CONNECTIVITY_TEST_HOSTS[@]}"; do
    if ! ping -c 1 -W 5 "$HOST" >/dev/null 2>&1; then
      log "Network connectivity issue detected - cannot reach $HOST"
      NETWORK_OK=false
    fi
  done
  
  # Check for internet connectivity via HTTPS
  if command -v curl >/dev/null 2>&1; then
    if ! curl -s --connect-timeout 5 https://www.google.com >/dev/null 2>&1 && \
       ! curl -s --connect-timeout 5 https://www.cloudflare.com >/dev/null 2>&1; then
      log "HTTPS connectivity issues detected"
      NETWORK_OK=false
      send_alert "network_https" "HTTPS connectivity issues detected" "warning"
    fi
  fi
  
  if [ "$NETWORK_OK" = "false" ]; then
    send_alert "network_connectivity" "Network connectivity issues detected" "warning"
  fi
  
  return $([[ "$NETWORK_OK" == "true" ]] && echo 0 || echo 1)
}

# Check network status
function check_network_status() {
  # Check network info
  NETWORK_INFO=$(execute_rpc getnetworkinfo)
  if [ $? -ne 0 ]; then
    log "Cannot get network info from node"
    
    # Write status file
    cat > "$STATUS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "trace_id": "$DISTRIBUTED_TRACE_ID",
  "status": "error",
  "error": "Cannot get network info",
  "check_time": $(date +%s)
}
EOF
    
    send_alert "network_info_error" "Cannot retrieve network information" "warning"
    return 1
  fi
  
  # Extract network data
  CONNECTIONS=$(extract_json_value "$NETWORK_INFO" "connections" "0")
  VERSION=$(extract_json_value "$NETWORK_INFO" "version" "0")
  SUBVERSION=$(extract_json_value "$NETWORK_INFO" "subversion" "unknown")
  PROTOCOL_VERSION=$(extract_json_value "$NETWORK_INFO" "protocolversion" "0")
  
  # Record network metrics
  record_metric "connections" "$CONNECTIONS"
  
  # Get uptime information
  UPTIME_INFO=$(execute_rpc uptime)
  if [ $? -eq 0 ]; then
    record_metric "node_uptime" "$UPTIME_INFO"
  fi
  
  # Analyze connected peers
  if [ $CONNECTIONS -gt 0 ]; then
    # Get detailed peer info
    PEER_INFO=$(execute_rpc getpeerinfo)
    if [ $? -eq 0 ]; then
      # Count inbound vs outbound connections
      if command -v jq >/dev/null 2>&1; then
        INBOUND=$(echo "$PEER_INFO" | jq '[.[] | select(.inbound == true)] | length')
        OUTBOUND=$(echo "$PEER_INFO" | jq '[.[] | select(.inbound == false)] | length')
        
        # Check connection distribution
        record_metric "inbound_connections" "$INBOUND"
        record_metric "outbound_connections" "$OUTBOUND"
        
        if [ $INBOUND -eq 0 ]; then
          log "No inbound connections - check port forwarding"
          send_alert "no_inbound" "No inbound connections - check port forwarding" "warning"
        fi
        
        if [ $OUTBOUND -eq 0 ]; then
          log "No outbound connections - check firewall/network"
          send_alert "no_outbound" "No outbound connections - check firewall/network" "warning"
        fi
        
        # Check for banned peers
        BANNED_INFO=$(execute_rpc listbanned)
        if [ $? -eq 0 ]; then
          BANNED_COUNT=$(echo "$BANNED_INFO" | jq '. | length')
          record_metric "banned_peers" "$BANNED_COUNT"
          
          if [ $BANNED_COUNT -gt 10 ]; then
            log "High number of banned peers: $BANNED_COUNT"
            send_alert "high_banned" "High number of banned peers: $BANNED_COUNT" "warning"
          fi
        fi
      fi
    fi
  fi
  
  return 0
}