# Meowcoin Docker

A Docker container for running the official Meowcoin Core node.

## Quick Start

### Prerequisites

- Docker installed on your system
- Docker Compose installed on your system

### Run with Docker Compose (Recommended)

1. Clone this repository:

```bash
git clone https://github.com/yourusername/meowcoin-docker.git
cd meowcoin-docker
```

2. Start the container:

```bash
docker-compose up -d
```

3. That's it! Your Meowcoin node is now running.

### Check Status

To check the status of your node:

```bash
docker logs meowcoin-node
```

### Using the Meowcoin CLI

You can interact with your node using the Meowcoin CLI:

```bash
docker exec -it meowcoin-node /usr/local/bin/entrypoint.sh cli getblockchaininfo
```

### Custom Configuration

If you want to use a custom configuration, edit the file in the `config` directory:

1. Edit or create `config/meowcoin.conf`
2. Restart the container:

```bash
docker-compose restart
```

## Data Storage

All blockchain data is stored in a Docker volume named `meowcoin-data`. This ensures your data persists even if the container is removed.

## Accessing Block Explorer

The Meowcoin node doesn't include a block explorer. To view blockchain data, you can use the official Meowcoin explorers:

- [Meowcoin Explorer](https://explorer.mewccrypto.com/)
- [Meowcoin Explorer 2](https://explorer.meowcoin.lol/)

## Ports

- **9766**: RPC port for API calls
- **8788**: P2P port for network communication

## Version

This container uses Meowcoin Core version 2.0.5. To update to a newer version, edit the `meowcoin_version.txt` file and rebuild the container.

## Support

For issues related to this Docker container, please [open an issue](https://github.com/yourusername/meowcoin-docker/issues).

For Meowcoin-specific questions, please visit their [official repository](https://github.com/Meowcoin-Foundation/Meowcoin).
