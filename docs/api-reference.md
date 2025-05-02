# MeowCoin Platform API Reference

This document provides a reference for the MeowCoin Platform API endpoints.

## Base URL

All API endpoints are relative to the base URL:

```
https://api.meowcoin.com/api
```

For local development:

```
http://localhost:8080/api
```

## Authentication

Most API endpoints require authentication. Include an `Authorization` header with a valid JWT token:

```
Authorization: Bearer <your_jwt_token>
```

To obtain a token, use the authentication endpoints described below.

## Response Format

All API responses follow a standard format:

```json
{
  "success": true,
  "data": { ... },
  "message": "Optional message",
  "code": "Optional code",
  "timestamp": "2025-05-02T12:34:56.789Z",
  "meta": {
    "page": 1,
    "limit": 10,
    "total": 100
  }
}
```

Error responses:

```json
{
  "success": false,
  "message": "Error message",
  "code": "ERROR_CODE",
  "timestamp": "2025-05-02T12:34:56.789Z",
  "details": { ... }
}
```

## Authentication Endpoints

### Login

```
POST /auth/login
```

Request body:

```json
{
  "username": "admin",
  "password": "your_password",
  "mfaCode": "123456" // Optional
}
```

Response:

```json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": 3600,
    "tokenType": "Bearer",
    "user": {
      "id": "user_id",
      "username": "admin",
      "email": "admin@example.com",
      "role": "admin"
    },
    "requiresMfa": false
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

### Refresh Token

```
POST /auth/refresh-token
```

Request body:

```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

Response:

```json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": 3600,
    "tokenType": "Bearer"
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

### Logout

```
POST /auth/logout
```

Request body:

```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

Response:

```json
{
  "success": true,
  "message": "Logged out successfully",
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

## Node Endpoints

### Get All Nodes

```
GET /nodes
```

Query parameters:
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 10)
- `sort`: Field to sort by (default: "createdAt")
- `order`: Sort order ("asc" or "desc", default: "desc")

Response:

```json
{
  "success": true,
  "data": [
    {
      "id": "node_id",
      "name": "MeowNode-1",
      "type": "full_node",
      "status": "running",
      "version": "1.2.3",
      "resources": {
        "cpuUsage": 45.2,
        "memoryUsage": 60.5,
        "diskUsage": 30.1,
        "networkInbound": 1024,
        "networkOutbound": 512,
        "connections": 8,
        "lastUpdated": "2025-05-02T12:34:56.789Z"
      },
      "blockHeight": 12345,
      "lastBlockTime": "2025-05-02T12:30:00.000Z",
      "syncProgress": 100,
      "uptime": 86400
    }
  ],
  "timestamp": "2025-05-02T12:34:56.789Z",
  "meta": {
    "page": 1,
    "limit": 10,
    "total": 1
  }
}
```

### Get Node by ID

```
GET /nodes/:id
```

Response:

```json
{
  "success": true,
  "data": {
    "id": "node_id",
    "name": "MeowNode-1",
    "type": "full_node",
    "status": "running",
    "version": "1.2.3",
    "resources": {
      "cpuUsage": 45.2,
      "memoryUsage": 60.5,
      "diskUsage": 30.1,
      "networkInbound": 1024,
      "networkOutbound": 512,
      "connections": 8,
      "lastUpdated": "2025-05-02T12:34:56.789Z"
    },
    "network": "mainnet",
    "syncProgress": 100,
    "blockHeight": 12345,
    "lastBlockTime": "2025-05-02T12:30:00.000Z",
    "peerCount": 8,
    "uptime": 86400,
    "createdAt": "2025-05-01T00:00:00.000Z",
    "updatedAt": "2025-05-02T12:34:56.789Z"
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

### Create Node

```
POST /nodes
```

Request body:

```json
{
  "name": "MeowNode-2",
  "type": "full_node",
  "rpcEnabled": true,
  "rpcPort": 9332,
  "p2pPort": 9333,
  "dataDir": "/data/meowcoin",
  "maxConnections": 125,
  "autoStart": true
}
```

Response:

```json
{
  "success": true,
  "data": {
    "id": "new_node_id",
    "name": "MeowNode-2",
    "type": "full_node",
    "status": "starting",
    "createdAt": "2025-05-02T12:34:56.789Z",
    "updatedAt": "2025-05-02T12:34:56.789Z"
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

### Update Node

```
PATCH /nodes/:id
```

Request body:

```json
{
  "name": "MeowNode-2-Updated",
  "rpcEnabled": false,
  "maxConnections": 100
}
```

Response:

```json
{
  "success": true,
  "data": {
    "id": "node_id",
    "name": "MeowNode-2-Updated",
    "type": "full_node",
    "status": "running",
    "rpcEnabled": false,
    "maxConnections": 100,
    "updatedAt": "2025-05-02T12:34:56.789Z"
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

### Delete Node

```
DELETE /nodes/:id
```

Response:

```json
{
  "success": true,
  "message": "Node deleted successfully",
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

### Perform Node Action

```
POST /nodes/:id/actions
```

Request body:

```json
{
  "action": "restart"
}
```

Valid actions: `start`, `stop`, `restart`, `backup`, `restore`, `update`, `reset`

Response:

```json
{
  "success": true,
  "data": {
    "id": "node_id",
    "status": "running",
    "updatedAt": "2025-05-02T12:34:56.789Z"
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

### Get Node Metrics

```
GET /nodes/:id/metrics
```

Query parameters:
- `timeRange`: Time range ("1h", "6h", "24h", "7d", "30d")
- `interval`: Data interval ("minute", "hour", "day")

Response:

```json
{
  "success": true,
  "data": {
    "cpu": [
      { "timestamp": "2025-05-02T12:00:00.000Z", "value": 45.2 },
      { "timestamp": "2025-05-02T12:05:00.000Z", "value": 46.5 }
    ],
    "memory": [
      { "timestamp": "2025-05-02T12:00:00.000Z", "value": 60.5 },
      { "timestamp": "2025-05-02T12:05:00.000Z", "value": 61.2 }
    ],
    "disk": [
      { "timestamp": "2025-05-02T12:00:00.000Z", "value": 30.1 },
      { "timestamp": "2025-05-02T12:05:00.000Z", "value": 30.2 }
    ],
    "network": {
      "inbound": [
        { "timestamp": "2025-05-02T12:00:00.000Z", "value": 1024 },
        { "timestamp": "2025-05-02T12:05:00.000Z", "value": 1056 }
      ],
      "outbound": [
        { "timestamp": "2025-05-02T12:00:00.000Z", "value": 512 },
        { "timestamp": "2025-05-02T12:05:00.000Z", "value": 528 }
      ]
    },
    "connections": [
      { "timestamp": "2025-05-02T12:00:00.000Z", "value": 8 },
      { "timestamp": "2025-05-02T12:05:00.000Z", "value": 9 }
    ]
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

## Blockchain Endpoints

### Get Blockchain Info

```
GET /blockchain/info
```

Response:

```json
{
  "success": true,
  "data": {
    "chain": "main",
    "blocks": 12345,
    "headers": 12345,
    "bestblockhash": "000000000000000000025f...",
    "difficulty": 123456789,
    "mediantime": 1714654321,
    "verificationprogress": 1,
    "initialblockdownload": false,
    "chainwork": "000000000000000000000...",
    "size_on_disk": 1073741824,
    "pruned": false
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

### Get Block by Hash or Height

```
GET /blockchain/blocks/:hashOrHeight
```

Response:

```json
{
  "success": true,
  "data": {
    "hash": "000000000000000000025f...",
    "height": 12345,
    "confirmations": 100,
    "size": 1234,
    "weight": 4936,
    "version": 536870912,
    "versionHex": "20000000",
    "merkleroot": "abc123...",
    "time": 1714654321,
    "mediantime": 1714654000,
    "nonce": 987654321,
    "bits": "1d00ffff",
    "difficulty": 123456789,
    "chainwork": "000000000000000000000...",
    "nTx": 10,
    "previousblockhash": "000000000000000000025e...",
    "nextblockhash": "000000000000000000025g...",
    "strippedsize": 1000,
    "tx": ["txid1", "txid2", "..."]
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

### Get Transaction by ID

```
GET /blockchain/transactions/:txid
```

Response:

```json
{
  "success": true,
  "data": {
    "txid": "abc123...",
    "hash": "abc123...",
    "version": 2,
    "size": 225,
    "vsize": 225,
    "weight": 900,
    "locktime": 0,
    "vin": [...],
    "vout": [...],
    "hex": "...",
    "blockhash": "000000000000000000025f...",
    "confirmations": 100,
    "time": 1714654321,
    "blocktime": 1714654321,
    "fee": 0.0001
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

### Send Transaction

```
POST /blockchain/transactions
```

Request body:

```json
{
  "hex": "signed_transaction_hex"
}
```

Response:

```json
{
  "success": true,
  "data": {
    "txid": "abc123..."
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

## Analytics Endpoints

### Get Dashboard Summary

```
GET /analytics/dashboard
```

Response:

```json
{
  "success": true,
  "data": {
    "blockchainMetrics": {
      "blockHeight": 12345,
      "blockTime": 600,
      "difficulty": 123456789,
      "hashRate": 1000000000000,
      "transactionCount": 1000,
      "mempoolSize": 5000000,
      "mempoolTransactions": 100,
      "averageFee": 0.0001,
      "medianFee": 0.00005,
      "totalSupply": 21000000,
      "timestamp": "2025-05-02T12:34:56.789Z"
    },
    "nodePerformance": [...],
    "recentBlocks": [...],
    "recentTransactions": {...},
    "networkStatus": {...},
    "alerts": {
      "critical": 0,
      "warning": 1,
      "info": 3
    },
    "timestamp": "2025-05-02T12:34:56.789Z"
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

### Get Chart Data

```
GET /analytics/charts/:chartId
```

Query parameters:
- `timeRange`: Time range ("1h", "6h", "24h", "7d", "30d")
- `interval`: Data interval ("minute", "hour", "day")

Response:

```json
{
  "success": true,
  "data": {
    "title": "Transaction Volume",
    "series": [
      {
        "name": "Transaction Count",
        "data": [
          { "timestamp": "2025-05-02T12:00:00.000Z", "value": 100 },
          { "timestamp": "2025-05-02T13:00:00.000Z", "value": 120 }
        ],
        "unit": "transactions"
      },
      {
        "name": "Transaction Volume",
        "data": [
          { "timestamp": "2025-05-02T12:00:00.000Z", "value": 1000 },
          { "timestamp": "2025-05-02T13:00:00.000Z", "value": 1200 }
        ],
        "unit": "MeowCoin"
      }
    ],
    "timeRange": {
      "start": "2025-05-02T00:00:00.000Z",
      "end": "2025-05-02T23:59:59.999Z"
    },
    "interval": "hour"
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

## Notification Endpoints

### Get Notifications

```
GET /notifications
```

Query parameters:
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 10)
- `type`: Filter by notification type
- `read`: Filter by read status (true/false)

Response:

```json
{
  "success": true,
  "data": [
    {
      "id": "notification_id",
      "type": "node_status",
      "title": "Node Offline",
      "message": "MeowNode-1 is offline",
      "priority": "high",
      "status": "delivered",
      "createdAt": "2025-05-02T12:34:56.789Z",
      "readAt": null,
      "data": {
        "nodeId": "node_id"
      },
      "link": "/nodes/node_id"
    }
  ],
  "timestamp": "2025-05-02T12:34:56.789Z",
  "meta": {
    "page": 1,
    "limit": 10,
    "total": 1,
    "unread": 1
  }
}
```

### Mark Notification as Read

```
PATCH /notifications/:id/read
```

Response:

```json
{
  "success": true,
  "data": {
    "id": "notification_id",
    "status": "read",
    "readAt": "2025-05-02T12:34:56.789Z"
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

### Update Notification Settings

```
PUT /notifications/settings
```

Request body:

```json
{
  "channels": {
    "email": true,
    "sms": false,
    "push": true,
    "in_app": true
  },
  "preferences": {
    "node_status": ["high", "critical"],
    "blockchain_sync": ["critical"],
    "transaction": ["high", "critical"],
    "system": ["critical"]
  },
  "quietHours": {
    "enabled": true,
    "start": "22:00",
    "end": "08:00",
    "timezone": "America/New_York",
    "bypassForCritical": true
  }
}
```

Response:

```json
{
  "success": true,
  "data": {
    "userId": "user_id",
    "channels": {...},
    "preferences": {...},
    "quietHours": {...},
    "updatedAt": "2025-05-02T12:34:56.789Z"
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

## WebSocket API

Connect to the WebSocket endpoint:

```
ws://api.meowcoin.com/ws
```

For local development:

```
ws://localhost:8080/ws
```

### Authentication

Send authentication message after connecting:

```json
{
  "type": "authenticate",
  "token": "your_jwt_token"
}
```

### Node Updates

Subscribe to node updates:

```json
{
  "type": "subscribe",
  "channel": "node-updates",
  "nodeId": "node_id" // Optional, omit for all nodes
}
```

Receive node updates:

```json
{
  "type": "node-update",
  "data": {
    "id": "node_id",
    "status": "running",
    "resources": {
      "cpuUsage": 45.2,
      "memoryUsage": 60.5,
      "diskUsage": 30.1,
      "networkInbound": 1024,
      "networkOutbound": 512,
      "connections": 8,
      "lastUpdated": "2025-05-02T12:34:56.789Z"
    },
    "blockHeight": 12345,
    "timestamp": "2025-05-02T12:34:56.789Z"
  }
}
```

### Blockchain Updates

Subscribe to blockchain updates:

```json
{
  "type": "subscribe",
  "channel": "blockchain-updates"
}
```

Receive blockchain updates:

```json
{
  "type": "blockchain-update",
  "data": {
    "blockHeight": 12345,
    "transactions": 10,
    "timestamp": "2025-05-02T12:34:56.789Z"
  }
}
```

### Notifications

Subscribe to notifications:

```json
{
  "type": "subscribe",
  "channel": "notifications"
}
```

Receive notifications:

```json
{
  "type": "notification",
  "data": {
    "id": "notification_id",
    "type": "node_status",
    "title": "Node Offline",
    "message": "MeowNode-1 is offline",
    "priority": "high",
    "timestamp": "2025-05-02T12:34:56.789Z"
  }
}
```