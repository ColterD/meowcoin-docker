# Meowcoin Node Docker - Installation Guide

This guide covers the installation and initial configuration of the Meowcoin Node Docker container.

---

## Prerequisites

- Docker Engine 20.10.0 or higher  
- Docker Compose 2.0.0 or higher  
- 2GB RAM minimum (4GB recommended)  
- 100GB free disk space (SSD recommended)  
- Stable internet connection  

---

## Quick Start

1. **Create a directory for your Meowcoin node:**

   ```bash
   mkdir -p ~/meowcoin-node
   cd ~/meowcoin-node
   ```

2. **Download the `docker-compose.yml` file:**

   ```bash
   curl -O https://raw.githubusercontent.com/colterd/meowcoin-docker/main/docker-compose.yml
   ```

3. **Start the node:**

   ```bash
   docker-compose up -d
   ```

That's it! Your Meowcoin node will start downloading the blockchain.

---

## Checking Node Status

- **Check if your node is running properly:**

  ```bash
  docker logs -f meowcoin-node
  ```

- **View blockchain sync progress:**

  ```bash
  docker exec meowcoin-node meowcoin-cli getblockchaininfo
  ```

---

## Accessing Your Node

The RPC interface is accessible on **localhost port 8332**.

- **Get your automatically generated RPC password:**

  ```bash
  docker exec meowcoin-node cat /home/meowcoin/.meowcoin/.rpcpassword
  ```

- **Use this password with the default username `meowcoin` to interact with your node:**

  ```bash
  docker exec meowcoin-node meowcoin-cli -rpcuser=meowcoin -rpcpassword=YOUR_PASSWORD getinfo
  ```

---

## Advanced Installation Options

### Custom Data Directory

To store blockchain data in a custom location, modify the volume mapping in `docker-compose.yml`:

```yaml
services:
  meowcoin:
    # Other settings...
    volumes:
      - /path/to/your/data:/home/meowcoin/.meowcoin
```

### Running on a Specific Network Interface

Edit the `docker-compose.yml` file and modify the port bindings:

```yaml
ports:
  - "192.168.1.100:8332:8332"  # Replace with your IP
  - "8333:8333"
```

---

## Upgrading from an Older Version

1. **Pull the latest image:**

   ```bash
   docker-compose pull
   ```

2. **Restart your node:**

   ```bash
   docker-compose down
   docker-compose up -d
   ```

Your node will start using the new version while preserving all blockchain data.

---

## Installation Verification

- **Check version:**

  ```bash
  docker exec meowcoin-node meowcoin-cli -version
  ```

- **Check blockchain info:**

  ```bash
  docker exec meowcoin-node meowcoin-cli getblockchaininfo
  ```

- **Check network info:**

  ```bash
  docker exec meowcoin-node meowcoin-cli getnetworkinfo
  ```

---

## Next Steps

- **See Configuration Guide for customizing your node**
- **Check Security Best Practices for securing your node**
- **Set up Monitoring for detailed node metrics**