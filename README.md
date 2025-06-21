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

# View logs (most important for debugging)
docker compose logs -f meowcoin-core

# Check status
./check-status.sh

# Access internal logs
docker exec meowcoin-node cat /tmp/meowcoin-core.log
```

**If deployment fails with "container is unhealthy":**
1. Check logs: `docker compose logs meowcoin-core`
2. The node needs 5-10 minutes to download and start
3. Wait for "Meowcoin daemon..." message in logs
4. If it keeps failing, try: `docker compose down && docker compose up -d`

**Common issues:**
- Build fails: Set specific version in `docker-compose.yml` instead of `latest`
- Node won't start: Check logs for errors
- Can't connect: Verify ports aren't blocked by firewall


