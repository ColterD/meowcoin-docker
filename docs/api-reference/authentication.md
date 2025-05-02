# Authentication API

This document describes the authentication endpoints for the MeowCoin Platform API.

## Login

```
POST /auth/login
```

Authenticates a user and returns a JWT token.

### Request Body

```json
{
  "username": "admin",
  "password": "your_password",
  "mfaCode": "123456" // Optional
}
```

### Response

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

## Refresh Token

```
POST /auth/refresh-token
```

Refreshes an expired JWT token.

### Request Body

```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### Response

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

## Logout

```
POST /auth/logout
```

Invalidates a refresh token.

### Request Body

```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### Response

```json
{
  "success": true,
  "message": "Logged out successfully",
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

## Get Current User

```
GET /auth/me
```

Returns information about the currently authenticated user.

### Response

```json
{
  "success": true,
  "data": {
    "id": "user_id",
    "username": "admin",
    "email": "admin@example.com",
    "firstName": "Admin",
    "lastName": "User",
    "role": "admin",
    "status": "active",
    "createdAt": "2025-01-01T00:00:00.000Z",
    "updatedAt": "2025-05-02T12:34:56.789Z",
    "lastLogin": "2025-05-02T12:00:00.000Z",
    "preferences": {
      "theme": "dark",
      "language": "en",
      "timezone": "UTC"
    },
    "mfaEnabled": false
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

## Setup MFA

```
POST /auth/mfa/setup
```

Initiates the setup of multi-factor authentication.

### Request Body

```json
{
  "method": "totp" // "totp", "sms", or "email"
}
```

### Response

```json
{
  "success": true,
  "data": {
    "secret": "ABCDEFGHIJKLMNOP", // Only for TOTP
    "qrCode": "data:image/png;base64,...", // Only for TOTP
    "verificationCode": "123456", // Only for SMS or email
    "expiresAt": "2025-05-02T13:34:56.789Z"
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

## Verify MFA Setup

```
POST /auth/mfa/verify
```

Verifies and completes the setup of multi-factor authentication.

### Request Body

```json
{
  "method": "totp",
  "code": "123456"
}
```

### Response

```json
{
  "success": true,
  "data": {
    "mfaEnabled": true,
    "recoveryCodes": [
      "abcd-efgh-ijkl-mnop",
      "qrst-uvwx-yzab-cdef",
      "ghij-klmn-opqr-stuv"
    ]
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```

## Disable MFA

```
POST /auth/mfa/disable
```

Disables multi-factor authentication.

### Request Body

```json
{
  "password": "your_password",
  "code": "123456" // MFA code or recovery code
}
```

### Response

```json
{
  "success": true,
  "data": {
    "mfaEnabled": false
  },
  "timestamp": "2025-05-02T12:34:56.789Z"
}
```