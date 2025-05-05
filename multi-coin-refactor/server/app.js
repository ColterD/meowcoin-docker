/**
 * Main Application Server
 * Sets up Express server with middleware and routes
 */
const express = require('express');
const path = require('path');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const cors = require('cors');
const swaggerUi = require('swagger-ui-express');
const YAML = require('yamljs');
const fs = require('fs');
const apiRoutes = require('./routes/api');
const { errorHandler, notFound } = require('./middleware/errorHandler');
const { securityHeaders, csrfProtection } = require('./middleware/security');
const { recordMetric } = require('../dist/core/monitoring');

// Create Express app
const app = express();

// Set environment variables
const PORT = process.env.PORT || 12000;
const HOST = process.env.HOST || '0.0.0.0';
const NODE_ENV = process.env.NODE_ENV || 'development';

// Basic security with helmet
app.use(helmet({
  contentSecurityPolicy: false // We'll set our own CSP
}));

// Custom security headers
app.use(securityHeaders);

// Enable CORS
app.use(cors({
  origin: '*', // In production, this should be restricted
  methods: ['GET', 'POST'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'X-API-Key']
}));

// Request parsing
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Compression
app.use(compression());

// Logging
app.use(morgan(NODE_ENV === 'production' ? 'combined' : 'dev'));

// Custom request logging
app.use((req, res, next) => {
  // Skip logging for static files and API docs
  if (!req.path.startsWith('/static') && 
      !req.path.includes('.') && 
      !req.path.startsWith('/api-docs')) {
    recordMetric({
      type: 'request',
      data: { 
        path: req.path,
        method: req.method,
        ip: req.ip || req.connection.remoteAddress,
        userAgent: req.headers['user-agent']
      },
      timestamp: new Date().toISOString(),
    });
  }
  next();
});

// CSRF protection for non-GET requests (except API docs)
app.use((req, res, next) => {
  if (req.path.startsWith('/api-docs')) {
    return next();
  }
  csrfProtection(req, res, next);
});

// Static files
app.use(express.static(path.join(__dirname, '..', 'public')));

// API Documentation
const swaggerDocument = YAML.load(path.join(__dirname, 'openapi.yaml'));
// Add server URL dynamically
swaggerDocument.servers.unshift({
  url: `http://${HOST}:${PORT}/api/v1`,
  description: 'Local development server'
});

app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument, {
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: 'Multi-Coin Blockchain Platform API',
  customfavIcon: '/favicon.ico',
  swaggerOptions: {
    persistAuthorization: true,
    displayRequestDuration: true,
    filter: true,
    deepLinking: true,
  }
}));

// API routes
app.use('/api', apiRoutes);

// Serve the main HTML file for all other routes (SPA support)
app.get('/onboarding', (req, res) => {
  res.sendFile(path.join(__dirname, '..', 'public', 'index.html'));
});

app.get('/', (req, res) => {
  res.redirect('/onboarding');
});

// Redirect to API docs
app.get('/docs', (req, res) => {
  res.redirect('/api-docs');
});

// Health check endpoint
app.get('/health', (req, res) => {
  const uptime = process.uptime();
  const { version } = require('../package.json');
  
  res.status(200).json({
    success: true,
    status: 'ok',
    version,
    uptime,
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use(notFound);

// Error handler
app.use(errorHandler);

// Export the app for testing
module.exports = app;

// Start the server if this file is run directly
if (require.main === module) {
  app.listen(PORT, HOST, () => {
    console.log(`Server running at http://${HOST}:${PORT}`);
    console.log(`API Documentation: http://${HOST}:${PORT}/api-docs`);
    console.log(`Environment: ${NODE_ENV}`);
    console.log(`Access via: https://work-1-rpekkbutozogdpsa.prod-runtime.all-hands.dev`);
  });
}