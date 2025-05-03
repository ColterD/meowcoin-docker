"use strict";
/**
 * System constants
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.DEFAULT_NOTIFICATION_EXPIRY = exports.DEFAULT_BACKUP_RETENTION = exports.DEFAULT_BACKUP_INTERVAL = exports.SHORT_CACHE_TTL = exports.LONG_CACHE_TTL = exports.DEFAULT_CACHE_TTL = exports.WS_MAX_CONNECTIONS = exports.WS_PING_TIMEOUT = exports.WS_PING_INTERVAL = exports.API_RATE_LIMIT_MAX_REQUESTS = exports.API_RATE_LIMIT_WINDOW = exports.DEFAULT_RATE_LIMIT_MAX_REQUESTS = exports.DEFAULT_RATE_LIMIT_WINDOW = exports.LOCKOUT_DURATION = exports.MAX_LOGIN_ATTEMPTS = exports.PASSWORD_REQUIRES_SYMBOL = exports.PASSWORD_REQUIRES_NUMBER = exports.PASSWORD_REQUIRES_UPPERCASE = exports.PASSWORD_REQUIRES_LOWERCASE = exports.PASSWORD_MIN_LENGTH = exports.DEFAULT_REFRESH_TOKEN_EXPIRY = exports.DEFAULT_TOKEN_EXPIRY = exports.MAX_PAGE_SIZE = exports.DEFAULT_PAGE_SIZE = exports.SLOW_SYNC_INTERVAL = exports.FAST_SYNC_INTERVAL = exports.DEFAULT_SYNC_INTERVAL = exports.DISK_CRITICAL_THRESHOLD = exports.DISK_WARNING_THRESHOLD = exports.MEMORY_CRITICAL_THRESHOLD = exports.MEMORY_WARNING_THRESHOLD = exports.CPU_CRITICAL_THRESHOLD = exports.CPU_WARNING_THRESHOLD = exports.DEFAULT_MEOWCOIN_P2P_PORT = exports.DEFAULT_MEOWCOIN_RPC_PORT = exports.DEFAULT_DASHBOARD_PORT = exports.DEFAULT_API_PORT = void 0;
// Default ports
exports.DEFAULT_API_PORT = 8080;
exports.DEFAULT_DASHBOARD_PORT = 3000;
exports.DEFAULT_MEOWCOIN_RPC_PORT = 9332;
exports.DEFAULT_MEOWCOIN_P2P_PORT = 9333;
// Resource thresholds
exports.CPU_WARNING_THRESHOLD = 80;
exports.CPU_CRITICAL_THRESHOLD = 90;
exports.MEMORY_WARNING_THRESHOLD = 80;
exports.MEMORY_CRITICAL_THRESHOLD = 90;
exports.DISK_WARNING_THRESHOLD = 80;
exports.DISK_CRITICAL_THRESHOLD = 90;
// Sync intervals (in milliseconds)
exports.DEFAULT_SYNC_INTERVAL = 5000;
exports.FAST_SYNC_INTERVAL = 1000;
exports.SLOW_SYNC_INTERVAL = 30000;
// Pagination defaults
exports.DEFAULT_PAGE_SIZE = 20;
exports.MAX_PAGE_SIZE = 100;
// Authentication
exports.DEFAULT_TOKEN_EXPIRY = '24h';
exports.DEFAULT_REFRESH_TOKEN_EXPIRY = '7d';
exports.PASSWORD_MIN_LENGTH = 12;
exports.PASSWORD_REQUIRES_LOWERCASE = true;
exports.PASSWORD_REQUIRES_UPPERCASE = true;
exports.PASSWORD_REQUIRES_NUMBER = true;
exports.PASSWORD_REQUIRES_SYMBOL = true;
exports.MAX_LOGIN_ATTEMPTS = 5;
exports.LOCKOUT_DURATION = 15 * 60 * 1000; // 15 minutes in milliseconds
// Rate limiting
exports.DEFAULT_RATE_LIMIT_WINDOW = 60 * 1000; // 1 minute in milliseconds
exports.DEFAULT_RATE_LIMIT_MAX_REQUESTS = 100;
exports.API_RATE_LIMIT_WINDOW = 60 * 1000; // 1 minute in milliseconds
exports.API_RATE_LIMIT_MAX_REQUESTS = 1000;
// WebSocket
exports.WS_PING_INTERVAL = 30000; // 30 seconds in milliseconds
exports.WS_PING_TIMEOUT = 5000; // 5 seconds in milliseconds
exports.WS_MAX_CONNECTIONS = 1000;
// Cache
exports.DEFAULT_CACHE_TTL = 60; // 60 seconds
exports.LONG_CACHE_TTL = 3600; // 1 hour in seconds
exports.SHORT_CACHE_TTL = 10; // 10 seconds
// Backup
exports.DEFAULT_BACKUP_INTERVAL = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
exports.DEFAULT_BACKUP_RETENTION = 7; // 7 days
// Notification
exports.DEFAULT_NOTIFICATION_EXPIRY = 30 * 24 * 60 * 60 * 1000; // 30 days in milliseconds
