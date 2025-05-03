import { PrismaClient } from '@prisma/client';

export function setupPrisma(logger: any) {
  const prisma = new PrismaClient({
    log: [
      { emit: 'event', level: 'query' },
      { emit: 'event', level: 'error' },
      { emit: 'event', level: 'info' },
      { emit: 'event', level: 'warn' },
    ],
  });

  if (process.env.NODE_ENV === 'development') {
    prisma.$on('query', (e: any) => {
      logger.debug?.(`Query: ${e.query}`);
      logger.debug?.(`Duration: ${e.duration}ms`);
    });
  }

  prisma.$on('error', (e: any) => {
    logger.error(e, 'Prisma error');
  });

  prisma.$connect()
    .then(() => {
      logger.info('Connected to database');
    })
    .catch((error: any) => {
      logger.error(error, 'Failed to connect to database');
      process.exit(1);
    });

  process.on('beforeExit', async () => {
    await prisma.$disconnect();
    logger.info('Disconnected from database');
  });

  return prisma;
}