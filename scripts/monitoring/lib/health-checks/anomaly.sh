#!/bin/bash
# Anomaly detection for metrics

# Function to detect traditional anomalies using standard deviation
function detect_anomaly() {
  local METRIC_NAME="$1"
  local CURRENT_VALUE="$2"
  local THRESHOLD="$3"
  local HISTORY_FILE="$HISTORICAL_DATA/${METRIC_NAME}.data"
  
  # Need at least 10 data points for anomaly detection
  if [ ! -f "$HISTORY_FILE" ] || [ $(wc -l < "$HISTORY_FILE") -lt 10 ]; then
    return 1  # Not enough data
  fi
  
  # Calculate mean and standard deviation
  local MEAN=$(awk '{sum+=$2} END {print sum/NR}' "$HISTORY_FILE")
  local STDDEV=$(awk -v mean=$MEAN '{sum+=($2-mean)^2} END {print sqrt(sum/NR)}' "$HISTORY_FILE")
  
  # Check for division by zero or very small stddev
  if [ $(echo "$STDDEV < 0.0001" | bc -l) -eq 1 ]; then
    return 1  # Can't reliably detect anomalies with near-zero variance
  fi
  
  # Calculate z-score (number of std devs from mean)
  local ZSCORE=$(echo "scale=2; ($CURRENT_VALUE - $MEAN) / $STDDEV" | bc -l)
  
  # Record the z-score
  record_metric "${METRIC_NAME}_zscore" "$ZSCORE" "gauge"
  
  # Check if value is anomalous (beyond threshold standard deviations)
  if (( $(echo "sqrt($ZSCORE * $ZSCORE) > $THRESHOLD" | bc -l) )); then
    log "ANOMALY DETECTED: $METRIC_NAME current=$CURRENT_VALUE mean=$MEAN stddev=$STDDEV zscore=$ZSCORE"
    return 0  # Anomaly detected
  fi
  
  return 1  # No anomaly
}

# Function to detect trend anomalies
function detect_trend_anomaly() {
  local METRIC_NAME="$1"
  local HISTORY_FILE="$HISTORICAL_DATA/${METRIC_NAME}.data"
  
  # Need at least 10 data points
  if [ ! -f "$HISTORY_FILE" ] || [ $(wc -l < "$HISTORY_FILE") -lt 10 ]; then
    return 1
  fi
  
  # Get last 10 measurements
  local RECENT_DATA=$(tail -n 10 "$HISTORY_FILE")
  
  # Calculate trend using linear regression slope
  local SLOPE=$(echo "$RECENT_DATA" | awk '
    BEGIN { x_sum=0; y_sum=0; xy_sum=0; x2_sum=0; n=0; }
    { 
      x[n] = n+1; 
      y[n] = $2; 
      x_sum += x[n]; 
      y_sum += y[n]; 
      xy_sum += x[n]*y[n]; 
      x2_sum += x[n]*x[n];
      n++;
    } 
    END {
      slope = (n*xy_sum - x_sum*y_sum) / (n*x2_sum - x_sum*x_sum);
      print slope;
    }')
  
  # Normalize slope based on mean value to get percent change
  local MEAN=$(echo "$RECENT_DATA" | awk '{sum+=$2} END {print sum/NR}')
  local PERCENT_CHANGE=$(echo "scale=2; $SLOPE * 10 / $MEAN * 100" | bc -l)
  
  # Record the trend data
  record_metric "${METRIC_NAME}_trend" "$PERCENT_CHANGE" "gauge"
  
  # Detect significant trends (configurable thresholds)
  local TREND_THRESHOLD="${TREND_THRESHOLD:-5}"  # Default 5% change over 10 points
  
  if (( $(echo "sqrt($PERCENT_CHANGE * $PERCENT_CHANGE) > $TREND_THRESHOLD" | bc -l) )); then
    local DIRECTION=$([ $(echo "$PERCENT_CHANGE > 0" | bc -l) -eq 1 ] && echo "increasing" || echo "decreasing")
    log "TREND ANOMALY: $METRIC_NAME showing significant $DIRECTION trend ($PERCENT_CHANGE% per 10 points)"
    return 0  # Trend anomaly detected
  fi
  
  return 1  # No trend anomaly
}

# Main function to run anomaly detection on all metrics
function run_anomaly_detection() {
  if [ "$ANOMALY_DETECTION_ENABLED" != "true" ]; then
    return 0
  fi
  
  log "Running anomaly detection"
  
  # Check for unusual peer count change
  if detect_anomaly "connections" "$CONNECTIONS" "3.0"; then
    log "Unusual change in peer connections detected"
    send_alert "peer_anomaly" "Unusual change in peer connections detected: $CONNECTIONS" "warning"
  fi
  
  # Check for unusual mempool growth
  if detect_anomaly "mempool_size" "$MEMPOOL_SIZE" "3.0"; then
    log "Unusual mempool growth detected"
    send_alert "mempool_anomaly" "Unusual mempool growth detected: $MEMPOOL_SIZE transactions" "warning"
  fi
  
  # Check for unusual disk usage growth
  if detect_anomaly "disk_usage" "$DISK_USAGE_PCT" "2.0"; then
    log "Unusual disk usage growth detected"
    send_alert "disk_anomaly" "Unusual disk usage growth detected: ${DISK_USAGE_PCT}%" "warning"
  fi
  
  # Check for CPU anomalies
  if detect_anomaly "cpu_usage" "$CPU_USAGE" "2.5"; then
    log "Unusual CPU usage pattern detected"
    send_alert "cpu_anomaly" "Unusual CPU usage pattern detected: ${CPU_USAGE}%" "warning"
  fi
  
  # Check for memory anomalies
  if detect_anomaly "memory_usage" "$MEMORY_USAGE" "2.5"; then
    log "Unusual memory usage pattern detected"
    send_alert "memory_anomaly" "Unusual memory usage pattern detected: ${MEMORY_USAGE}%" "warning"
  fi
  
  # Look for trend anomalies
  if detect_trend_anomaly "disk_usage"; then
    log "Disk usage showing significant trend"
    send_alert "disk_trend" "Disk usage showing significant trend" "warning"
  fi
  
  if detect_trend_anomaly "cpu_usage"; then
    log "CPU usage showing significant trend"
    send_alert "cpu_trend" "CPU usage showing significant trend" "warning"
  fi
  
  return 0
}