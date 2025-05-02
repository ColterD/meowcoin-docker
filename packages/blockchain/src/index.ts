import { config } from './config';
import { buildServer } from './server';
import { logger } from './utils/logger';
import { initializeNodeManager } from './services/nodeManager';

async function start() {
  try {
    // Initialize node manager
    await initializeNodeManager();
    
    // Build and start server
    const server = await buildServer();
    
    await server.listen({ 
      port: config.port, 
      host: '0.0.0.0' 
    });
    
    logger.info(`Blockchain service listening on ${config.port}`);
    
    // Handle graceful shutdown
    const shutdown = async () => {
      logger.info('Shutting down blockchain service...');
      await server.close();
      process.exit(0);
    };
    
    process.on('SIGTERM', shutdown);
    process.on('SIGINT', shutdown);
    
  } catch (err) {
    logger.error(err, 'Error starting blockchain service');
    process.exit(1);
  }
}

start();