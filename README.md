# Meowcoin Docker

A secure, robust Docker setup for running a [Meowcoin](https://github.com/Meowcoin-Foundation/Meowcoin) node and monitoring service.

## Features

- 🔒 **Security-hardened Docker images**
  - Non-root execution with minimal capabilities
  - Read-only filesystems with secure defaults
  - Automatic credential management and secure storage
  - Supply chain security with checksum and signature verification

- 🚀 **Performance-optimized configuration**
  - Automatic resource detection and optimization
  - Multi-stage builds for minimal image size
  - Configurable resource limits and reservations

- 📊 **Comprehensive monitoring**
  - Real-time status dashboard
  - Resource usage tracking
  - Blockchain synchronization monitoring

- 🔄 **Reliability and resilience**
  - Automatic recovery from failures
  - Robust health checks
  - Graceful shutdown handling

- 🛠️ **Flexible configuration**
  - Environment variable customization
  - Support for custom configuration files
  - Multiple deployment options (standalone, swarm)

- 📦 **Multi-architecture support**
  - x86_64, ARM64, and ARM builds
  - Cross-platform compatibility

## Quick Start

```bash
# Clone the repository
git clone https://github.com/ColterD/meowcoin-docker.git
cd meowcoin-docker

# Copy and edit the environment file (optional)
cp .env.example .env
# Edit .env to customize your setup

# Start the stack
docker-compose up -d
```

That's it! The system will automatically download the latest Meowcoin release, configure it optimally for your system, and start syncing the blockchain. Your RPC credentials are created automatically and stored securely.

## Configuration

### Environment Variables

You can customize the setup by creating a `.env` file in the project root. See `.env.example` for all available options. Here are some key variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `MEOWCOIN_VERSION` | Meowcoin version to use | `latest` |
| `MEOWCOIN_ARCH` | Architecture | `x86_64-linux-gnu` |
| `MEOWCOIN_RPC_PORT` | RPC port | `9766` |
| `MEOWCOIN_P2P_PORT` | P2P port | `8788` |
| `MEOWCOIN_DB_CACHE` | Database cache size (MB) | `1024` |
| `MEOWCOIN_MAX_CONNECTIONS` | Maximum connections | `100` |
| `RESOURCES_LIMIT_MEMORY` | Memory limit | `4G` |
| `RESOURCES_LIMIT_CPUS` | CPU limit | `2.0` |

### Custom Configuration

To use a custom `meowcoin.conf` file:

```bash
# Create your custom config
cp config/meowcoin.conf.template /path/to/your/meowcoin.conf
# Edit the file as needed

# Set the path in .env
echo "MEOWCOIN_CUSTOM_CONFIG=/path/to/your/meowcoin.conf" >> .env
```

## Usage

### Using `meowcoin-cli`

To interact with your node, use `docker-compose exec meowcoin-core` followed by your desired command:

```bash
# Get blockchain info
docker-compose exec meowcoin-core getblockchaininfo

# Get network info
docker-compose exec meowcoin-core getnetworkinfo

# Get mempool info
docker-compose exec meowcoin-core getmempoolinfo
```

### Using the Makefile

The project includes a Makefile to simplify common operations:

```bash
# Build the Docker images
make build

# Start the containers
make up

# View container logs
make logs

# Check container status
make status

# Stop the containers
make down

# Show help
make help
```

### Checking Logs

```bash
# View logs from the Meowcoin node
docker-compose logs -f meowcoin-core

# View logs from the monitor service
docker-compose logs -f meowcoin-monitor
```

## Advanced Usage

### Deployment Examples

The project includes several example configurations:

- **Basic**: A minimal setup for running a Meowcoin node
  ```bash
  docker-compose -f examples/basic/docker-compose.basic.yml up -d
  ```

- **Advanced**: A full-featured setup with monitoring
  ```bash
  docker-compose -f examples/advanced/docker-compose.advanced.yml up -d
  ```

- **Swarm**: A configuration for Docker Swarm deployment
  ```bash
  docker stack deploy -c docker-compose.yml -c examples/swarm/docker-compose.swarm.yml meowcoin
  ```

### Building a Specific Version

By default, the project uses the latest Meowcoin release. To use a specific version:

1. Set the version in your `.env` file:
   ```
   MEOWCOIN_VERSION=2.0.5
   ```

2. Build and start the containers:
   ```bash
   docker-compose up -d --build
   ```

**Note**: For production use, it's recommended to pin to a specific version number rather than using `latest`.

## Security Features

This project implements multiple layers of security:

### Supply Chain Security
- Downloads only official releases from the Meowcoin Foundation's GitHub
- Verifies checksums and GPG signatures
- Implements retry logic with fallbacks for reliability

### Principle of Least Privilege
- Non-root execution with dedicated users
- Minimal kernel capabilities
- No privilege escalation

### Filesystem and Runtime Hardening
- Read-only root filesystem
- Secure temporary storage
- Resource limits to prevent DoS attacks

### Secure Configuration
- Automatic generation of strong credentials
- Secure credential storage
- Proper file permissions

## Project Structure

```
meowcoin-docker/
├── .github/                      # GitHub workflows
├── docker/                       # Docker-related files
│   ├── core/                     # Meowcoin Core node
│   ├── monitor/                  # Monitoring service
│   └── scripts/                  # Shared scripts
├── config/                       # Default configurations
├── examples/                     # Example configurations
├── docker-compose.yml            # Main compose file
├── .env.example                  # Example environment variables
├── Makefile                      # Simplified build commands
└── README.md                     # This file
```

## Troubleshooting

### Common Issues

- **Build fails with GitHub API error**: Set a specific version in `.env` instead of using `latest`.
- **Node won't start**: Check logs with `docker-compose logs meowcoin-core` for specific errors.
- **RPC connection issues**: Verify the RPC port is correctly mapped and not blocked by a firewall.

For more detailed troubleshooting, see the logs or open an issue on GitHub.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
