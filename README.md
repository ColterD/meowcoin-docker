# Meowcoin Node Docker

A fully automated Docker solution for running a Meowcoin node. This image automatically updates whenever new Meowcoin Core versions are released.

## Quick Start

```bash
# Pull and run the container
docker-compose up -d

That's it! Your Meowcoin node is now running.
What You Get

    Latest Meowcoin Core version (currently running: Meow-v2.0.5)
    Automatic updates when new versions are released
    Data persistence between restarts
    Secure setup with non-root user

Configuration

The default configuration exposes these ports:

    8332: RPC port
    8333: P2P port

Blockchain data is stored in a Docker volume for persistence.
Custom Configuration

To use custom Meowcoin settings, modify the environment variables in docker-compose.yml:

yaml

environment:
  - MEOWCOIN_OPTS="-rpcallowip=0.0.0.0/0 -rpcbind=0.0.0.0 -printtoconsole"

Accessing Your Node
RPC Commands

bash

# Example: Get blockchain info
docker exec meowcoin-node meowcoin-cli getblockchaininfo

# Example: Get wallet info
docker exec meowcoin-node meowcoin-cli getwalletinfo

Security Notes

    The default configuration allows RPC from any IP (0.0.0.0/0)
    For production, consider restricting RPC access

Troubleshooting

Container not starting?
Check logs: docker logs meowcoin-node

Need to reset?

bash

docker-compose down
docker volume rm meowcoin-data
docker-compose up -d

Contributing

Found a bug or want to suggest improvements? Open an issue on GitHub.
License

This project is released under the MIT License.


This README provides simple getting started instructions while covering essential information about configuration and security.