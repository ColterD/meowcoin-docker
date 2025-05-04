/**
 * Error Handler Middleware
 * Centralized error handling for the application
 */
const { recordMetric } = require('../../dist/core/monitoring');

/**
 * Global error handler middleware
 * @param {Error} err - Error object
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
exports.errorHandler = (err, req, res, next) => {
  // Log the error
  recordMetric({
    type: 'error',
    data: { 
      message: err.message,
      stack: err.stack,
      path: req.path,
      method: req.method,
      body: req.body,
      query: req.query,
      params: req.params,
      headers: req.headers
    },
    timestamp: new Date().toISOString(),
  });
  
  // Determine status code
  const statusCode = err.statusCode || 500;
  
  // Send error response
  res.status(statusCode).json({
    success: false,
    error: statusCode === 500 ? 'Internal server error' : err.message,
    details: process.env.NODE_ENV === 'development' ? err.stack : undefined
  });
};

/**
 * Not found middleware
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
exports.notFound = (req, res) => {
  // Log the 404 error
  recordMetric({
    type: 'error',
    data: { 
      message: 'Not found',
      path: req.path,
      method: req.method
    },
    timestamp: new Date().toISOString(),
  });
  
  // Send 404 response
  res.status(404).json({
    success: false,
    error: 'Not found',
    details: `The requested resource at ${req.path} was not found`
  });
};