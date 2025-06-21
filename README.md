# Meowcoin Docker

This project provides a secure, fast, and easy-to-use Docker setup for running a [Meowcoin](https://github.com/Meowcoin-Foundation/Meowcoin) node.

It is designed to be as "plug-and-play" as possible. The system automatically downloads the latest official Meowcoin release, generates and secures RPC credentials, and runs everything in a secure, unprivileged environment.

## Features

- **Blazing Fast Setup**: Downloads pre-compiled official releases, not source code. Get a node running in minutes, not hours.
- **Zero-Config Start**: Works out-of-the-box with `docker-compose up`. No need to create `.env` files.
- **Secure by Default**: Automatically generates a unique RPC username and password and stores them securely in a persistent volume.
- **Persistent & Robust**: Blockchain data and credentials persist in a Docker volume.
- **Unprivileged**: Runs the node as a non-root `meowcoin` user for enhanced security.
- **Health-checked**: Includes a robust health check to ensure the node is fully responsive.
- **Simplified CLI**: Interact with `meowcoin-cli` using direct `docker-compose exec` commands.
- **Cross-Platform**: Uses Debian-based images for wide compatibility.

## Prerequisites

- [Docker](https://www.docker.com/products/docker-desktop/)
- [Docker Compose](https://docs.docker.com/compose/install/)

## Getting Started

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/ColterD/meowcoin-docker.git
    cd meowcoin-docker
    ```

2.  **Start the node:**
    ```bash
    docker-compose up -d
    ```

That's it! On the first run, the service will download the latest Meowcoin release and start syncing the blockchain. Your RPC credentials are created automatically and stored securely.

To view the generated credentials, run:
```bash
docker-compose exec meowcoin-core cat /home/meowcoin/.meowcoin/.credentials
```
These credentials are saved in the `meowcoin_data` volume and will persist across restarts.

## Usage

### Using `meowcoin-cli`

To interact with your node, use `docker-compose exec meowcoin-core` followed by your desired `meowcoin-cli` command. The entrypoint script automatically handles the authentication.

**Examples:**
```bash
# Get blockchain info
docker-compose exec meowcoin-core getblockchaininfo

# Get network info
docker-compose exec meowcoin-core getnetworkinfo

# Get a new address
docker-compose exec meowcoin-core getnewaddress
```

### Checking Logs

To view the real-time logs from the Meowcoin node:
```bash
docker-compose logs -f meowcoin-core
```

To view the logs from the monitor service:
```bash
docker-compose logs -f meowcoin-monitor
```

### Custom Configuration
For most use cases, no changes are needed. However, if you need to adjust ports or resource limits, you can do so by editing the default values directly in the `docker-compose.yml` file. For advanced node settings, you can edit the `meowcoin.conf.template` file in the project root.

## Project Structure

- `docker-compose.yml`: Defines the `meowcoin-core` and `meowcoin-monitor` services. It includes sensible defaults for all necessary configurations.
- `meowcoin.conf.template`: The template for the `meowcoin.conf` file, located in the project root.
- `meowcoin-core/`:
  - `Dockerfile`: A multi-stage Dockerfile that fetches the latest official Meowcoin release and sets up a secure runtime environment.
  - `entrypoint.sh`: **The core logic.** Handles node startup, automatic credential generation, and routing for `meowcoin-cli` commands.
- `meowcoin-monitor/`:
  - `Dockerfile`: A simple Dockerfile for the monitor service.
  - `entrypoint.sh`: A script that periodically checks the node's status.
- `README.md`: This file.
