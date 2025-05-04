/**
 * Security Middleware
 * Implements security best practices for the application
 */
const { recordMetric } = require('../../dist/core/monitoring');

/**
 * Set security headers middleware
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
exports.securityHeaders = (req, res, next) => {
  // Content Security Policy
  res.setHeader(
    'Content-Security-Policy',
    "default-src 'self'; script-src 'self' https://cdn.jsdelivr.net; style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; img-src 'self' data:; font-src 'self' https://cdn.jsdelivr.net; connect-src 'self'"
  );
  
  // X-Content-Type-Options
  res.setHeader('X-Content-Type-Options', 'nosniff');
  
  // X-Frame-Options
  res.setHeader('X-Frame-Options', 'SAMEORIGIN');
  
  // X-XSS-Protection
  res.setHeader('X-XSS-Protection', '1; mode=block');
  
  // Referrer-Policy
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  
  // Permissions-Policy
  res.setHeader(
    'Permissions-Policy',
    'camera=(), microphone=(), geolocation=(), interest-cohort=()'
  );
  
  // Continue to the next middleware/controller
  next();
};

/**
 * CSRF protection middleware
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
exports.csrfProtection = (req, res, next) => {
  // Skip for GET, HEAD, OPTIONS requests
  if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
    return next();
  }
  
  // Check for X-Requested-With header for AJAX requests
  const requestedWith = req.headers['x-requested-with'];
  if (requestedWith !== 'XMLHttpRequest') {
    // Log CSRF attempt
    recordMetric({
      type: 'security',
      data: { 
        action: 'csrf_attempt', 
        path: req.path,
        method: req.method,
        headers: req.headers,
        ip: req.ip || req.connection.remoteAddress
      },
      timestamp: new Date().toISOString(),
    });
    
    return res.status(403).json({ 
      success: false,
      error: 'CSRF protection: Invalid request'
    });
  }
  
  // Continue to the next middleware/controller
  next();
};