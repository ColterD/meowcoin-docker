# Meowcoin Docker

A "fire and forget" Docker container for running Meowcoin Core.

## Quick Start (One Command Setup)

```bash
docker-compose up -d
```

That's it! Your Meowcoin node is now running.

### Checking Status

```bash
docker logs meowcoin-node
```

### Using the Meowcoin CLI

```bash
docker exec -it meowcoin-node entrypoint.sh cli getblockchaininfo
```

## Blockchains Explorers

View the Meowcoin blockchain:

- [Meowcoin Explorer](https://explorer.mewccrypto.com/)
- [Meowcoin Explorer 2](https://explorer.meowcoin.lol/)

## Customization (Optional)

To customize settings, edit the `config/meowcoin.conf` file and restart the container:

```bash
docker-compose restart
```

## Data

All blockchain data is stored in a Docker volume for persistence.
