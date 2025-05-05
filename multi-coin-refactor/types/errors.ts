/**
 * Custom Error Classes
 * Standardized error handling for the application
 */

/**
 * Base Application Error
 * All custom errors should extend this class
 */
export class AppError extends Error {
  public readonly statusCode: number;
  public readonly code: string;
  public readonly details?: unknown;
  public readonly isOperational: boolean;

  constructor(
    message: string,
    statusCode = 500,
    code = 'INTERNAL_ERROR',
    details?: unknown,
    isOperational = true
  ) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
    this.isOperational = isOperational;
    
    // Capture stack trace
    Error.captureStackTrace(this, this.constructor);
    
    // Set the prototype explicitly
    Object.setPrototypeOf(this, AppError.prototype);
  }
}

/**
 * Bad Request Error
 * For invalid input or validation errors
 */
export class BadRequestError extends AppError {
  constructor(message = 'Bad request', code = 'BAD_REQUEST', details?: unknown) {
    super(message, 400, code, details, true);
    Object.setPrototypeOf(this, BadRequestError.prototype);
  }
}

/**
 * Unauthorized Error
 * For authentication errors
 */
export class UnauthorizedError extends AppError {
  constructor(message = 'Unauthorized', code = 'UNAUTHORIZED', details?: unknown) {
    super(message, 401, code, details, true);
    Object.setPrototypeOf(this, UnauthorizedError.prototype);
  }
}

/**
 * Forbidden Error
 * For authorization errors
 */
export class ForbiddenError extends AppError {
  constructor(message = 'Forbidden', code = 'FORBIDDEN', details?: unknown) {
    super(message, 403, code, details, true);
    Object.setPrototypeOf(this, ForbiddenError.prototype);
  }
}

/**
 * Not Found Error
 * For resource not found errors
 */
export class NotFoundError extends AppError {
  constructor(message = 'Not found', code = 'NOT_FOUND', details?: unknown) {
    super(message, 404, code, details, true);
    Object.setPrototypeOf(this, NotFoundError.prototype);
  }
}

/**
 * Conflict Error
 * For resource conflicts
 */
export class ConflictError extends AppError {
  constructor(message = 'Conflict', code = 'CONFLICT', details?: unknown) {
    super(message, 409, code, details, true);
    Object.setPrototypeOf(this, ConflictError.prototype);
  }
}

/**
 * Too Many Requests Error
 * For rate limiting
 */
export class TooManyRequestsError extends AppError {
  constructor(message = 'Too many requests', code = 'TOO_MANY_REQUESTS', details?: unknown) {
    super(message, 429, code, details, true);
    Object.setPrototypeOf(this, TooManyRequestsError.prototype);
  }
}

/**
 * Internal Server Error
 * For unexpected server errors
 */
export class InternalServerError extends AppError {
  constructor(message = 'Internal server error', code = 'INTERNAL_ERROR', details?: unknown) {
    super(message, 500, code, details, false);
    Object.setPrototypeOf(this, InternalServerError.prototype);
  }
}

/**
 * Service Unavailable Error
 * For temporary service unavailability
 */
export class ServiceUnavailableError extends AppError {
  constructor(message = 'Service unavailable', code = 'SERVICE_UNAVAILABLE', details?: unknown) {
    super(message, 503, code, details, true);
    Object.setPrototypeOf(this, ServiceUnavailableError.prototype);
  }
}

/**
 * Validation Error
 * For input validation errors
 */
export class ValidationError extends BadRequestError {
  constructor(message = 'Validation error', details?: unknown) {
    super(message, 'VALIDATION_ERROR', details);
    Object.setPrototypeOf(this, ValidationError.prototype);
  }
}

/**
 * Database Error
 * For database-related errors
 */
export class DatabaseError extends AppError {
  constructor(message = 'Database error', code = 'DATABASE_ERROR', details?: unknown) {
    super(message, 500, code, details, false);
    Object.setPrototypeOf(this, DatabaseError.prototype);
  }
}

/**
 * External Service Error
 * For errors from external services
 */
export class ExternalServiceError extends AppError {
  constructor(message = 'External service error', code = 'EXTERNAL_SERVICE_ERROR', details?: unknown) {
    super(message, 502, code, details, true);
    Object.setPrototypeOf(this, ExternalServiceError.prototype);
  }
}