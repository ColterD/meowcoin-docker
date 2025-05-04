/**
 * API Routes
 * Defines all API endpoints for the application
 */
const express = require('express');
const router = express.Router();
const onboardingController = require('../controllers/onboardingController');
const feedbackController = require('../controllers/feedbackController');
const { validateOnboarding, validateFeedback } = require('../middleware/validation');
const { rateLimiter } = require('../middleware/rateLimiter');

// API version prefix
const API_VERSION = '/v1';

// Onboarding routes
router.post(
  `${API_VERSION}/onboarding`, 
  rateLimiter({ windowMs: 60 * 1000, max: 10 }), // 10 requests per minute
  validateOnboarding,
  onboardingController.processOnboarding
);

// Feedback routes
router.post(
  `${API_VERSION}/feedback`, 
  rateLimiter({ windowMs: 60 * 1000, max: 5 }), // 5 requests per minute
  validateFeedback,
  feedbackController.processFeedback
);

// Health check route
router.get(`${API_VERSION}/health`, (req, res) => {
  res.status(200).json({ 
    status: 'ok',
    version: process.env.npm_package_version || '0.1.0',
    timestamp: new Date().toISOString()
  });
});

module.exports = router;