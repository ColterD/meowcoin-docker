#!/usr/bin/env node

/**
 * Meowcoin health check script
 * Performs comprehensive health checks on the Meowcoin node
 */

const core = require('../core');

// Initialize core modules
async function init() {
  await core.logging.initialize();
  await core.config.initialize();
  await core.monitor.initialize();
}

// Run health check
async function runHealthCheck() {
  console.log('Running Meowcoin node health check...');
  
  try {
    const results = await core.monitor.runHealthCheck();
    
    console.log(`Status: ${results.status.toUpperCase()}`);
    console.log(`Timestamp: ${results.timestamp}`);
    
    if (results.issues.length > 0) {
      console.log('\nIssues detected:');
      results.issues.forEach(issue => {
        console.log(`- ${issue.message}`);
      });
    } else {
      console.log('\nNo issues detected.');
    }
    
    // Exit with appropriate code
    if (results.status === 'healthy') {
      process.exit(0);
    } else {
      process.exit(1);
    }
  } catch (error) {
    console.error(`Health check failed: ${error.message}`);
    process.exit(2);
  }
}

// Run script
init()
  .then(runHealthCheck)
  .catch(error => {
    console.error(`Unhandled error: ${error.message}`);
    process.exit(2);
  });