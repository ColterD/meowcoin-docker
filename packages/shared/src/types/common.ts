/**
 * Standard API response format
 */
export interface ApiResponseMeta {
  [key: string]: string | number | boolean | undefined;
}

export interface ApiResponse<T> {
  data: T;
  success: boolean;
  message?: string;
  code?: string;
  timestamp: string;
  meta?: ApiResponseMeta;
}

/**
 * Pagination parameters
 */
export interface PaginationParams {
  page: number;
  limit: number;
  sort?: string;
  order?: 'asc' | 'desc';
}

/**
 * Time range filter
 */
export interface TimeRangeFilter {
  startTime?: string; // ISO date string
  endTime?: string; // ISO date string
}

/**
 * Health status response
 */
export interface HealthStatus {
  status: 'healthy' | 'degraded' | 'unhealthy';
  version: string;
  uptime: number; // in seconds
  timestamp: string;
  services?: {
    [serviceName: string]: {
      status: 'healthy' | 'degraded' | 'unhealthy';
      message?: string;
    };
  };
}

/**
 * Error codes
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
// eslint-disable-next-line no-unused-vars
export enum ErrorCode {
  UNAUTHORIZED = 'UNAUTHORIZED',
  FORBIDDEN = 'FORBIDDEN',
  NOT_FOUND = 'NOT_FOUND',
  VALIDATION_ERROR = 'VALIDATION_ERROR',
  INTERNAL_SERVER_ERROR = 'INTERNAL_SERVER_ERROR',
  SERVICE_UNAVAILABLE = 'SERVICE_UNAVAILABLE',
  RATE_LIMIT_EXCEEDED = 'RATE_LIMIT_EXCEEDED',
  BLOCKCHAIN_ERROR = 'BLOCKCHAIN_ERROR',
  NODE_ERROR = 'NODE_ERROR',
  DATABASE_ERROR = 'DATABASE_ERROR',
}

// Structured error details for AppError
export type AppErrorDetails<T = unknown> = T;

/**
 * Custom application error
 */
export class AppError<T = unknown> extends Error {
  code: ErrorCode;
  statusCode: number;
  details?: AppErrorDetails<T>;

  constructor(code: ErrorCode, message: string, statusCode: number = 500, details?: AppErrorDetails<T>) {
    super(message);
    this.name = 'AppError';
    this.code = code;
    this.statusCode = statusCode;
    this.details = details;
  }
}

/**
 * Feature flags
 */
export interface FeatureFlags {
  enableMfa: boolean;
  enableAnalytics: boolean;
  enableNotifications: boolean;
  enableAutoBackup: boolean;
  enableAdvancedCharts: boolean;
  enableMultiNode: boolean;
  enableSmartContracts: boolean;
  [key: string]: boolean;
}