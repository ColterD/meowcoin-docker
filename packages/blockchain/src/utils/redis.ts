import Redis from 'ioredis';
import { config } from '../config';
import { logger } from './logger';

// Create Redis client
export const redis = new Redis({
  host: config.redis.host,
  port: config.redis.port,
  password: config.redis.password,
  maxRetriesPerRequest: 3,
});

// Handle Redis events
redis.on('connect', () => {
  logger.info('Connected to Redis');
});

redis.on('error', (error) => {
  logger.error(error, 'Redis error');
});

redis.on('reconnecting', () => {
  logger.warn('Reconnecting to Redis');
});

// Handle process exit
process.on('beforeExit', async () => {
  await redis.quit();
  logger.info('Disconnected from Redis');
});