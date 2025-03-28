#!/bin/bash
# tests/integration/node_lifecycle_test.sh
# Integration test for Meowcoin Docker node lifecycle

set -e

# Configuration
CONTAINER_NAME="meowcoin-test"
COMPOSE_FILE="docker-compose.yml"
TEST_LOG="integration_test_$(date +%Y%m%d_%H%M%S).log"
TIMEOUT=300  # Max time to wait for node initialization

# Utility functions
log() {
  echo "[$(date -Iseconds)] $1" | tee -a $TEST_LOG
}

fail() {
  log "ERROR: $1"
  exit 1
}

wait_for_condition() {
  local condition="$1"
  local message="$2"
  local timeout="$3"
  local interval="${4:-5}"
  local elapsed=0
  
  log "Waiting for: $message (max $timeout seconds)"
  
  while ! eval "$condition"; do
    elapsed=$((elapsed + interval))
    if [ $elapsed -ge $timeout ]; then
      fail "Timeout waiting for: $message"
    fi
    log "Still waiting... ($elapsed seconds elapsed)"
    sleep $interval
  done
  
  log "Condition met after $elapsed seconds: $message"
}

# Create test log
log "Starting integration test for Meowcoin Docker node"

# Check for docker and docker-compose
if ! command -v docker >/dev/null 2>&1; then
  fail "Docker is not installed"
fi

if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
  fail "Docker Compose is not installed"
fi

# Use appropriate docker-compose command
if command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
else
  COMPOSE_CMD="docker compose"
fi

# Check for compose file
if [ ! -f "$COMPOSE_FILE" ]; then
  fail "Docker Compose file not found: $COMPOSE_FILE"
fi

# Clean up any previous test containers
log "Cleaning up any previous test containers"
$COMPOSE_CMD -f $COMPOSE_FILE down 2>/dev/null || true
docker rm -f $CONTAINER_NAME 2>/dev/null || true

# Start container
log "Starting container using $COMPOSE_FILE"
$COMPOSE_CMD -f $COMPOSE_FILE up -d || fail "Failed to start container"

# Wait for container to start
wait_for_condition \
  "docker ps | grep -q $CONTAINER_NAME" \
  "Container to be running" \
  60 5

# Get container info
log "Container is running, getting container info"
CONTAINER_ID=$(docker ps | grep $CONTAINER_NAME | awk '{print $1}')
log "Container ID: $CONTAINER_ID"

# Wait for node initialization
log "Waiting for node initialization"
wait_for_condition \
  "docker logs $CONTAINER_NAME 2>&1 | grep -q 'Meowcoin Core starting'" \
  "Node initialization" \
  $TIMEOUT 10

# Test RPC connectivity
log "Testing RPC connectivity"
wait_for_condition \
  "docker exec $CONTAINER_NAME meowcoin-cli getblockchaininfo >/dev/null 2>&1" \
  "RPC connection" \
  60 5

# Get blockchain info
log "Getting blockchain info"
docker exec $CONTAINER_NAME meowcoin-cli getblockchaininfo > blockchain_info.json || fail "Failed to get blockchain info"
log "Blockchain info retrieved successfully"

# Test network info
log "Testing network info"
docker exec $CONTAINER_NAME meowcoin-cli getnetworkinfo > network_info.json || fail "Failed to get network info"
log "Network info retrieved successfully"

# If monitoring is enabled, check metrics endpoint
if grep -q "ENABLE_METRICS=true" $COMPOSE_FILE; then
  log "Testing monitoring endpoint"
  wait_for_condition \
    "docker exec $CONTAINER_NAME curl -s http://localhost:9449/metrics | grep -q meowcoin" \
    "Metrics endpoint" \
    60 5
  log "Metrics endpoint is working"
fi

# Test backup script
log "Testing backup functionality"
docker exec $CONTAINER_NAME /usr/local/bin/backup/backup-blockchain.sh || fail "Backup failed"
wait_for_condition \
  "docker exec $CONTAINER_NAME ls -la /home/meowcoin/.meowcoin/backups/ | grep -q tar.gz" \
  "Backup file creation" \
  60 5
log "Backup completed successfully"

# Test health check script
log "Testing health check"
docker exec $CONTAINER_NAME /usr/local/bin/monitoring/health-check.sh || log "Health check reported issues"
wait_for_condition \
  "docker exec $CONTAINER_NAME cat /tmp/meowcoin_health_status.json | grep -q 'status'" \
  "Health status file" \
  30 5
log "Health check executed"

# Check configuration validation
log "Testing configuration validation"
docker exec $CONTAINER_NAME bash -c "RPC_BIND=127.0.0.1 /usr/local/bin/entrypoint/config.sh validate" || log "Configuration validation reported issues"
log "Configuration validation executed"

# Test security checks
log "Testing security scripts"
docker exec $CONTAINER_NAME /usr/local/bin/security/check-integrity.sh || log "Security integrity check reported issues"
docker exec $CONTAINER_NAME /usr/local/bin/security/check-permissions.sh || log "Permission check reported issues"
log "Security checks executed"

# Test graceful shutdown
log "Testing graceful shutdown"
$COMPOSE_CMD -f $COMPOSE_FILE stop || fail "Failed to stop container"
wait_for_condition \
  "! docker ps | grep -q $CONTAINER_NAME" \
  "Container to stop" \
  60 5
log "Container stopped gracefully"

# Start container again to test restart
log "Testing container restart"
$COMPOSE_CMD -f $COMPOSE_FILE start || fail "Failed to restart container"
wait_for_condition \
  "docker ps | grep -q $CONTAINER_NAME" \
  "Container to restart" \
  60 5
log "Container restarted successfully"

# Test service removal
log "Testing service removal"
$COMPOSE_CMD -f $COMPOSE_FILE down || fail "Failed to remove service"
wait_for_condition \
  "! docker ps -a | grep -q $CONTAINER_NAME" \
  "Service to be removed" \
  60 5
log "Service removed successfully"

# Clean up remaining files
log "Cleaning up test files"
rm -f blockchain_info.json network_info.json || true

log "Integration test completed successfully"
exit 0