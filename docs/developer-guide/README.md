# MeowCoin Platform Developer Guide

Welcome to the MeowCoin Platform Developer Guide. This guide provides information for developers who want to contribute to the platform or build integrations with it.

## Table of Contents

1. [Architecture Overview](./architecture.md)
2. [Development Environment Setup](./development-setup.md)
3. [Coding Standards](./coding-standards.md)
4. [Testing](./testing.md)
5. [Building and Packaging](./building.md)
6. [Contributing](./contributing.md)
7. [API Integration](./api-integration.md)
8. [Plugin Development](./plugin-development.md)

## Architecture Overview

MeowCoin Platform is built using a microservices architecture with the following components:

- **API Gateway**: Central entry point for all client requests
- **Authentication Service**: Handles user authentication and authorization
- **Blockchain Service**: Manages communication with MeowCoin nodes
- **Analytics Engine**: Processes and analyzes blockchain data
- **Notification Service**: Manages alerts and user notifications
- **Dashboard Application**: React-based frontend with server components
- **Database Cluster**: Persistent storage with automatic scaling
- **Cache Layer**: High-performance data caching
- **Message Queue**: Asynchronous task processing

For more details, see the [Architecture Overview](./architecture.md).

## Technology Stack

The platform is built using the following technologies:

- **Backend**: Node.js with Fastify framework
- **Frontend**: React with Next.js and Material-UI
- **Database**: PostgreSQL and TimescaleDB
- **Caching**: Redis
- **Message Queue**: RabbitMQ
- **Containerization**: Docker and Docker Compose
- **Monitoring**: Prometheus and Grafana

## Development Environment Setup

To set up a development environment, follow the instructions in the [Development Environment Setup](./development-setup.md) guide.

## Contributing

We welcome contributions to the MeowCoin Platform! Please read our [Contributing Guide](./contributing.md) for details on how to contribute.

## License

MeowCoin Platform is licensed under the MIT License. See the [LICENSE](../../LICENSE) file for details.