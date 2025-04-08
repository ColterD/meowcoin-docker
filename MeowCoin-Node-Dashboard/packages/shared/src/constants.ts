// System defaults
export const DEFAULT_PORT = 3000;
export const DEFAULT_SYNC_INTERVAL = 5000;
export const DEFAULT_MAX_CONNECTIONS = 100;

// Resource limits
export const MAX_CPU_USAGE = 100;
export const MAX_MEMORY_USAGE = 100;
export const MAX_DISK_USAGE = 100;

// Warning thresholds
export const CPU_WARNING_THRESHOLD = 80;
export const MEMORY_WARNING_THRESHOLD = 80;
export const DISK_WARNING_THRESHOLD = 80;

// Authentication
export const TOKEN_EXPIRY = '24h';

// Node statuses
export const NODE_STATUS = {
  RUNNING: 'running',
  STOPPED: 'stopped',
  ERROR: 'error',
} as const;

// Action types
export const NODE_ACTIONS = {
  START: 'start',
  STOP: 'stop',
  RESTART: 'restart',
} as const;