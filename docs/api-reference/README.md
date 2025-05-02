# MeowCoin Platform API Reference

Welcome to the MeowCoin Platform API Reference. This documentation provides detailed information about the MeowCoin Platform API, including endpoints, request/response formats, and authentication.

## Table of Contents

1. [Authentication](./authentication.md)
2. [Node API](./node-api.md)
3. [Blockchain API](./blockchain-api.md)
4. [Analytics API](./analytics-api.md)
5. [User API](./user-api.md)
6. [Notification API](./notification-api.md)
7. [WebSocket API](./websocket-api.md)
8. [Error Handling](./error-handling.md)

## API Overview

The MeowCoin Platform API is a RESTful API that allows you to interact with the platform programmatically. It provides access to all the features available in the web interface, including node management, blockchain data, analytics, and more.

## Base URL

The base URL for all API endpoints is:

```
https://your-platform-domain.com/api
```

Replace `your-platform-domain.com` with the domain where your MeowCoin Platform is hosted.

## Authentication

All API requests require authentication using JSON Web Tokens (JWT). See the [Authentication](./authentication.md) section for details on how to obtain and use tokens.

## Request Format

API requests should be made using HTTP methods (GET, POST, PUT, DELETE) with JSON payloads where applicable. The content type should be set to `application/json`.

## Response Format

All API responses are in JSON format with the following structure:

```json
{
  "success": true,
  "data": { ... },
  "message": "Optional message",
  "code": "Optional code",
  "timestamp": "2025-05-01T12:00:00Z",
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 100
  }
}
```

## Error Handling

In case of an error, the API will return a JSON response with the following structure:

```json
{
  "success": false,
  "message": "Error message",
  "code": "ERROR_CODE",
  "timestamp": "2025-05-01T12:00:00Z",
  "details": { ... }
}
```

See the [Error Handling](./error-handling.md) section for details on error codes and messages.

## Rate Limiting

The API is rate-limited to prevent abuse. The rate limit is 1000 requests per minute per API key. If you exceed the rate limit, you will receive a 429 Too Many Requests response.

## Support

If you need assistance with the API, please contact our support team at api-support@meowcoin.com or visit our [Developer Portal](https://developers.meowcoin.com).