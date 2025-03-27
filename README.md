# Meowcoin Node Docker

A fully automated, secure Docker solution for running a Meowcoin node. This image automatically updates whenever new Meowcoin Core versions are released.

---

## Quick Start

```bash
# Pull and run the container
docker-compose up -d
```

That's it! Your Meowcoin node is now running.

---

## Configuration

### Default Ports
The default configuration exposes these ports:

- `8332`: RPC port
- `8333`: P2P port

Blockchain data is stored in a Docker volume for persistence.

### Custom Configuration
To use custom Meowcoin settings, modify the environment variables in `docker-compose.yml`:

```yaml
environment:
  - RPC_USER=your_custom_username
  - RPC_PASSWORD=your_strong_password
  - RPC_BIND=127.0.0.1  # Only allow local connections
  - RPC_ALLOWIP=127.0.0.1  # Only allow local connections
  - MEOWCOIN_OPTS="-printtoconsole"
```

> **IMPORTANT**: Always change the default RPC credentials for production use.

---

## Accessing Your Node

### RPC Commands

Use the following commands to interact with your Meowcoin node:

```bash
# Example: Get blockchain info
docker exec meowcoin-node meowcoin-cli -rpcuser=meowcoin -rpcpassword=changeme getblockchaininfo

# Example: Get wallet info
docker exec meowcoin-node meowcoin-cli -rpcuser=meowcoin -rpcpassword=changeme getwalletinfo
```

### Viewing Generated RPC Password

If you didn't specify an RPC password, one was generated for you. View it with:

```bash
docker logs meowcoin-node | grep "Generated RPC password:"
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
docker-compose -f docker-compose.local.yml up -d
```

---

## SSL/TLS Configuration

For secure RPC communication, create an SSL certificate and update your configuration:

```bash
# Generate self-signed certificate
openssl req -newkey rsa:4096 -x509 -sha256 -days 3650 -nodes -out meowcoin.crt -keyout meowcoin.key

# Add to docker-compose.yml volumes:
volumes:
  - ./meowcoin.crt:/home/meowcoin/.meowcoin/meowcoin.crt
  - ./meowcoin.key:/home/meowcoin/.meowcoin/meowcoin.key

# Add to environment variables:
environment:
  - CUSTOM_OPTS="rpcssl=1 rpcsslcertificatechainfile=/home/meowcoin/.meowcoin/meowcoin.crt rpcsslprivatekeyfile=/home/meowcoin/.meowcoin/meowcoin.key"
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

**RPC connection issues?**

1. Verify RPC credentials are correct
2. Check RPC bind address and allowip settings
3. Ensure ports are not blocked by firewall

---

## Contributing

Found a bug or want to suggest improvements? [Open an issue on GitHub](https://github.com/colterd/meowcoin-docker/issues).

---

## License

This project is released under the [MIT License](LICENSE).