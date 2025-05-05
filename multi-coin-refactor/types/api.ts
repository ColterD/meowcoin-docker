/**
 * API Types
 * Type definitions for API requests and responses
 */

/**
 * Base API Response
 * Common properties for all API responses
 */
export interface ApiResponse {
  success: boolean;
  timestamp: string;
}

/**
 * Error Response
 * Response for failed API requests
 */
export interface ErrorResponse extends ApiResponse {
  success: false;
  error: string;
  details?: unknown;
  code?: string;
}

/**
 * Success Response
 * Response for successful API requests
 */
export interface SuccessResponse<T = unknown> extends ApiResponse {
  success: true;
  data: T;
}

/**
 * Health Check Response
 * Response for health check endpoint
 */
export interface HealthCheckResponse extends ApiResponse {
  success: true;
  status: 'ok' | 'degraded' | 'error';
  version: string;
  uptime: number;
  services?: {
    [key: string]: {
      status: 'ok' | 'degraded' | 'error';
      message?: string;
    };
  };
}

/**
 * Onboarding Request
 * Request for onboarding a new coin
 */
export interface OnboardingRequest {
  coin: string;
  config: {
    rpcUrl: string;
    network: 'mainnet' | 'testnet' | 'regtest';
    enabled?: boolean;
    minConfirmations?: number;
    timeout?: number;
    [key: string]: unknown;
  };
}

/**
 * Onboarding Response
 * Response for successful onboarding
 */
export interface OnboardingResponse extends SuccessResponse {
  data: {
    coin: string;
    configId: string;
    createdAt: string;
  };
}

/**
 * Feedback Request
 * Request for submitting feedback
 */
export interface FeedbackRequest {
  feedback: string;
  user?: {
    id?: string;
    authenticated?: boolean;
    [key: string]: unknown;
  };
  context?: string;
}

/**
 * Feedback Response
 * Response for successful feedback submission
 */
export interface FeedbackResponse extends SuccessResponse {
  data: {
    feedbackId: string;
    createdAt: string;
  };
}

/**
 * Pagination Parameters
 * Common pagination parameters for list endpoints
 */
export interface PaginationParams {
  page?: number;
  limit?: number;
  sort?: string;
  order?: 'asc' | 'desc';
}

/**
 * Paginated Response
 * Response for paginated list endpoints
 */
export interface PaginatedResponse<T> extends SuccessResponse {
  data: T[];
  pagination: {
    total: number;
    page: number;
    limit: number;
    pages: number;
  };
}