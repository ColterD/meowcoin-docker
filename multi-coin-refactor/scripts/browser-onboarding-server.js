#!/usr/bin/env node
// Minimal Express server for browser onboarding E2E automation

// Try to load from dist/ first (compiled version)
let express, path, bodyParser, simulateOnboarding, submitFeedbackBrowser;

try {
  express = require('express');
  path = require('path');
  bodyParser = require('body-parser');
  ({ simulateOnboarding } = require('../dist/wizards/browser/index'));
  ({ submitFeedbackBrowser } = require('../dist/wizards/browser/onboarding'));
  console.log('Loaded browser server modules from dist/');
} catch (e) {
  console.error('Failed to load from dist/, trying source version with ts-node:', e);
  try {
    // Fall back to source version with ts-node
    express = require('express');
    path = require('path');
    bodyParser = require('body-parser');
    require('ts-node/register');
    ({ simulateOnboarding } = require('../wizards/browser/index.ts'));
    ({ submitFeedbackBrowser } = require('../wizards/browser/onboarding.ts'));
    console.log('Loaded browser server modules from source with ts-node');
  } catch (e2) {
    console.error('Failed to start browser server:', e2);
    console.log('Please make sure you have run `npm install` and `npx tsc` first.');
    process.exit(1);
  }
}

const app = express();
const PORT = process.env.PORT || 12000; // Use the runtime port
const HOST = '0.0.0.0'; // Allow connections from any host

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Add CORS support
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With');
  next();
});

// Serve static files from public directory
app.use(express.static(path.join(process.cwd(), 'public')));

// Serve static HTML onboarding form
app.get('/onboarding', (req, res) => {
  res.sendFile(path.join(process.cwd(), 'public', 'index.html'));
});

// Handle onboarding POST
app.post('/onboarding', (req, res) => {
  try {
    const { coin, config } = req.body;
    const result = simulateOnboarding(coin, config);
    if (result.success) return res.json({ success: true });
    return res.json({ error: result.error || 'Invalid config', details: result.details });
  } catch (e) {
    return res.json({ error: e.message });
  }
});

// Handle feedback POST
app.post('/feedback', (req, res) => {
  try {
    const { feedback, user } = req.body;
    // submitFeedbackBrowser is already imported at the top
    submitFeedbackBrowser(feedback, user);
    return res.json({ success: true });
  } catch (e) {
    return res.json({ error: e.message });
  }
});

app.listen(PORT, HOST, () => {
  console.log(`Browser onboarding server running at http://${HOST}:${PORT}/onboarding`);
  console.log('Access via: https://work-1-rpekkbutozogdpsa.prod-runtime.all-hands.dev/onboarding');
}); 