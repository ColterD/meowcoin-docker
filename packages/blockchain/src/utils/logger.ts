import pino from 'pino';
import { getConfig } from '../config';

export function getLogger(config: ReturnType<typeof getConfig>) {
  return pino({
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
}