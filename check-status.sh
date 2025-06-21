#!/bin/bash
# This script checks the status of the meowcoin containers and displays their logs

echo "=== Meowcoin Docker Status Check ==="
echo "Date: $(date)"
echo ""

# Check if containers are running
echo "=== Container Status ==="
docker ps -a --filter "name=meowcoin"
echo ""

# Check logs
echo "=== Meowcoin Core Logs ==="
if [ -f "/var/lib/docker/volumes/meowcoin_logs/_data/meowcoin-core.log" ]; then
    tail -n 20 "/var/lib/docker/volumes/meowcoin_logs/_data/meowcoin-core.log"
else
    echo "Log file not found. Try running: docker exec meowcoin-node cat /var/log/meowcoin/meowcoin-core.log"
fi
echo ""

echo "=== Meowcoin Monitor Logs ==="
if [ -f "/var/lib/docker/volumes/meowcoin_logs/_data/meowcoin-monitor.log" ]; then
    tail -n 20 "/var/lib/docker/volumes/meowcoin_logs/_data/meowcoin-monitor.log"
else
    echo "Log file not found. Try running: docker exec meowcoin-monitor cat /var/log/meowcoin/meowcoin-monitor.log"
fi
echo ""

echo "=== Meowcoin Status ==="
if [ -f "/var/lib/docker/volumes/meowcoin_logs/_data/meowcoin-status.txt" ]; then
    cat "/var/lib/docker/volumes/meowcoin_logs/_data/meowcoin-status.txt"
else
    echo "Status file not found. Try running: docker exec meowcoin-monitor cat /var/log/meowcoin/meowcoin-status.txt"
fi
echo ""

# Check network connectivity
echo "=== Network Connectivity ==="
echo "Trying to connect from host to meowcoin-core RPC port:"
nc -zv meowcoin-node 9766 || echo "Failed to connect to meowcoin-node:9766"
echo ""

# Check volume contents
echo "=== Volume Contents ==="
echo "meowcoin_logs volume:"
ls -la /var/lib/docker/volumes/meowcoin_logs/_data/ || echo "Cannot access volume directory"
echo ""

echo "=== End of Status Check ==="