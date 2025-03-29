#!/usr/bin/env node

/**
 * Meowcoin CLI wrapper script
 * Provides additional features and standardized error handling for the Meowcoin CLI
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Get meowcoin.conf location
const HOME_DIR = process.env.HOME || '/home/meowcoin';
const CONFIG_FILE = path.join(HOME_DIR, '.meowcoin', 'meowcoin.conf');

// Forward arguments to meowcoin-cli
const args = process.argv.slice(2);

// Check if help requested
if (args.includes('-help') || args.includes('--help') || args.includes('help')) {
  const help = execSync('meowcoin-cli -help', { encoding: 'utf8' });
  console.log('Meowcoin CLI Wrapper');
  console.log('-------------------');
  console.log('');
  console.log(help);
  process.exit(0);
}

// Parse config file to get RPC credentials if not provided
if (!args.includes('-rpcuser') && !args.includes('-rpcpassword')) {
  try {
    if (fs.existsSync(CONFIG_FILE)) {
      const config = fs.readFileSync(CONFIG_FILE, 'utf8');
      const rpcUser = config.match(/rpcuser=(.+)/)?.[1];
      const rpcPassword = config.match(/rpcpassword=(.+)/)?.[1];
      
      if (rpcUser && rpcPassword) {
        args.push('-rpcuser=' + rpcUser);
        args.push('-rpcpassword=' + rpcPassword);
      }
    }
  } catch (error) {
    console.error(`Warning: Error reading configuration: ${error.message}`);
  }
}

// Execute command
try {
  const output = execSync('meowcoin-cli ' + args.join(' '), { encoding: 'utf8' });
  process.stdout.write(output);
} catch (error) {
  console.error(`Error: ${error.message}`);
  process.exit(1);
}