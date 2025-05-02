import { PrismaClient } from '@prisma/client';
import { logger } from './logger';

// Create Prisma client instance
export const prisma = new PrismaClient({
  log: [
    {
      emit: 'event',
      level: 'query',
    },
    {
      emit: 'event',
      level: 'error',
    },
    {
      emit: 'event',
      level: 'info',
    },
    {
      emit: 'event',
      level: 'warn',
    },
  ],
});

// Log Prisma queries in development
if (process.env.NODE_ENV === 'development') {
  prisma.$on('query', (e) => {
    logger.debug(`Query: ${e.query}`);
    logger.debug(`Duration: ${e.duration}ms`);
  });
}

// Log Prisma errors
prisma.$on('error', (e) => {
  logger.error(e, 'Prisma error');
});

// Handle Prisma connection
prisma.$connect()
  .then(() => {
    logger.info('Connected to database');
  })
  .catch((error) => {
    logger.error(error, 'Failed to connect to database');
    process.exit(1);
  });

// Handle process exit
process.on('beforeExit', async () => {
  await prisma.$disconnect();
  logger.info('Disconnected from database');
});