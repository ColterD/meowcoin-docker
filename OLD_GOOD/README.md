# Meowcoin Node Docker

A fully automated, secure Docker solution for running a Meowcoin node. This image automatically updates whenever new Meowcoin Core versions are released.

---

## Quick Start

```bash
# Pull and run the container
docker-compose up -d
```

That's it! Your Meowcoin node is now running with automatically generated secure credentials.

---

## Security Features

- Auto-generated credentials: Secure RPC credentials are generated automatically
- Local-only RPC: RPC interface is only exposed to localhost by default
- Secure defaults: Safe configuration out of the box
- Non-root execution: Container runs with limited user permissions
- Password persistence: Generated passwords are stored in the volume for reuse
- Optional fail2ban protection: Ban IPs that attempt to brute force RPC
- Optional SSL/TLS: Automatic SSL certificate generation

---

## Advanced Features

This container includes several optional advanced features that can be enabled via environment variables:

### SSL/TLS Encryption
Auto-generate SSL certificates for secure RPC communication:

```yaml
environment:
  - ENABLE_SSL=true
```

### Fail2ban Protection
Enable fail2ban to automatically block IPs that attempt to brute force RPC authentication:

```yaml
environment:
  - ENABLE_FAIL2BAN=true
```

### Prometheus Metrics
Export node metrics for monitoring with Prometheus:

```yaml
environment:
  - ENABLE_METRICS=true
ports:
  - "127.0.0.1:9449:9449"  # Expose metrics port
```

### Automatic Backups
Schedule regular backups of wallet data:

```yaml
environment:
  - ENABLE_BACKUPS=true
  - BACKUP_SCHEDULE="0 0 * * *"  # Daily at midnight (cron format)
```

### Resource Limits
Control container resource usage:

```yaml
deploy:
  resources:
    limits:
      memory: 4G
      cpus: '2'
    reservations:
      memory: 1G
```

---

## Configuration

### Default Ports
The default configuration exposes these ports:

- `8332`: RPC port (bound to localhost only)
- `8333`: P2P port
- `9449`: Prometheus metrics (optional)

Blockchain data is stored in a Docker volume for persistence.

### Custom Configuration
To use custom Meowcoin settings, modify the environment variables in `docker-compose.yml`:

```yaml
environment:
  - RPC_USER=your_custom_username  # Optional
  - RPC_PASSWORD=your_strong_password  # Optional - auto-generated if not provided
  - RPC_BIND=127.0.0.1  # Only bind to localhost inside container
  - RPC_ALLOWIP=127.0.0.1  # Only allow local connections
  - MEOWCOIN_OPTS="dbcache=1024 maxconnections=50"  # Additional options
```

**IMPORTANT**: If you specify your own RPC credentials, use strong, unique credentials.

---

## Accessing Your Node

### RPC Commands

Use the following commands to interact with your Meowcoin node:

```bash
# Get the auto-generated password
docker exec meowcoin-node cat /home/meowcoin/.meowcoin/.rpcpassword

# Example: Get blockchain info (replace PASSWORD with your password)
docker exec meowcoin-node meowcoin-cli -rpcuser=meowcoin -rpcpassword=PASSWORD getblockchaininfo

# Example: Get wallet info (replace PASSWORD with your password)
docker exec meowcoin-node meowcoin-cli -rpcuser=meowcoin -rpcpassword=PASSWORD getwalletinfo
```

---

## Building Locally

To build the Docker image locally:

```bash
# Clone the repository
git clone https://github.com/colterd/meowcoin-docker.git
cd meowcoin-docker

# Build the image
docker build -t meowcoin-docker:local .

# Run with local image
docker run -d --name meowcoin-node -v meowcoin-data:/home/meowcoin/.meowcoin -p 127.0.0.1:8332:8332 -p 8333:8333 meowcoin-docker:local
```

---

## Troubleshooting

**Container not starting?**

Check logs:
```bash
docker logs meowcoin-node
```

**Need to reset?**

```bash
docker-compose down
docker volume rm meowcoin-data
docker-compose up -d
```

### RPC connection issues?
- Verify RPC credentials with: `docker exec meowcoin-node cat /home/meowcoin/.meowcoin/.rpcpassword`
- Check RPC bind address and allowip settings
- Ensure ports are not blocked by firewall

### SSL issues?

Check if certificates were generated properly:
```bash
docker exec meowcoin-node ls -la /home/meowcoin/.meowcoin/certs/
```

---

## Contributing

Found a bug or want to suggest improvements? [Open an issue on GitHub](https://github.com/colterd/meowcoin-docker/issues).

---

## License

This project is released under the [MIT License](LICENSE).