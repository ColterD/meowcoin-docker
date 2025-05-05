/**
 * Error Handler Middleware
 * Centralized error handling for the application
 */
const { recordMetric } = require('../../dist/core/monitoring');

// Import custom error classes if available
let AppError, NotFoundError;
try {
  const errors = require('../../dist/types/errors');
  AppError = errors.AppError;
  NotFoundError = errors.NotFoundError;
} catch (e) {
  // Fallback if custom error classes are not available
  AppError = Error;
  NotFoundError = Error;
}

/**
 * Global error handler middleware
 * @param {Error} err - Error object
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
exports.errorHandler = (err, req, res, next) => {
  // Default error values
  let statusCode = err.statusCode || 500;
  let errorMessage = err.message || 'Internal server error';
  let errorCode = err.code || 'INTERNAL_ERROR';
  let errorDetails = err.details;
  let isOperational = err.isOperational !== undefined ? err.isOperational : false;
  
  // Hide error details in production for non-operational errors
  const showDetails = process.env.NODE_ENV !== 'production' || isOperational;
  
  // Log the error with appropriate level based on severity
  const logLevel = statusCode >= 500 ? 'error' : 'warn';
  
  // Prepare error data for logging
  const errorData = { 
    message: errorMessage,
    code: errorCode,
    statusCode,
    isOperational,
    stack: err.stack,
    path: req.path,
    method: req.method,
    ip: req.ip || req.connection.remoteAddress,
    userAgent: req.headers['user-agent']
  };
  
  // Add request data in development
  if (process.env.NODE_ENV === 'development') {
    errorData.body = req.body;
    errorData.query = req.query;
    errorData.params = req.params;
    errorData.headers = req.headers;
  }
  
  // Record metric for monitoring
  recordMetric({
    type: 'error',
    data: errorData,
    timestamp: new Date().toISOString(),
  });
  
  // Send error response
  res.status(statusCode).json({
    success: false,
    timestamp: new Date().toISOString(),
    error: errorMessage,
    code: errorCode,
    details: showDetails ? errorDetails : undefined,
    stack: process.env.NODE_ENV === 'development' ? err.stack : undefined
  });
};

/**
 * Not found middleware
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
exports.notFound = (req, res, next) => {
  // Create a not found error
  const error = new NotFoundError(
    `The requested resource at ${req.path} was not found`,
    'RESOURCE_NOT_FOUND'
  );
  
  // Pass to error handler
  next(error);
};

/**
 * Async handler wrapper to avoid try/catch blocks in route handlers
 * @param {Function} fn - Async route handler
 * @returns {Function} Express middleware function
 */
exports.asyncHandler = (fn) => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

/**
 * Convert errors from third-party middleware
 * @param {Error} err - Error object
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
exports.convertErrors = (err, req, res, next) => {
  let convertedError = err;
  
  // Convert validation errors
  if (err.name === 'ValidationError') {
    convertedError = new AppError(
      'Validation Error',
      400,
      'VALIDATION_ERROR',
      err.errors,
      true
    );
  }
  
  // Convert JWT errors
  if (err.name === 'JsonWebTokenError') {
    convertedError = new AppError(
      'Invalid token',
      401,
      'INVALID_TOKEN',
      undefined,
      true
    );
  }
  
  // Convert token expiration errors
  if (err.name === 'TokenExpiredError') {
    convertedError = new AppError(
      'Token expired',
      401,
      'TOKEN_EXPIRED',
      undefined,
      true
    );
  }
  
  next(convertedError);
};