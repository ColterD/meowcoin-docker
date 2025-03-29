const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

/**
 * Integration test for Meowcoin Docker node lifecycle
 * Tests container startup, operation, and shutdown
 */

// Configuration
const CONTAINER_NAME = 'meowcoin-test';
const COMPOSE_FILE = 'docker-compose.yml';
const TEST_LOG = `integration_test_${new Date().toISOString().replace(/:/g, '-')}.log`;
const TIMEOUT = 300; // Max time to wait for node initialization in seconds

// Utility functions
function log(message) {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] ${message}`;
  console.log(logMessage);
  fs.appendFileSync(TEST_LOG, logMessage + '\n');
}

function fail(message) {
  log(`ERROR: ${message}`);
  process.exit(1);
}

async function waitForCondition(condition, message, timeout, interval = 5) {
  log(`Waiting for: ${message} (max ${timeout} seconds)`);
  
  let elapsed = 0;
  
  while (true) {
    try {
      if (await condition()) {
        log(`Condition met after ${elapsed} seconds: ${message}`);
        return true;
      }
    } catch (error) {
      // Ignore errors, just retry
    }
    
    elapsed += interval;
    if (elapsed >= timeout) {
      fail(`Timeout waiting for: ${message}`);
    }
    
    log(`Still waiting... (${elapsed} seconds elapsed)`);
    await new Promise(resolve => setTimeout(resolve, interval * 1000));
  }
}

// Main test function
async function runTest() {
  log('Starting integration test for Meowcoin Docker node');
  
  // Check for docker and docker-compose
  try {
    execSync('docker --version', { stdio: 'pipe' });
  } catch (error) {
    fail('Docker is not installed');
  }
  
  try {
    execSync('docker-compose --version', { stdio: 'pipe' });
  } catch (error) {
    try {
      execSync('docker compose version', { stdio: 'pipe' });
    } catch (error) {
      fail('Docker Compose is not installed');
    }
  }
  
  // Use appropriate docker-compose command
  const COMPOSE_CMD = execSync('docker-compose --version', { stdio: 'pipe', encoding: 'utf8' }).includes('docker-compose') 
    ? 'docker-compose' 
    : 'docker compose';
  
  // Check for compose file
  if (!fs.existsSync(COMPOSE_FILE)) {
    fail(`Docker Compose file not found: ${COMPOSE_FILE}`);
  }
  
  // Clean up any previous test containers
  log('Cleaning up any previous test containers');
  try {
    execSync(`${COMPOSE_CMD} -f ${COMPOSE_FILE} down`, { stdio: 'pipe' });
  } catch (error) {
    // Ignore errors
  }
  
  try {
    execSync(`docker rm -f ${CONTAINER_NAME}`, { stdio: 'pipe' });
  } catch (error) {
    // Ignore errors
  }
  
  // Start container
  log(`Starting container using ${COMPOSE_FILE}`);
  try {
    execSync(`${COMPOSE_CMD} -f ${COMPOSE_FILE} up -d`, { stdio: 'pipe' });
  } catch (error) {
    fail(`Failed to start container: ${error.message}`);
  }
  
  // Wait for container to start
  await waitForCondition(
    () => execSync('docker ps', { encoding: 'utf8' }).includes(CONTAINER_NAME),
    'Container to be running',
    60
  );
  
  // Get container info
  log('Container is running, getting container info');
  const containerId = execSync(`docker ps | grep ${CONTAINER_NAME} | awk '{print $1}'`, { encoding: 'utf8' }).trim();
  log(`Container ID: ${containerId}`);
  
  // Wait for node initialization
  log('Waiting for node initialization');
  await waitForCondition(
    () => execSync(`docker logs ${CONTAINER_NAME} 2>&1`, { encoding: 'utf8' }).includes('Meowcoin Core starting'),
    'Node initialization',
    TIMEOUT,
    10
  );
  
  // Test RPC connectivity
  log('Testing RPC connectivity');
  await waitForCondition(
    () => {
      try {
        execSync(`docker exec ${CONTAINER_NAME} meowcoin-cli-wrapper.js getblockchaininfo`, { stdio: 'pipe' });
        return true;
      } catch (error) {
        return false;
      }
    },
    'RPC connection',
    60
  );
  
  // Get blockchain info
  log('Getting blockchain info');
  try {
    const blockchainInfo = execSync(`docker exec ${CONTAINER_NAME} meowcoin-cli-wrapper.js getblockchaininfo`, { encoding: 'utf8' });
    fs.writeFileSync('blockchain_info.json', blockchainInfo);
    log('Blockchain info retrieved successfully');
  } catch (error) {
    fail('Failed to get blockchain info');
  }
  
  // Test network info
  log('Testing network info');
  try {
    const networkInfo = execSync(`docker exec ${CONTAINER_NAME} meowcoin-cli-wrapper.js getnetworkinfo`, { encoding: 'utf8' });
    fs.writeFileSync('network_info.json', networkInfo);
    log('Network info retrieved successfully');
  } catch (error) {
    fail('Failed to get network info');
  }
  
  // Test metrics endpoint if enabled
  if (fs.readFileSync(COMPOSE_FILE, 'utf8').includes('ENABLE_METRICS=true')) {
    log('Testing monitoring endpoint');
    await waitForCondition(
      () => {
        try {
          return execSync(`docker exec ${CONTAINER_NAME} curl -s http://localhost:9449/metrics`, { encoding: 'utf8' }).includes('meowcoin');
        } catch (error) {
          return false;
        }
      },
      'Metrics endpoint',
      60
    );
    log('Metrics endpoint is working');
  }
  
  // Test backup functionality
  log('Testing backup functionality');
  try {
    execSync(`docker exec ${CONTAINER_NAME} meowcoin-backup.js create test`, { stdio: 'pipe' });
    await waitForCondition(
      () => {
        try {
          return execSync(`docker exec ${CONTAINER_NAME} ls -la /home/meowcoin/.meowcoin/backups/`, { encoding: 'utf8' }).includes('tar.gz');
        } catch (error) {
          return false;
        }
      },
      'Backup file creation',
      60
    );
    log('Backup completed successfully');
  } catch (error) {
    fail(`Backup failed: ${error.message}`);
  }
  
  // Test health check
  log('Testing health check');
  try {
    execSync(`docker exec ${CONTAINER_NAME} meowcoin-health.js`, { stdio: 'pipe' });
    await waitForCondition(
      () => {
        try {
          return fs.existsSync('/tmp/meowcoin_health_status.json');
        } catch (error) {
          return false;
        }
      },
      'Health status file',
      30
    );
    log('Health check executed');
  } catch (error) {
    log(`Health check reported issues: ${error.message}`);
  }
  
  // Test graceful shutdown
  log('Testing graceful shutdown');
  try {
    execSync(`${COMPOSE_CMD} -f ${COMPOSE_FILE} stop`, { stdio: 'pipe' });
    await waitForCondition(
      () => !execSync('docker ps', { encoding: 'utf8' }).includes(CONTAINER_NAME),
      'Container to stop',
      60
    );
    log('Container stopped gracefully');
  } catch (error) {
    fail(`Failed to stop container: ${error.message}`);
  }
  
  // Start container again to test restart
  log('Testing container restart');
  try {
    execSync(`${COMPOSE_CMD} -f ${COMPOSE_FILE} start`, { stdio: 'pipe' });
    await waitForCondition(
      () => execSync('docker ps', { encoding: 'utf8' }).includes(CONTAINER_NAME),
      'Container to restart',
      60
    );
    log('Container restarted successfully');
  } catch (error) {
    fail(`Failed to restart container: ${error.message}`);
  }
  
  // Test service removal
  log('Testing service removal');
  try {
    execSync(`${COMPOSE_CMD} -f ${COMPOSE_FILE} down`, { stdio: 'pipe' });
    await waitForCondition(
      () => !execSync('docker ps -a', { encoding: 'utf8' }).includes(CONTAINER_NAME),
      'Service to be removed',
      60
    );
    log('Service removed successfully');
  } catch (error) {
    fail(`Failed to remove service: ${error.message}`);
  }
  
  // Clean up remaining files
  log('Cleaning up test files');
  try {
    fs.unlinkSync('blockchain_info.json');
    fs.unlinkSync('network_info.json');
  } catch (error) {
    // Ignore errors
  }
  
  log('Integration test completed successfully');
  return 0;
}

// Run the test
runTest()
  .then(code => process.exit(code))
  .catch(error => {
    console.error(`Test failed with error: ${error.message}`);
    process.exit(1);
  });