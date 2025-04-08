# MeowCoin Node Dashboard

An all-in-one solution for running and monitoring a MeowCoin blockchain node. This application provides both the MeowCoin node and a real-time monitoring dashboard in a single Docker container.

## Features

- Complete MeowCoin node with RPC capabilities
- Real-time node monitoring dashboard
- Blockchain data visualization (blocks, sync status, connections)
- Node control (start/stop/restart) via web interface
- Resource usage monitoring (CPU, memory, disk)
- Auto-refreshing data (every 10 seconds)
- Dark/light mode support
- Mobile-responsive design
- Persistent blockchain storage

## Architecture

This project combines:

1. **MeowCoin Node**: Full blockchain node with RPC capabilities
2. **Dashboard Backend**: Express.js server connecting to the node via RPC
3. **Dashboard Frontend**: Modern web interface for monitoring and control

## Prerequisites

- Docker and Docker Compose

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/meowcoin-docker.git
   cd meowcoin-docker/MeowCoin-Node-Dashboard
   ```

2. (Optional) Create a `.env` file to customize settings:
   ```
   NODE_API_KEY=your_custom_api_key
   JWT_SECRET=your_custom_jwt_secret
   ```

3. Build and start the container:
   ```bash
   docker-compose up -d
   ```

4. Access the dashboard at http://localhost:3000

## Exposed Ports

- **3000**: Dashboard web interface
- **9332**: MeowCoin RPC port (for wallet connections)
- **9333**: MeowCoin P2P port (for blockchain network)

## Persistent Data

The container uses Docker volumes for data persistence:

- `blockchain_data`: Stores the blockchain data
- `meowcoin_config`: Stores MeowCoin configuration

This ensures your blockchain data is preserved between container restarts.

## Configuration

### MeowCoin Node Configuration

The MeowCoin node uses a standard configuration with the following settings:

```
server=1
rpcuser=meowcoinuser
rpcpassword=meowcoinpassword
rpcallowip=127.0.0.1
rpcport=9332
listen=1
daemon=1
txindex=1
```

You can customize these by modifying the `config/meowcoin.conf` file.

### Environment Variables

- `NODE_ENV`: Set to `production` or `development`
- `PORT`: Dashboard web port (default: 3000)
- `NODE_API_KEY`: API key for securing endpoints
- `JWT_SECRET`: Secret for JWT token generation
- `SYNC_INTERVAL`: Data refresh interval in milliseconds
- `MAX_CONNECTIONS`: Maximum WebSocket connections

## Development

For local development, you'll need Node.js 18+ and npm:

1. Install dependencies:
   ```bash
   npm install
   ```

2. Start in development mode:
   ```bash
   npm run dev
   ```

## Features Details

- **Real-time monitoring**: Dashboard updates every 10 seconds
- **Block tracking**: View latest block, height, and time since last block
- **Network stats**: Hashrate, difficulty, block reward, total supply
- **Resource monitoring**: CPU, memory, and disk usage
- **Node control**: Start, stop, and restart the MeowCoin node
- **Dark mode**: Automatically adapts to system preferences

## License

MIT
