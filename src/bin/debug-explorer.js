#!/usr/bin/env node

/**
 * Meowcoin Block Explorer Debug Script
 * Tests connectivity to the Meowcoin daemon and reports configuration issues
 */

const fs = require('fs');
const { execSync } = require('child_process');
const http = require('http');

console.log('Starting Block Explorer Debug Script');

// Get configuration from meowcoin.conf
function getMeowcoinConfig() {
  try {
    const configPath = '/home/meowcoin/.meowcoin/meowcoin.conf';
    if (!fs.existsSync(configPath)) {
      return { error: 'meowcoin.conf not found' };
    }

    const configContent = fs.readFileSync(configPath, 'utf8');
    const config = {};
    
    configContent.split('\n').forEach(line => {
      if (line.trim() && !line.startsWith('#')) {
        const [key, value] = line.split('=').map(part => part.trim());
        if (key && value) {
          config[key] = value;
        }
      }
    });

    return config;
  } catch (error) {
    return { error: `Failed to read meowcoin.conf: ${error.message}` };
  }
}

// Test RPC connection
function testRpcConnection(config) {
  try {
    const rpcPort = config.rpcport || 9766;
    const rpcUser = config.rpcuser || 'meowcoin';
    const rpcPassword = config.rpcpassword || '';
    const rpcHost = config.rpcbind || '127.0.0.1';

    console.log(`Testing RPC connection to ${rpcHost}:${rpcPort}`);
    console.log(`Using credentials: user=${rpcUser}, password=${rpcPassword ? '[SET]' : '[NOT SET]'}`);

    // Create a basic auth header
    const auth = Buffer.from(`${rpcUser}:${rpcPassword}`).toString('base64');
    
    // Create a simple RPC request
    const postData = JSON.stringify({
      jsonrpc: '1.0',
      id: 'debug',
      method: 'getnetworkinfo',
      params: []
    });

    const options = {
      hostname: rpcHost,
      port: rpcPort,
      path: '/',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
        'Authorization': `Basic ${auth}`
      }
    };

    // Make the request
    const req = http.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        if (res.statusCode === 200) {
          console.log('RPC connection successful');
          console.log(`Response: ${data}`);
        } else {
          console.log(`RPC connection failed with status code: ${res.statusCode}`);
          console.log(`Response: ${data}`);
        }
      });
    });

    req.on('error', (error) => {
      console.log(`RPC connection error: ${error.message}`);
    });

    req.write(postData);
    req.end();

    return true;
  } catch (error) {
    console.log(`RPC test failed: ${error.message}`);
    return false;
  }
}

// Check if meowcoind is running
function checkMeowcoindRunning() {
  try {
    execSync('pgrep -x meowcoind', { stdio: 'pipe' });
    console.log('Meowcoind is running');
    return true;
  } catch (error) {
    console.log('Meowcoind is NOT running');
    return false;
  }
}

// Get Block Explorer configuration
function getExplorerConfig() {
  try {
    const explorerConfig = {};
    
    // Check environment variables
    const envVars = [
      'BTCEXP_HOST',
      'BTCEXP_PORT',
      'BTCEXP_BITCOIND_HOST',
      'BTCEXP_BITCOIND_PORT',
      'BTCEXP_BITCOIND_USER',
      'BTCEXP_BITCOIND_PASS',
      'BTCEXP_ADDRESS_API'
    ];

    envVars.forEach(varName => {
      explorerConfig[varName] = process.env[varName];
    });

    // Check supervisord config
    const supervisordConfig = '/etc/supervisor/conf.d/supervisord.conf';
    if (fs.existsSync(supervisordConfig)) {
      const configContent = fs.readFileSync(supervisordConfig, 'utf8');
      const envLine = configContent.split('\n').find(line => line.trim().startsWith('environment='));
      
      if (envLine) {
        const envParts = envLine.trim().substring('environment='.length).split(',');
        envParts.forEach(part => {
          const [key, value] = part.split('=');
          if (key && value) {
            explorerConfig[key] = value.replace(/"/g, '');
          }
        });
      }
    }

    return explorerConfig;
  } catch (error) {
    return { error: `Failed to get explorer config: ${error.message}` };
  }
}

// Run the debug script
function run() {
  console.log('======== Meowcoin Block Explorer Debug ========');
  
  // Check if meowcoind is running
  const meowcoindRunning = checkMeowcoindRunning();
  
  // Get meowcoin.conf
  const meowcoinConfig = getMeowcoinConfig();
  console.log('\nMeowcoin Configuration:');
  console.log(JSON.stringify(meowcoinConfig, null, 2));
  
  // Get explorer config
  const explorerConfig = getExplorerConfig();
  console.log('\nBlock Explorer Configuration:');
  console.log(JSON.stringify(explorerConfig, null, 2));
  
  // Test RPC connection if meowcoind is running
  if (meowcoindRunning) {
    console.log('\nTesting RPC Connection:');
    testRpcConnection(meowcoinConfig);
  }
  
  console.log('\nChecking Ports:');
  const ports = [9766, 9767, 9449, 3001];
  ports.forEach(port => {
    try {
      const result = execSync(`netstat -tuln | grep ":${port} "`, { stdio: 'pipe' });
      console.log(`Port ${port}: LISTENING`);
    } catch (error) {
      console.log(`Port ${port}: NOT LISTENING`);
    }
  });
  
  console.log('\n==============================================');
}

// Run the script
run();