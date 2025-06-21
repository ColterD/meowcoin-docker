# Configuration Templates

This directory contains template files used by the Meowcoin Docker containers.

## meowcoin.conf.template

This template is used to generate the `meowcoin.conf` file when the container starts for the first time. It contains placeholders for environment variables that will be substituted at runtime.

The template is copied to `/etc/meowcoin/meowcoin.conf.template` in the container and is used by the entrypoint script to generate the final configuration file.

### Available Variables

The following environment variables can be used in the template:

- `${MEOWCOIN_RPC_USER}`: The RPC username
- `${MEOWCOIN_RPC_PASSWORD}`: The RPC password
- `${MEOWCOIN_RPC_PORT}`: The RPC port
- `${MEOWCOIN_P2P_PORT}`: The P2P port
- `${MEOWCOIN_MAX_CONNECTIONS}`: Maximum number of connections
- `${MEOWCOIN_DB_CACHE}`: Database cache size in MB
- `${MEOWCOIN_MAX_MEMPOOL}`: Maximum mempool size in MB
- `${MEOWCOIN_TXINDEX}`: Whether to enable transaction indexing (0 or 1)
- `${MEOWCOIN_MEOWPOW}`: Whether to enable MeowPow (0 or 1)
- `${MEOWCOIN_BANTIME}`: Ban time in seconds

### Customization

To use a completely custom configuration file, you can mount your own file into the container:

```yaml
volumes:
  - ./path/to/your/meowcoin.conf:/home/meowcoin/.meowcoin/meowcoin.conf:ro
```

This will override the template-based configuration generation.