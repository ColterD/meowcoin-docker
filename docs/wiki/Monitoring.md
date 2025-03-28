# Monitoring Your Node

## Basic Monitoring

### Container Health Check

The container includes a health check accessible via Docker:

```bash
docker inspect --format='{{json .State.Health}}' meowcoin-node
```

### Log Monitoring

View logs:
```bash
docker logs meowcoin-node
```

Continuous log monitoring:
```bash
docker logs -f meowcoin-node
```

### Node Status

Check blockchain status:
```bash
docker exec meowcoin-node meowcoin-cli getblockchaininfo
```

Check network status:
```bash
docker exec meowcoin-node meowcoin-cli getnetworkinfo
```

## Advanced Monitoring

### Prometheus Metrics

Enable Prometheus metrics:

```yaml
environment:
  - ENABLE_METRICS=true
ports:
  - "127.0.0.1:9449:9449"
```

### Grafana Dashboard

The included docker-compose.yml supports a complete monitoring stack:

```bash
docker-compose --profile monitoring up -d
```

This starts:

- Prometheus for metrics collection
- Grafana for visualization

Access Grafana at http://localhost:3000 (default credentials: admin/admin)

### Available Metrics

The Prometheus exporter provides metrics on:

- Blockchain height and sync status
- Transaction rates and fees
- Memory pool size and composition
- Network peers and bandwidth usage
- System resource utilization

### Alert Configuration

Configure Prometheus alerts for:

- Node out of sync (more than 6 blocks behind)
- Low peer count (less than 3 connections)
- High memory pool usage
- Unusual transaction patterns

Example alert configuration:

```yaml
groups:
- name: meowcoin
  rules:
  - alert: NodeOutOfSync
    expr: meowcoin_blocks_behind > 6
    for: 30m
    labels:
      severity: warning
    annotations:
      summary: "Meowcoin node out of sync"
      description: "Node is {{ $value }} blocks behind the latest block"
```

## Notification Integrations

### Email Notifications

Configure Grafana to send email alerts:

- Add SMTP configuration to Grafana
- Create notification channels
- Link alerts to notification channels

### Webhook Integrations

Send alerts to:

- Slack
- Discord
- Telegram
- PagerDuty

Example webhook configuration for Slack:

```yaml
receivers:
- name: slack-notifications
  slack_configs:
  - api_url: 'https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX'
    channel: '#meowcoin-alerts'
    send_resolved: true
```
