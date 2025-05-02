# MeowCoin Blockchain Platform (2025 Edition)

A comprehensive, enterprise-grade platform for running, managing, and monitoring MeowCoin blockchain nodes with advanced analytics, security features, and multi-node orchestration capabilities.

![MeowCoin Platform](https://placeholder.com/meowcoin-platform-2025.png)

## Quick Start with One-Line Installer

The easiest way to get started is with our one-line installer:

### For Linux/macOS:

```bash
curl -sSL https://raw.githubusercontent.com/ColterD/meowcoin-docker/main/meowcoin-platform-installer.sh | bash
```

### For Windows PowerShell:

```powershell
iwr -useb https://raw.githubusercontent.com/ColterD/meowcoin-docker/main/meowcoin-platform-installer.ps1 | iex
```

The installer will:
1. Check for Docker and Docker Compose
2. Create a directory for the MeowCoin Platform
3. Clone the repository
4. Start the platform with Docker Compose
5. Guide you through the setup process

## Alternative: Manual Installation

If you prefer to run the startup script directly:

### For Linux/macOS:

```bash
# Clone the repository
git clone https://github.com/ColterD/meowcoin-docker.git
cd meowcoin-docker

# Run the startup script directly
./start.sh
```

### For Windows:

```powershell
# Clone the repository
git clone https://github.com/ColterD/meowcoin-docker.git
cd meowcoin-docker

# Run the startup script directly
.\start.ps1
```

## What Happens Next

The platform will automatically:
1. Check for script updates
2. Download required files
3. Start essential services
4. Open a web-based setup wizard
5. Guide you through the configuration process

The scripts will automatically update themselves when new versions are available, ensuring you always have the latest features and bug fixes.

### Setup Wizard Features

The setup wizard allows you to configure:

- **Database Options**:
  - **SQLite**: Simple file-based database for personal use or testing
  - **Built-in PostgreSQL**: Automatically managed database for production use
  - **Custom Configuration**: Connect to your existing database servers

- **Node Configuration**:
  - Configure your MeowCoin node settings
  - Set RPC credentials
  - Adjust network parameters

- **Security Settings**:
  - Set up secure passwords
  - Configure access controls
  - Enable encryption options

## Accessing Services

After starting the platform, you can access these services:

- **Dashboard**: http://localhost:3000
- **Grafana Monitoring**: http://localhost:3001 (admin/admin)
- **RabbitMQ Management**: http://localhost:15672 (guest/guest)
- **PostgreSQL**: localhost:5432 (postgres/postgres)
- **Redis**: localhost:6379

## Customizing Your Installation

After completing the setup wizard, you can further customize your installation:

1. **Modify Configuration**: Edit the `.env` file to change any settings
2. **Add Custom Plugins**: Place custom plugins in the `plugins` directory
3. **Extend Functionality**: Modify the docker-compose.yml file to add new services

```bash
# Restart the platform after making changes
docker-compose down
docker-compose up -d
```

## Features

### Core Platform
- **Multi-Node Management**: Orchestrate and monitor multiple MeowCoin nodes from a single dashboard
- **Real-Time Monitoring**: Advanced metrics with customizable alerts and notifications
- **Blockchain Analytics**: Deep insights into network performance, transaction patterns, and blockchain health
- **Automated Operations**: Scheduled backups, updates, and maintenance tasks
- **High Availability**: Fault-tolerant architecture with automatic failover
- **Horizontal Scaling**: Add nodes dynamically to handle increased load

### Security
- **Role-Based Access Control**: Granular permissions for different user roles
- **Multi-Factor Authentication**: Enhanced security with various 2FA options
- **Audit Logging**: Comprehensive activity tracking and compliance reporting
- **Secure API Gateway**: Encrypted communications with rate limiting and DDoS protection
- **Secrets Management**: Secure storage and rotation of sensitive credentials

### User Experience
- **Modern Dashboard**: Intuitive interface with customizable widgets and layouts
- **Mobile Responsive**: Full functionality on desktop, tablet, and mobile devices
- **Dark/Light Modes**: Automatic theme switching based on system preferences
- **Internationalization**: Support for multiple languages
- **Accessibility**: WCAG 2.2 AA compliant interface

### Developer Tools
- **GraphQL API**: Flexible data access with efficient queries
- **Webhooks**: Real-time event notifications for external integrations
- **SDK**: Client libraries for multiple programming languages
- **CLI Tools**: Command-line utilities for automation and scripting
- **Playground**: Interactive API testing environment

## Architecture

The MeowCoin Platform uses a modern microservices architecture:

- **API Gateway**: Central entry point for all client requests
- **Authentication Service**: Handles user authentication and authorization
- **Blockchain Service**: Manages communication with MeowCoin nodes
- **Analytics Engine**: Processes and analyzes blockchain data
- **Notification Service**: Manages alerts and user notifications
- **Dashboard Application**: React-based frontend with server components
- **Database Cluster**: Persistent storage with automatic scaling
- **Cache Layer**: High-performance data caching
- **Message Queue**: Asynchronous task processing

## System Requirements

- **Docker and Docker Compose**: Required for containerization
- **Memory**: 4GB minimum (8GB+ recommended)
- **Storage**: 100GB+ for blockchain data
- **CPU**: 2+ cores recommended
- **Operating System**: Any OS that supports Docker (Linux, macOS, Windows)

## Configuration

The platform can be configured in two ways:

1. **Web-Based Setup Wizard**: The recommended way to configure the platform is through the setup wizard, which guides you through all configuration options with a user-friendly interface.

2. **Manual Configuration**: Advanced users can edit the `.env` file directly. This file is created by the setup wizard with your chosen settings, but can be modified manually if needed.

Important configuration options:
- `JWT_SECRET`: Secret key for JWT token generation
- `MEOWCOIN_RPC_USER` and `MEOWCOIN_RPC_PASSWORD`: Credentials for the MeowCoin node
- `DATABASE_TYPE`: Type of database to use (sqlite, postgresql)
- `POSTGRES_PASSWORD`: Password for the PostgreSQL database (if using PostgreSQL)
- `GRAFANA_ADMIN_PASSWORD`: Password for the Grafana admin user
- `RABBITMQ_USER` and `RABBITMQ_PASSWORD`: Credentials for RabbitMQ
- `ENABLE_MFA`: Enable Multi-Factor Authentication
- `ENABLE_ANALYTICS`: Enable the analytics engine

## Documentation

- [User Guide](./docs/user-guide/README.md)
- [API Reference](./docs/api-reference/README.md)
- [Developer Guide](./docs/developer-guide/README.md)
- [Deployment Guide](./docs/deployment-guide/README.md)
- [Security Guide](./docs/security-guide/README.md)

## License

MIT