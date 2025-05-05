/**
 * Type Definitions
 * Central export point for all type definitions
 */

// Re-export all types from individual files
export * from './api';
export * from './errors';

/**
 * Environment Variables
 * Type definitions for environment variables
 */
export interface EnvironmentVariables {
  NODE_ENV: 'development' | 'production' | 'test';
  PORT: number;
  HOST: string;
  FEEDBACK_PERSISTENCE: 'memory' | 'file' | 'db';
  ONBOARDING_PERSISTENCE: 'memory' | 'file' | 'db';
  BASE_URL: string;
  JWT_SECRET?: string;
  JWT_EXPIRES_IN?: string;
  LOG_LEVEL: 'error' | 'warn' | 'info' | 'debug';
}

/**
 * Storage Adapter
 * Interface for storage adapters
 */
export interface StorageAdapter<T> {
  save(item: T): Promise<void>;
  getAll(): Promise<T[]>;
  clear(): Promise<void>;
}

/**
 * Logger Interface
 * Interface for logger implementations
 */
export interface Logger {
  error(message: string, meta?: Record<string, unknown>): void;
  warn(message: string, meta?: Record<string, unknown>): void;
  info(message: string, meta?: Record<string, unknown>): void;
  debug(message: string, meta?: Record<string, unknown>): void;
}

/**
 * Metric
 * Interface for metrics
 */
export interface Metric {
  type: string;
  data: Record<string, unknown>;
  timestamp: string;
}

/**
 * Coin Module
 * Interface for coin modules
 */
export interface CoinModule {
  name: string;
  symbol: string;
  configSchema: unknown;
  validateConfig(config: unknown): boolean;
  createRpcClient(config: unknown): unknown;
}

/**
 * User
 * Interface for user data
 */
export interface User {
  id: string;
  username: string;
  email?: string;
  roles: string[];
  createdAt: string;
  updatedAt: string;
}

/**
 * Authentication Result
 * Interface for authentication results
 */
export interface AuthResult {
  user: User;
  token: string;
  expiresAt: string;
}