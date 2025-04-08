import { MAX_CPU_USAGE, MAX_MEMORY_USAGE, MAX_DISK_USAGE, DEFAULT_PORT } from './constants';

export interface EnvironmentConfig {
  apiUrl: string;
  socketUrl: string;
  nodeApiKey: string;
  syncInterval: number;
  jwtSecret: string;
  maxConnections: number;
}

// This allows both frontend and backend to have consistent configuration
// while still respecting their different environment variable patterns
export const getConfig = (env: Record<string, string | undefined> = process.env): EnvironmentConfig => ({
  apiUrl: env.REACT_APP_API_URL || env.API_URL || '/api',
  socketUrl: env.REACT_APP_SOCKET_URL || env.SOCKET_URL || '',
  nodeApiKey: env.NODE_API_KEY || '',
  syncInterval: Number(env.SYNC_INTERVAL) || 5000,
  jwtSecret: env.JWT_SECRET || 'default_secret',
  maxConnections: Number(env.MAX_CONNECTIONS) || 100,
});

export const getResourceLimits = () => ({
  cpu: MAX_CPU_USAGE,
  memory: MAX_MEMORY_USAGE,
  disk: MAX_DISK_USAGE,
});

export const getDefaultPort = (): number => {
  return Number(process.env.PORT) || DEFAULT_PORT;
};