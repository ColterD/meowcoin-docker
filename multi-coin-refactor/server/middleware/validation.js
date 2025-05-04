/**
 * Validation Middleware
 * Validates request data before processing
 */
const { recordMetric } = require('../../dist/core/monitoring');

/**
 * Validate onboarding request
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
exports.validateOnboarding = (req, res, next) => {
  const { coin, config } = req.body;
  const errors = [];
  
  // Validate coin
  if (!coin || typeof coin !== 'string' || coin.trim() === '') {
    errors.push('Coin is required');
  }
  
  // Validate config
  if (!config || typeof config !== 'object') {
    errors.push('Config is required and must be an object');
  } else {
    // Validate rpcUrl
    if (!config.rpcUrl || typeof config.rpcUrl !== 'string' || config.rpcUrl.trim() === '') {
      errors.push('RPC URL is required');
    } else {
      try {
        new URL(config.rpcUrl);
      } catch (error) {
        errors.push('RPC URL must be a valid URL');
      }
    }
    
    // Validate network
    if (!config.network || typeof config.network !== 'string' || 
        !['mainnet', 'testnet', 'regtest'].includes(config.network)) {
      errors.push('Network must be one of: mainnet, testnet, regtest');
    }
    
    // Validate minConfirmations if provided
    if (config.minConfirmations !== undefined && 
        (typeof config.minConfirmations !== 'number' || config.minConfirmations < 0)) {
      errors.push('Minimum confirmations must be a non-negative number');
    }
    
    // Validate timeout if provided
    if (config.timeout !== undefined && 
        (typeof config.timeout !== 'number' || config.timeout < 1000)) {
      errors.push('Timeout must be at least 1000ms');
    }
  }
  
  // If there are validation errors, return 400 with error details
  if (errors.length > 0) {
    // Log validation errors
    recordMetric({
      type: 'validation',
      data: { 
        action: 'onboarding', 
        errors,
        body: req.body
      },
      timestamp: new Date().toISOString(),
    });
    
    return res.status(400).json({ 
      success: false,
      error: 'Validation failed',
      details: errors
    });
  }
  
  // If validation passes, continue to the next middleware/controller
  next();
};

/**
 * Validate feedback request
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
exports.validateFeedback = (req, res, next) => {
  const { feedback, user } = req.body;
  const errors = [];
  
  // Validate feedback
  if (!feedback || typeof feedback !== 'string' || feedback.trim() === '') {
    errors.push('Feedback is required');
  }
  
  // Validate user if provided
  if (user !== undefined && (typeof user !== 'object' || user === null)) {
    errors.push('User must be an object if provided');
  }
  
  // If there are validation errors, return 400 with error details
  if (errors.length > 0) {
    // Log validation errors
    recordMetric({
      type: 'validation',
      data: { 
        action: 'feedback', 
        errors,
        body: req.body
      },
      timestamp: new Date().toISOString(),
    });
    
    return res.status(400).json({ 
      success: false,
      error: 'Validation failed',
      details: errors
    });
  }
  
  // If validation passes, continue to the next middleware/controller
  next();
};