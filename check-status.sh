#!/bin/bash
echo "=== Meowcoin Status ==="

# Container status
docker ps -a --filter "name=meowcoin"
echo ""

# Quick status from monitor
docker exec meowcoin-monitor cat /tmp/meowcoin-status.txt 2>/dev/null || echo "Status not available"
echo ""

# Recent logs
echo "Recent logs:"
docker logs --tail 10 meowcoin-node