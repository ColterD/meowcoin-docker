/**
 * Onboarding Controller
 * Handles onboarding-related requests and business logic
 */
const { simulateOnboarding } = require('../../dist/wizards/browser/index');
const { recordMetric } = require('../../dist/core/monitoring');

/**
 * Process onboarding request
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
exports.processOnboarding = (req, res) => {
  try {
    const { coin, config } = req.body;
    
    // Log the onboarding attempt
    recordMetric({
      type: 'onboarding',
      data: { action: 'request', coin, config },
      timestamp: new Date().toISOString(),
    });
    
    // Validate and process the onboarding request
    const result = simulateOnboarding(coin, config);
    
    if (result.success) {
      // Log successful onboarding
      recordMetric({
        type: 'onboarding',
        data: { action: 'success', coin, config },
        timestamp: new Date().toISOString(),
      });
      
      return res.status(200).json({ success: true });
    }
    
    // Log failed onboarding
    recordMetric({
      type: 'onboarding',
      data: { action: 'error', error: result.error, details: result.details, coin, config },
      timestamp: new Date().toISOString(),
    });
    
    return res.status(400).json({ 
      success: false,
      error: result.error || 'Invalid configuration', 
      details: result.details 
    });
  } catch (error) {
    // Log unexpected error
    recordMetric({
      type: 'error',
      data: { 
        action: 'onboarding', 
        error: error.message, 
        stack: error.stack,
        body: req.body
      },
      timestamp: new Date().toISOString(),
    });
    
    return res.status(500).json({ 
      success: false,
      error: 'Server error processing onboarding request',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};