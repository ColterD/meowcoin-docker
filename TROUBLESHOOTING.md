# Troubleshooting Guide

This guide helps you diagnose and fix common issues with the Meowcoin Docker setup.

## Quick Diagnostics

### Check Container Status
```bash
docker compose ps
```

### View Logs
```bash
# Core service logs
docker compose logs -f meowcoin-core

# Monitor service logs
docker compose logs -f meowcoin-monitor

# All logs
docker compose logs -f
```

### Check Status
```bash
# Use the provided status script
./check-status.sh

# Or manually check status
docker exec meowcoin-monitor cat /var/log/meowcoin/meowcoin-status.txt
```

## Common Issues and Solutions

### 1. Container Won't Start

**Symptoms:**
- Container exits immediately
- "Exited (1)" status

**Diagnosis:**
```bash
docker compose logs meowcoin-core
```

**Common Causes & Solutions:**

#### Binary Validation Failed
```
ERROR: Required binary 'meowcoind' not found in PATH
```
**Solution:** Rebuild the image
```bash
docker compose build --no-cache
docker compose up -d
```

#### Permission Issues
```
ERROR: Could not create data directory
```
**Solution:** Check volume permissions
```bash
docker volume inspect meowcoin_data
sudo chown -R 1000:1000 /var/lib/docker/volumes/meowcoin_data/_data
```

### 2. Download Failures

**Symptoms:**
- Build fails during download phase
- "Failed to download Meowcoin Core" error

**Solutions:**

#### Use Specific Version
Edit `docker-compose.yml`:
```yaml
args:
  MEOWCOIN_VERSION: 2.0.5  # Use a specific version
```

#### Check Network Connectivity
```bash
curl -I https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/latest
```

### 3. RPC Connection Issues

**Symptoms:**
- Monitor shows "RPC Server: OFFLINE"
- CLI commands fail

**Diagnosis:**
```bash
# Check if RPC port is listening
docker exec meowcoin-node netstat -tlnp | grep 9766

# Test RPC connection
docker exec meowcoin-core getblockchaininfo
```

**Solutions:**

#### Check Credentials
```bash
docker exec meowcoin-node cat /home/meowcoin/.meowcoin/.credentials
```

#### Verify Configuration
```bash
docker exec meowcoin-node cat /home/meowcoin/.meowcoin/meowcoin.conf
```

#### Restart Services
```bash
docker compose restart
```

### 4. Sync Issues

**Symptoms:**
- Sync progress stuck at 0%
- No peer connections

**Diagnosis:**
```bash
# Check network info
docker exec meowcoin-core getnetworkinfo

# Check peer info
docker exec meowcoin-core getpeerinfo
```

**Solutions:**

#### Check Firewall
Ensure port 8788 is open for P2P connections:
```bash
# On host system
sudo ufw allow 8788
```

#### Add Nodes Manually
```bash
# Add a node manually
docker exec meowcoin-core addnode "node.meowcoin.org:8788" "add"
```

### 5. Resource Issues

**Symptoms:**
- Container killed (OOMKilled)
- Very slow performance

**Solutions:**

#### Increase Memory Limits
Edit `docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      memory: 8G  # Increase from 4G
```

#### Reduce Cache Settings
Set environment variables:
```bash
export MEOWCOIN_DB_CACHE=512
export MEOWCOIN_MAX_MEMPOOL=150
docker compose up -d
```

### 6. Log Issues

**Symptoms:**
- No logs visible
- Log files not found

**Solutions:**

#### Check Log Volume
```bash
docker volume inspect meowcoin_logs
ls -la /var/lib/docker/volumes/meowcoin_logs/_data/
```

#### Access Logs Directly
```bash
# Core logs
docker exec meowcoin-node cat /var/log/meowcoin/meowcoin-core.log

# Monitor logs
docker exec meowcoin-monitor cat /var/log/meowcoin/meowcoin-monitor.log
```

### 7. Network Connectivity Issues

**Symptoms:**
- Monitor can't connect to core
- Services can't communicate

**Diagnosis:**
```bash
# Check network
docker network ls
docker network inspect meowcoin-network

# Test connectivity
docker exec meowcoin-monitor nc -zv meowcoin-core 9766
```

**Solutions:**

#### Recreate Network
```bash
docker compose down
docker network prune
docker compose up -d
```

#### Check DNS Resolution
```bash
docker exec meowcoin-monitor nslookup meowcoin-core
```

## Advanced Debugging

### Enable Debug Mode
```bash
export DEBUG=1
docker compose up -d
```

### Access Container Shell
```bash
# Core container
docker exec -it meowcoin-node bash

# Monitor container
docker exec -it meowcoin-monitor bash
```

### Check System Resources
```bash
# Memory usage
docker stats

# Disk usage
docker system df
```

### Rebuild Everything
```bash
# Complete rebuild
docker compose down -v
docker system prune -a
docker compose build --no-cache
docker compose up -d
```

## Getting Help

If you're still experiencing issues:

1. **Collect Information:**
   ```bash
   # Save all logs
   docker compose logs > meowcoin-logs.txt
   
   # Save system info
   docker version > system-info.txt
   docker compose version >> system-info.txt
   uname -a >> system-info.txt
   ```

2. **Check GitHub Issues:**
   Visit the [GitHub repository](https://github.com/ColterD/meowcoin-docker/issues)

3. **Create a New Issue:**
   Include the collected logs and system information

## Prevention

### Regular Maintenance
```bash
# Update to latest version
docker compose pull
docker compose up -d

# Clean up old images
docker image prune

# Check disk space
df -h
```

### Monitoring
```bash
# Set up log rotation
echo "*/5 * * * * docker exec meowcoin-node logrotate /etc/logrotate.conf" | crontab -

# Monitor resource usage
watch docker stats
```