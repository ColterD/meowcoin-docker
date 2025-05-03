import { logger } from './utils/logger';
import { initializeNodeManager } from './services/nodeManager';

async function start() {
  try {
    // Initialize node manager
    await initializeNodeManager();
    // No server to start; buildServer is missing
    logger.info(`Blockchain service initialized (no server started)`);
    // No graceful shutdown needed
  } catch (err) {
    logger.error(err, 'Error starting blockchain service');
    process.exit(1);
  }
}

start();