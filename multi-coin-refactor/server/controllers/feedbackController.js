/**
 * Feedback Controller
 * Handles feedback-related requests and business logic
 */
const { submitUserFeedback } = require('../../dist/core/feedback');
const { recordMetric } = require('../../dist/core/monitoring');

/**
 * Process feedback submission
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
exports.processFeedback = (req, res) => {
  try {
    const { feedback, user } = req.body;
    
    // Validate input
    if (!feedback || typeof feedback !== 'string' || feedback.trim() === '') {
      return res.status(400).json({ 
        success: false,
        error: 'Feedback is required' 
      });
    }
    
    // Log the feedback attempt
    recordMetric({
      type: 'feedback',
      data: { action: 'request', feedback, user },
      timestamp: new Date().toISOString(),
    });
    
    // Process the feedback
    submitUserFeedback({
      userId: user?.id,
      feedback,
      createdAt: new Date().toISOString(),
      context: 'browser',
    });
    
    // Log successful feedback submission
    recordMetric({
      type: 'feedback',
      data: { action: 'success', feedback, user },
      timestamp: new Date().toISOString(),
    });
    
    return res.status(200).json({ success: true });
  } catch (error) {
    // Log unexpected error
    recordMetric({
      type: 'error',
      data: { 
        action: 'feedback', 
        error: error.message, 
        stack: error.stack,
        body: req.body
      },
      timestamp: new Date().toISOString(),
    });
    
    return res.status(500).json({ 
      success: false,
      error: 'Server error processing feedback',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};