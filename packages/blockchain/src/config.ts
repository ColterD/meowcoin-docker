import dotenv from 'dotenv';
import { z } from 'zod';

// Load environment variables
dotenv.config();

// Define configuration schema with validation
export const configSchema = z.object({
  // Server configuration
  port: z.coerce.number().default(3002),
  nodeEnv: z.enum(['development', 'test', 'production']).default('development'),
  logLevel: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),
  
  // Security
  jwtSecret: z.string().min(32),
  
  // Database
  database: z.object({
    url: z.string().url(),
  }),
  
  // Redis
  redis: z.object({
    host: z.string().default('localhost'),
    port: z.coerce.number().default(6379),
    password: z.string().optional(),
  }),
  
  // MeowCoin node
  meowcoin: z.object({
    rpcHost: z.string().default('localhost'),
    rpcPort: z.coerce.number().default(9332),
    rpcUser: z.string(),
    rpcPassword: z.string(),
    dataDir: z.string().default('/data/meowcoin'),
  }),
  
  // Backup
  backup: z.object({
    enabled: z.boolean().default(true),
    interval: z.coerce.number().default(86400), // 24 hours in seconds
    maxBackups: z.coerce.number().default(7),
    storageDir: z.string().default('/data/backups'),
  }),
});

export function getConfig() {
  return configSchema.parse({
    port: process.env.PORT,
    nodeEnv: process.env.NODE_ENV,
    logLevel: process.env.LOG_LEVEL,
    
    jwtSecret: process.env.JWT_SECRET,
    
    database: {
      url: process.env.DATABASE_URL,
    },
    
    redis: {
      host: process.env.REDIS_HOST,
      port: process.env.REDIS_PORT,
      password: process.env.REDIS_PASSWORD,
    },
    
    meowcoin: {
      rpcHost: process.env.MEOWCOIN_RPC_HOST,
      rpcPort: process.env.MEOWCOIN_RPC_PORT,
      rpcUser: process.env.MEOWCOIN_RPC_USER,
      rpcPassword: process.env.MEOWCOIN_RPC_PASSWORD,
      dataDir: process.env.MEOWCOIN_DATA_DIR,
    },
    
    backup: {
      enabled: process.env.BACKUP_ENABLED === 'true',
      interval: process.env.BACKUP_INTERVAL,
      maxBackups: process.env.MAX_BACKUPS,
      storageDir: process.env.BACKUP_STORAGE_DIR,
    },
  });
}