# Meowcoin Docker

Docker setup for running a [Meowcoin](https://github.com/Meowcoin-Foundation/Meowcoin) node.

## Quick Start

```bash
git clone https://github.com/ColterD/meowcoin-docker.git
cd meowcoin-docker
docker compose up -d
```

That's it! The node will download the latest Meowcoin release and start syncing.

## Commands

```bash
# Check status
docker compose logs -f

# Use meowcoin-cli
docker compose exec meowcoin-core getblockchaininfo

# View credentials
docker compose exec meowcoin-core cat /home/meowcoin/.meowcoin/.credentials

# Stop
docker compose down
```

## Configuration

Copy `.env.example` to `.env` to customize settings like version, ports, and resource limits.

## Troubleshooting

```bash
# Check if containers are running
docker compose ps

# View logs
docker compose logs meowcoin-core

# Check status
./check-status.sh
```

**Common issues:**
- Build fails: Set specific version in `docker-compose.yml` instead of `latest`
- Node won't start: Check logs for errors
- "Container is unhealthy": Node is still starting, wait a few minutes
- Can't connect: Verify ports aren't blocked by firewall


