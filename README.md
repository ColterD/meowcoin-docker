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

## What You Get

- Latest Meowcoin Core version (currently running: **Meow-v2.0.5**)
- Automatic updates when new versions are released
- Data persistence between restarts
- Secure setup with non-root user
- Multi-architecture support (AMD64 and ARM64)

---

## Security Features

- RPC authentication with automatically generated credentials
- Limited network access by default
- Non-root container user
- Regular security scanning

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
  - RPC_USER=meowcoin
  - RPC_PASSWORD=changeme
  - RPC_BIND=0.0.0.0
  - RPC_ALLOWIP=172.0.0.0/8
  - MEOWCOIN_OPTS="-printtoconsole"
```

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

---

## Security Notes

- **Important:** For production use, change the default RPC credentials.
- Consider restricting RPC access to specific IPs.
- Store sensitive credentials in Docker secrets instead of environment variables.

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

---

## Contributing

Found a bug or want to suggest improvements? [Open an issue on GitHub](https://github.com/your-repo-here/issues).

---

## License

This project is released under the [MIT License](LICENSE).