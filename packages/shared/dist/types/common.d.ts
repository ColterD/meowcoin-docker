/**
 * Standard API response format
 */
export interface ApiResponse<T> {
    data: T;
    success: boolean;
    message?: string;
    code?: string;
    timestamp: string;
    meta?: {
        page?: number;
        limit?: number;
        total?: number;
        [key: string]: any;
    };
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
    startTime?: string;
    endTime?: string;
}
/**
 * Health status response
 */
export interface HealthStatus {
    status: 'healthy' | 'degraded' | 'unhealthy';
    version: string;
    uptime: number;
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
export declare enum ErrorCode {
    UNAUTHORIZED = "UNAUTHORIZED",
    FORBIDDEN = "FORBIDDEN",
    NOT_FOUND = "NOT_FOUND",
    VALIDATION_ERROR = "VALIDATION_ERROR",
    INTERNAL_SERVER_ERROR = "INTERNAL_SERVER_ERROR",
    SERVICE_UNAVAILABLE = "SERVICE_UNAVAILABLE",
    RATE_LIMIT_EXCEEDED = "RATE_LIMIT_EXCEEDED",
    BLOCKCHAIN_ERROR = "BLOCKCHAIN_ERROR",
    NODE_ERROR = "NODE_ERROR",
    DATABASE_ERROR = "DATABASE_ERROR"
}
/**
 * Custom application error
 */
export declare class AppError extends Error {
    code: ErrorCode;
    statusCode: number;
    details?: any;
    constructor(code: ErrorCode, message: string, statusCode?: number, details?: any);
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
