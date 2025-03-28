# Configuration Guide

## Environment Variables

The container is configured using environment variables in the docker-compose.yml file.

### Core Settings

| Variable | Default | Description |
|----------|---------|-------------|
| RPC_USER | meowcoin | RPC username |
| RPC_PASSWORD | *auto-generated* | RPC password (auto-generated if not set) |
| RPC_BIND | 127.0.0.1 | IP address to bind RPC server |
| RPC_ALLOWIP | 127.0.0.1 | IP addresses allowed to connect to RPC |

### Performance Settings

| Variable | Default | Description |
|----------|---------|-------------|
| DBCACHE | *auto* | Database cache size in MB |
| MAX_CONNECTIONS | *auto* | Maximum network connections |
| MAXMEMPOOL | *auto* | Maximum memory pool size in MB |

### Security Features

| Variable | Default | Description |
|----------|---------|-------------|
| ENABLE_SSL | false | Enable SSL for RPC connections |
| ENABLE_FAIL2BAN | false | Enable fail2ban protection |
| ENABLE_JWT_AUTH | false | Enable JWT authentication |
| ENABLE_READONLY_FS | false | Enable read-only filesystem |

### Monitoring Features

| Variable | Default | Description |
|----------|---------|-------------|
| ENABLE_METRICS | false | Enable Prometheus metrics |
| TZ | UTC | Container timezone |

### Backup Features

| Variable | Default | Description |
|----------|---------|-------------|
| ENABLE_BACKUPS | false | Enable automated backups |
| BACKUP_SCHEDULE | 0 0 * * * | Backup schedule (cron format) |
| MAX_BACKUPS | 7 | Number of backups to retain |
| BACKUP_COMPRESSION_LEVEL | 6 | Backup compression level (1-9) |
| BACKUP_REMOTE_ENABLED | false | Enable remote backup storage |
| BACKUP_REMOTE_TYPE | | Remote storage type (s3, sftp) |

## Advanced Configuration

### Custom meowcoin.conf

To use a completely custom configuration:

1. Create your configuration file
2. Mount it into the container:

\`\`\`yaml
volumes:
  - ./my-custom-meowcoin.conf:/home/meowcoin/.meowcoin/meowcoin.conf:ro
\`\`\`

### Resource Allocation

Configure container resource limits:

\`\`\`yaml
deploy:
  resources:
    limits:
      memory: 4G
      cpus: '2'
    reservations:
      memory: 1G
      cpus: '0.5'
\`\`\`

### Multi-Node Setup

For running multiple nodes, modify the compose file:

\`\`\`yaml
services:
  meowcoin-mainnet:
    # Regular node config

  meowcoin-testnet:
    # Same image, different port and config
    environment:
      - CUSTOM_OPTS="testnet=1"
    ports:
      - "127.0.0.1:18332:18332"
\`\`\`
