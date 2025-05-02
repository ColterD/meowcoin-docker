# MeowCoin Platform Infrastructure

This directory contains configuration files for the infrastructure components of the MeowCoin Platform.

## Components

### Prometheus

Prometheus is used for monitoring and alerting. It collects metrics from all services and stores them for analysis.

Configuration:
- `prometheus.yml`: Main configuration file for Prometheus

### Grafana

Grafana is used for visualization of metrics and creating dashboards.

Configuration:
- `provisioning/datasources/datasources.yml`: Configures data sources for Grafana
- `provisioning/dashboards/dashboards.yml`: Configures dashboard providers for Grafana
- `provisioning/dashboards/json/`: Contains JSON definitions for pre-configured dashboards

### PostgreSQL

PostgreSQL is used as the main relational database for the platform.

Configuration:
- `postgres/init/create-multiple-databases.sh`: Script to create multiple databases during initialization

### TimescaleDB

TimescaleDB is used for time-series data storage, particularly for metrics and historical data.

### Redis

Redis is used for caching, pub/sub messaging, and as a session store.

### RabbitMQ

RabbitMQ is used as a message broker for asynchronous communication between services.

## Deployment

These configurations are used by the Docker Compose setup in the root directory. To deploy the infrastructure:

```bash
# From the root directory
docker-compose up -d
```

## Monitoring

Once deployed, you can access:

- Grafana: http://localhost:3001 (default credentials: admin/admin)
- Prometheus: http://localhost:9090

## Backup and Restore

Backup scripts and procedures are located in the `scripts` directory in the root of the project.