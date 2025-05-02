# Node API

This document describes the node management endpoints for the MeowCoin Platform API.

## Get All Nodes

```
GET /nodes
```

Returns a list of all nodes.

### Query Parameters

- `page`: Page number (default: 1)
- `limit`: Items per page (default: 10)
- `sort`: Field to sort by (default: "createdAt")
- `order`: Sort order ("asc" or "desc", default: "desc")
- `status`: Filter by node status (optional)
- `type`: Filter by node type (optional)

### Response

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

## Get Node by ID

```
GET /nodes/:id
```

Returns detailed information about a specific node.

### Response

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

## Create Node

```
POST /nodes
```

Creates a new node.

### Request Body

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

### Response

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

## Update Node

```
PATCH /nodes/:id
```

Updates an existing node.

### Request Body

```json
{
  "name": "MeowNode-2-Updated",
  "rpcEnabled": false,
  "maxConnections": 100
}
```

### Response

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

## Delete Node

```
DELETE /nodes/:id
```

Deletes a node.

### Response

```json
{
  "success": true,
  "message": "Node deleted successfully",
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

## Perform Node Action

```
POST /nodes/:id/actions
```

Performs an action on a node.

### Request Body

```json
{
  "action": "restart"
}
```

Valid actions: `start`, `stop`, `restart`, `backup`, `restore`, `update`, `reset`

### Response

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

## Get Node Metrics

```
GET /nodes/:id/metrics
```

Returns metrics for a specific node.

### Query Parameters

- `timeRange`: Time range ("1h", "6h", "24h", "7d", "30d")
- `interval`: Data interval ("minute", "hour", "day")

### Response

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

## Get Node Logs

```
GET /nodes/:id/logs
```

Returns logs for a specific node.

### Query Parameters

- `lines`: Number of lines to return (default: 100)
- `level`: Log level filter ("debug", "info", "warn", "error")
- `search`: Search term to filter logs

### Response

```json
{
  "success": true,
  "data": {
    "logs": [
      {
        "timestamp": "2025-05-02T12:34:56.789Z",
        "level": "info",
        "message": "Node started successfully"
      },
      {
        "timestamp": "2025-05-02T12:34:55.789Z",
        "level": "info",
        "message": "Loading configuration"
      }
    ],
    "total": 2
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

## Get Node Backups

```
GET /nodes/:id/backups
```

Returns a list of backups for a specific node.

### Response

```json
{
  "success": true,
  "data": [
    {
      "id": "backup_id",
      "nodeId": "node_id",
      "size": 1073741824,
      "blockHeight": 12345,
      "createdAt": "2025-05-02T12:34:56.789Z",
      "status": "completed",
      "location": "s3://meowcoin-backups/node_id/backup_id.tar.gz",
      "checksum": "abc123..."
    }
  ],
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

## Create Node Backup

```
POST /nodes/:id/backups
```

Creates a new backup for a specific node.

### Request Body

```json
{
  "note": "Weekly backup"
}
```

### Response

```json
{
  "success": true,
  "data": {
    "id": "backup_id",
    "nodeId": "node_id",
    "status": "pending",
    "createdAt": "2025-05-02T12:34:56.789Z"
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

## Restore Node from Backup

```
POST /nodes/:id/restore
```

Restores a node from a backup.

### Request Body

```json
{
  "backupId": "backup_id"
}
```

### Response

```json
{
  "success": true,
  "data": {
    "id": "node_id",
    "status": "restoring",
    "updatedAt": "2025-05-02T12:34:56.789Z"
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```