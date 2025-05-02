import pino from 'pino';
import { config } from '../config';

// Create logger instance
export const logger = pino({
  level: config.logLevel,
  transport: config.nodeEnv !== 'production' 
    ? {
        target: 'pino-pretty',
        options: {
          colorize: true,
          translateTime: 'SYS:standard',
          ignore: 'pid,hostname',
        },
      }
    : undefined,
  base: {
    service: 'blockchain-service',
  },
});