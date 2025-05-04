#!/usr/bin/env node

/**
 * Server Entry Point
 * Starts the application server
 */

// Load environment variables
require('dotenv').config();

// Import the app
const app = require('./app');

// Set environment variables
const PORT = process.env.PORT || 12000;
const HOST = process.env.HOST || '0.0.0.0';

// Start the server
app.listen(PORT, HOST, () => {
  console.log(`Server running at http://${HOST}:${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Access via: https://work-1-rpekkbutozogdpsa.prod-runtime.all-hands.dev`);
});