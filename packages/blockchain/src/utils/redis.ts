import Redis from 'ioredis';
import { getConfig } from '../config';

export function setupRedis(config: ReturnType<typeof getConfig>, logger: any) {
  const redis = new Redis({
    host: config.redis.host,
    port: config.redis.port,
    password: config.redis.password,
    maxRetriesPerRequest: 3,
  });

  redis.on('connect', () => {
    logger.info('Connected to Redis');
  });

  redis.on('error', (error) => {
    logger.error(error, 'Redis error');
  });

  redis.on('reconnecting', () => {
    logger.warn('Reconnecting to Redis');
  });

  process.on('beforeExit', async () => {
    await redis.quit();
    logger.info('Disconnected from Redis');
  });

  return redis;
}