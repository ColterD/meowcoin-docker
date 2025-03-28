# Meowcoin Node Docker

A fully automated, secure Docker solution for running a Meowcoin node. This image automatically updates whenever new Meowcoin Core versions are released.

## Features

- **Auto-updating**: Stays current with latest Meowcoin releases
- **Secure**: Hardened configuration with multiple security layers
- **Resource Optimized**: Automatically adapts to available system resources
- **Multi-architecture**: Supports AMD64 and ARM64 architectures
- **Monitoring**: Prometheus integration for advanced metrics
- **Backup System**: Automated blockchain backups with retention policies

## Quick Start

```bash
curl -sSL https://raw.githubusercontent.com/colterd/meowcoin-docker/main/docker-compose.yml > docker-compose.yml
docker-compose up -d
```

That's it! Your Meowcoin node is now running with secure auto-generated credentials.

## Documentation

Visit our Wiki for complete documentation:

- Installation Guide
- Configuration Guide
- Security Best Practices
- Monitoring
- Backups
- Troubleshooting
- Advanced Usage

## Repository Structure

```
meowcoin-docker/
├── build/                  # Build files
├── config/                 # Configuration templates
├── docs/                   # Documentation
├── scripts/                # Scripts for container operation
└── docker-compose.yml      # Docker Compose configuration
```

## Contributing

Contributions are welcome! Please see `CONTRIBUTING.md` for details.

## License

This project is released under the MIT License.