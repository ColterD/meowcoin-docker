/**
 * System constants
 */

// Default ports
export const DEFAULT_API_PORT = 8080;
export const DEFAULT_DASHBOARD_PORT = 3000;
export const DEFAULT_MEOWCOIN_RPC_PORT = 9332;
export const DEFAULT_MEOWCOIN_P2P_PORT = 9333;

// Resource thresholds
export const CPU_WARNING_THRESHOLD = 80;
export const CPU_CRITICAL_THRESHOLD = 90;
export const MEMORY_WARNING_THRESHOLD = 80;
export const MEMORY_CRITICAL_THRESHOLD = 90;
export const DISK_WARNING_THRESHOLD = 80;
export const DISK_CRITICAL_THRESHOLD = 90;

// Sync intervals (in milliseconds)
export const DEFAULT_SYNC_INTERVAL = 5000;
export const FAST_SYNC_INTERVAL = 1000;
export const SLOW_SYNC_INTERVAL = 30000;

// Pagination defaults
export const DEFAULT_PAGE_SIZE = 20;
export const MAX_PAGE_SIZE = 100;

// Authentication
export const DEFAULT_TOKEN_EXPIRY = '24h';
export const DEFAULT_REFRESH_TOKEN_EXPIRY = '7d';
export const PASSWORD_MIN_LENGTH = 12;
export const PASSWORD_REQUIRES_LOWERCASE = true;
export const PASSWORD_REQUIRES_UPPERCASE = true;
export const PASSWORD_REQUIRES_NUMBER = true;
export const PASSWORD_REQUIRES_SYMBOL = true;
export const MAX_LOGIN_ATTEMPTS = 5;
export const LOCKOUT_DURATION = 15 * 60 * 1000; // 15 minutes in milliseconds

// Rate limiting
export const DEFAULT_RATE_LIMIT_WINDOW = 60 * 1000; // 1 minute in milliseconds
export const DEFAULT_RATE_LIMIT_MAX_REQUESTS = 100;
export const API_RATE_LIMIT_WINDOW = 60 * 1000; // 1 minute in milliseconds
export const API_RATE_LIMIT_MAX_REQUESTS = 1000;

// WebSocket
export const WS_PING_INTERVAL = 30000; // 30 seconds in milliseconds
export const WS_PING_TIMEOUT = 5000; // 5 seconds in milliseconds
export const WS_MAX_CONNECTIONS = 1000;

// Cache
export const DEFAULT_CACHE_TTL = 60; // 60 seconds
export const LONG_CACHE_TTL = 3600; // 1 hour in seconds
export const SHORT_CACHE_TTL = 10; // 10 seconds

// Backup
export const DEFAULT_BACKUP_INTERVAL = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
export const DEFAULT_BACKUP_RETENTION = 7; // 7 days

// Notification
export const DEFAULT_NOTIFICATION_EXPIRY = 30 * 24 * 60 * 60 * 1000; // 30 days in milliseconds