import pino from 'pino';

/**
 * Returns a pino logger instance configured for the given service.
 * @param config An object with logLevel and nodeEnv properties (string).
 */
export function getLogger(config: { logLevel: string; nodeEnv: string; serviceName?: string }) {
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
      service: config.serviceName || 'shared-service',
    },
  });
} 