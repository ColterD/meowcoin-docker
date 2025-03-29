#!/usr/bin/env node

/**
 * Main entrypoint script for Meowcoin Docker container
 * Handles initialization and startup of all services
 */

const { execSync, spawn } = require('child_process');
const core = require('./core');
const fs = require('fs');
const path = require('path');

// Initialize all core modules
async function initialize() {
  console.log('Initializing Meowcoin Docker container...');
  
  try {
    // Load version information
    const version = fs.readFileSync('/meowcoin_version.txt', 'utf8').trim();
    console.log(`Meowcoin version: ${version}`);
    
    // Initialize core modules
    await core.initialize();
    
    // Generate Meowcoin configuration
    await core.config.generateMeowcoinConfig();
    
    // Start supervisord to manage services
    console.log('Starting supervisord...');
    
    // Run supervisord in foreground
    const supervisor = spawn('supervisord', ['-n', '-c', '/etc/supervisor/conf.d/supervisord.conf'], {
      stdio: 'inherit'
    });
    
    // Handle supervisor exit
    supervisor.on('close', (code) => {
      console.log(`supervisord exited with code ${code}`);
      process.exit(code);
    });
    
    // Handle shutdown signal
    process.on('SIGTERM', () => {
      console.log('Received SIGTERM, shutting down...');
      
      // Execute shutdown hooks if plugins enabled
      if (core.config.get('enablePlugins')) {
        core.plugins.executeHooks('shutdown');
      }
      
      // Send SIGTERM to supervisord
      supervisor.kill('SIGTERM');
    });
    
    process.on('SIGINT', () => {
      console.log('Received SIGINT, shutting down...');
      
      // Execute shutdown hooks if plugins enabled
      if (core.config.get('enablePlugins')) {
        core.plugins.executeHooks('shutdown');
      }
      
      // Send SIGINT to supervisord
      supervisor.kill('SIGINT');
    });
  } catch (error) {
    console.error(`Initialization failed: ${error.message}`);
    process.exit(1);
  }
}

// Run entrypoint
initialize().catch(error => {
  console.error(`Unhandled error: ${error.message}`);
  process.exit(1);
});