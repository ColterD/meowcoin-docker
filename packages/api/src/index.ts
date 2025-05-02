import { config } from './config';
import { buildServer } from './server';
import { logger } from './utils/logger';

async function start() {
  try {
    const server = await buildServer();
    
    await server.listen({ 
      port: config.port, 
      host: '0.0.0.0' 
    });
    
    logger.info(`Server listening on ${config.port}`);
    
    // Handle graceful shutdown
    const shutdown = async () => {
      logger.info('Shutting down server...');
      await server.close();
      process.exit(0);
    };
    
    process.on('SIGTERM', shutdown);
    process.on('SIGINT', shutdown);
    
  } catch (err) {
    logger.error(err, 'Error starting server');
    process.exit(1);
  }
}

start();