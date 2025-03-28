# Troubleshooting

## Common Issues

### Container Won't Start

**Symptoms**: Container exits immediately or keeps restarting

**Potential Solutions**:
1. Check logs: `docker logs meowcoin-node`
2. Verify port availability: `netstat -tuln | grep 8333`
3. Check disk space: `df -h`
4. Verify permissions on mounted volumes

### Node Won't Sync

**Symptoms**: Blockchain height doesn't increase, node reports "catching up"

**Potential Solutions**:
1. Check network connectivity:
   ```bash
   docker exec meowcoin-node meowcoin-cli getnetworkinfo
   ```

2. Verify sufficient connections:
   ```bash
   docker exec meowcoin-node meowcoin-cli getconnectioncount
   ```

3. Verify disk space for blockchain:
   ```bash
   docker exec meowcoin-node df -h
   ```

4. Check for firewall issues blocking port 8333

### RPC Connection Issues

**Symptoms**: Unable to connect to RPC or authentication failures

**Potential Solutions**:
1. Verify RPC credentials:
   ```bash
   docker exec meowcoin-node cat /home/meowcoin/.meowcoin/.rpcpassword
   ```

2. Check RPC configuration:
   ```bash
   docker exec meowcoin-node grep rpc /home/meowcoin/.meowcoin/meowcoin.conf
   ```

3. Verify RPC service is running:
   ```bash
   docker exec meowcoin-node netstat -tulpn | grep 8332
   ```

## Diagnostic Commands

### Node Status

```bash
# Get blockchain info
docker exec meowcoin-node meowcoin-cli getblockchaininfo

# Get network info
docker exec meowcoin-node meowcoin-cli getnetworkinfo

# Get mempool info
docker exec meowcoin-node meowcoin-cli getmempoolinfo

# Get wallet info (if wallet enabled)
docker exec meowcoin-node meowcoin-cli getwalletinfo
```

### Container Health

```bash
# Check container stats
docker stats meowcoin-node

# View container logs
docker logs -f --tail=100 meowcoin-node

# Check container health status
docker inspect --format='{{.State.Health.Status}}' meowcoin-node
```

### Filesystem Issues

```bash
# Check disk usage
docker exec meowcoin-node df -h

# Check for corrupted files
docker exec meowcoin-node meowcoin-cli verifychain

# Check permissions
docker exec meowcoin-node ls -la /home/meowcoin/.meowcoin
```

## Recovery Procedures

### Reset Node

To completely reset the node (will delete blockchain data):

```bash
docker-compose down
docker volume rm meowcoin-data
docker-compose up -d
```

### Repair Database

To attempt blockchain database repair:

```bash
docker-compose down
docker-compose run --rm -e CUSTOM_OPTS="-reindex" meowcoin
```

### Generate Debug Info

Generate a complete debug report:

```bash
docker exec meowcoin-node meowcoin-cli getwalletinfo
docker exec meowcoin-node meowcoin-cli getnetworkinfo
docker exec meowcoin-node meowcoin-cli getblockchaininfo
docker exec meowcoin-node meowcoin-cli getmempoolinfo
docker exec meowcoin-node cat /var/log/meowcoin/setup.log
docker logs meowcoin-node > meowcoin-container.log
```
