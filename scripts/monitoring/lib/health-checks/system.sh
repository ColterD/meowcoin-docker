#!/bin/bash
# System resource checking

# Check system resources
function check_system_resources() {
  if [ "$RESOURCE_CHECK_ENABLED" != "true" ]; then
    return 0
  fi
  
  # Check disk space
  check_disk_space
  
  # Check CPU usage
  check_cpu_usage
  
  # Check memory usage
  check_memory_usage
  
  # Check disk I/O
  check_disk_io
  
  # Check log file for error patterns
  check_log_errors
  
  return 0
}

# Check disk space
function check_disk_space() {
  if [ "$CHECK_DISK_SPACE" = "true" ]; then
    AVAILABLE_SPACE_KB=$(df -k /home/meowcoin/.meowcoin | tail -1 | awk '{print $4}')
    AVAILABLE_SPACE_GB=$((AVAILABLE_SPACE_KB / 1024 / 1024))
    TOTAL_SPACE_KB=$(df -k /home/meowcoin/.meowcoin | tail -1 | awk '{print $2}')
    TOTAL_SPACE_GB=$((TOTAL_SPACE_KB / 1024 / 1024))
    USED_SPACE_KB=$((TOTAL_SPACE_KB - AVAILABLE_SPACE_KB))
    DISK_USAGE_PCT=$((USED_SPACE_KB * 100 / TOTAL_SPACE_KB))
    
    # Record metrics
    record_metric "disk_usage" "$DISK_USAGE_PCT"
    record_metric "disk_available_gb" "$AVAILABLE_SPACE_GB"
    record_metric "disk_total_gb" "$TOTAL_SPACE_GB"
    
    if [ $AVAILABLE_SPACE_GB -lt $MIN_FREE_SPACE_GB ]; then
      log "Low disk space: ${AVAILABLE_SPACE_GB}GB available (minimum: ${MIN_FREE_SPACE_GB}GB)"
      send_alert "low_disk_space" "Low disk space: ${AVAILABLE_SPACE_GB}GB available (minimum: ${MIN_FREE_SPACE_GB}GB)" "warning"
      return 1
    fi
    
    # Check inode usage too (can be a hidden problem)
    INODE_USAGE_PCT=$(df -i /home/meowcoin/.meowcoin | tail -1 | awk '{print $5}' | tr -d '%')
    record_metric "inode_usage" "$INODE_USAGE_PCT"
    
    if [ $INODE_USAGE_PCT -gt 90 ]; then
      log "High inode usage: ${INODE_USAGE_PCT}% (can prevent new file creation)"
      send_alert "high_inode_usage" "High inode usage: ${INODE_USAGE_PCT}% (can prevent new file creation)" "warning"
      return 1
    fi
  fi
  
  return 0
}

# Check CPU usage
function check_cpu_usage() {
  if command -v top >/dev/null 2>&1; then
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    record_metric "cpu_usage" "$CPU_USAGE"
    
    if [ $(echo "$CPU_USAGE > $MAX_CPU_USAGE" | bc -l) -eq 1 ]; then
      log "High CPU usage: ${CPU_USAGE}% (threshold: ${MAX_CPU_USAGE}%)"
      send_alert "high_cpu" "High CPU usage: ${CPU_USAGE}% (threshold: ${MAX_CPU_USAGE}%)" "warning"
      return 1
    fi
  fi
  
  return 0
}

# Check memory usage
function check_memory_usage() {
  if command -v free >/dev/null 2>&1; then
    MEMORY_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    record_metric "memory_usage" "$MEMORY_USAGE"
    
    if [ $(echo "$MEMORY_USAGE > $MAX_MEMORY_USAGE" | bc -l) -eq 1 ]; then
      log "High memory usage: ${MEMORY_USAGE}% (threshold: ${MAX_MEMORY_USAGE}%)"
      send_alert "high_memory" "High memory usage: ${MEMORY_USAGE}% (threshold: ${MAX_MEMORY_USAGE}%)" "warning"
      return 1
    fi
  fi
  
  return 0
}

# Check disk I/O
function check_disk_io() {
  if command -v iostat >/dev/null 2>&1; then
    DISK_IO=$(iostat -x | grep -A 1 "avg-cpu" | tail -1 | awk '{print $14}')
    record_metric "disk_io" "$DISK_IO"
    
    if [ $(echo "$DISK_IO > $DISK_IO_THRESHOLD" | bc -l) -eq 1 ]; then
      log "High disk I/O utilization: ${DISK_IO}% (threshold: ${DISK_IO_THRESHOLD}%)"
      send_alert "high_disk_io" "High disk I/O: ${DISK_IO}% (threshold: ${DISK_IO_THRESHOLD}%)" "warning"
      return 1
    fi
  fi
  
  return 0
}

# Check for errors in log file
function check_log_errors() {
  if [ -f "/home/meowcoin/.meowcoin/debug.log" ]; then
    # Check last 100 lines for critical errors
    ERROR_COUNT=$(tail -n 100 "/home/meowcoin/.meowcoin/debug.log" | grep -c -E "ERROR:|EXCEPTION:|core dumped|segmentation fault|fatal error")
    if [ $ERROR_COUNT -gt 0 ]; then
      log "Found $ERROR_COUNT error(s) in recent log entries"
      
      # Extract last error for alert
      LAST_ERROR=$(tail -n 100 "/home/meowcoin/.meowcoin/debug.log" | grep -E "ERROR:|EXCEPTION:|core dumped|segmentation fault|fatal error" | tail -1)
      send_alert "log_errors" "Found errors in logs: $LAST_ERROR" "warning"
      return 1
    fi
  fi
  
  return 0
}