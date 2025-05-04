/**
 * Rate Limiter Middleware
 * Limits the number of requests from a single IP address
 */
const { recordMetric } = require('../../dist/core/monitoring');

// In-memory store for rate limiting
// In production, this should be replaced with Redis or another distributed store
const ipRequestCounts = new Map();

/**
 * Rate limiter middleware factory
 * @param {Object} options - Rate limiter options
 * @param {number} options.windowMs - Time window in milliseconds
 * @param {number} options.max - Maximum number of requests in the time window
 * @returns {Function} Express middleware function
 */
exports.rateLimiter = ({ windowMs = 60 * 1000, max = 10 }) => {
  return (req, res, next) => {
    const ip = req.ip || req.connection.remoteAddress;
    const now = Date.now();
    
    // Initialize or clean up old requests for this IP
    if (!ipRequestCounts.has(ip)) {
      ipRequestCounts.set(ip, []);
    }
    
    const requests = ipRequestCounts.get(ip);
    
    // Remove requests outside the current time window
    const validRequests = requests.filter(timestamp => now - timestamp < windowMs);
    ipRequestCounts.set(ip, validRequests);
    
    // Check if the IP has exceeded the rate limit
    if (validRequests.length >= max) {
      // Log rate limit exceeded
      recordMetric({
        type: 'security',
        data: { 
          action: 'rate_limit_exceeded', 
          ip,
          path: req.path,
          method: req.method,
          count: validRequests.length,
          limit: max,
          window: windowMs
        },
        timestamp: new Date().toISOString(),
      });
      
      return res.status(429).json({ 
        success: false,
        error: 'Too many requests, please try again later',
        retryAfter: Math.ceil((windowMs - (now - validRequests[0])) / 1000)
      });
    }
    
    // Add the current request timestamp
    validRequests.push(now);
    ipRequestCounts.set(ip, validRequests);
    
    // Continue to the next middleware/controller
    next();
  };
};