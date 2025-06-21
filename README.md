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

### Building a Specific Version

By default, this project builds the `latest` official release of Meowcoin. If you need to run a specific version (e.g., for testing or network compatibility), you can specify it during the build process.

1.  **Edit `docker-compose.yml`**:
    Uncomment the `MEOWCOIN_VERSION` build argument and set it to your desired version tag (e.g., `4.1.0`).

    ```yaml
    # docker-compose.yml
    services:
      meowcoin-core:
        build:
          context: .
          dockerfile: ./meowcoin-core/Dockerfile
          args:
            # Uncomment the line below to build a specific Meowcoin version
            MEOWCOIN_VERSION: 4.1.0 # Change this to your desired version
    ```

2.  **Build and Start the Node**:
    Use the `--build` flag to force Docker Compose to build the image with your specified version.
    ```bash
    docker-compose up -d --build
    ```

### Custom Configuration

This project is designed to be highly flexible. While it works out-of-the-box, you can customize it in several ways:

- **Resource Limits & Ports**: The `docker-compose.yml` file allows you to easily change resource reservations, limits, and port mappings.
- **Node Arguments**: You can pass additional command-line arguments to `meowcoind` by modifying the `CMD` in `docker-compose.yml`.
- **meowcoin.conf**: To use a completely custom `meowcoin.conf` file, you can mount it into the container.
  1. Create your `meowcoin.conf` file on the host machine.
  2. Add the following to the `volumes` section of the `meowcoin-core` service in `docker-compose.yml`:
     ```yaml
     volumes:
       - meowcoin_data:/home/meowcoin/.meowcoin
       - ./path/to/your/meowcoin.conf:/home/meowcoin/.meowcoin/meowcoin.conf:ro
     ```
  The entrypoint script will detect your custom file and skip the default generation.

To use a specific version of Meowcoin Core, you can set the `MEOWCOIN_VERSION` build argument in the `docker-compose.yml` file.

```yaml
services:
  meowcoin-core:
    build:
      args:
        # For the most reliable builds, uncomment the line below and set a specific version.
        # Find available versions on the Meowcoin GitHub releases page.
        # MEOWCOIN_VERSION: 4.1.0
```

**Note on Using `latest`**: By default, the build will pull the `latest` version. This is convenient, but it relies on making a network request to the GitHub API. In automated environments like Portainer or in case of network issues, this API call can occasionally fail, causing the build to stop. **For production use, it is strongly recommended to pin to a specific version number.**

## Security Features

This project was built from the ground up with security as a top priority. It incorporates a multi-layered defense strategy aligned with the [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html).

- **Software Supply Chain Security**:
  - The build process downloads only official, pre-compiled releases directly from the Meowcoin Foundation's GitHub.
  - **GPG Signature Verification**: Every downloaded release is verified against the official developer GPG signatures to ensure its authenticity and integrity, protecting against supply-chain attacks.

- **Principle of Least Privilege**:
  - **Non-Root Execution**: Both the `meowcoin-core` and `meowcoin-monitor` services run as dedicated, unprivileged users (`meowcoin` and `monitor` respectively).
  - **No New Privileges**: The `no-new-privileges` security option is enabled to prevent any process from escalating its privileges.
  - **Minimal Kernel Capabilities**: All Linux kernel capabilities are dropped (`cap_drop: ALL`), granting the containers only the absolute minimum set of permissions required to run.

- **Filesystem and Runtime Hardening**:
  - **Read-Only Root Filesystem**: The root filesystems for both containers are set to `read_only`. This prevents any modification to the application binaries, libraries, or system tools, drastically reducing the attack surface.
  - **Secure Temp Space**: A temporary, in-memory filesystem (`tmpfs`) is mounted at `/tmp` for any necessary temporary file operations.
  - **Denial-of-Service Protection**: Resource limits (`ulimits`) are in place to prevent a single container from consuming excessive system resources (e.g., via a fork bomb).

- **Secure Configuration & Data**:
  - **Automated Credential Management**: The system automatically generates strong, unique RPC credentials on first run.
  - **Secure Credential Storage**: Credentials are not exposed in logs or environment variables but are stored in a file with strict `600` permissions inside a persistent Docker volume.
  - **Log Rotation**: The logging driver is configured to automatically rotate logs, preventing disk exhaustion from uncontrolled log growth.

## Project Structure

- `docker-compose.yml`: Defines the `meowcoin-core` and `meowcoin-monitor` services. It includes sensible defaults and allows for version pinning.
- `meowcoin-core/`:
  - `Dockerfile`: A multi-stage Dockerfile that fetches a specified or latest official Meowcoin release and sets up a secure runtime environment.
  - `entrypoint.sh`: **The core logic.** Handles node startup, automatic credential generation, and routing for `meowcoin-cli` commands.
- `meowcoin-monitor/`:
  - `Dockerfile`: A simple Dockerfile for the monitor service.
  - `entrypoint.sh`: A script that periodically checks the node's status.
- `README.md`: This file.
