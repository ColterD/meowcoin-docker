import dotenv from 'dotenv';
import { z } from 'zod';

// Load environment variables
dotenv.config();

// Define configuration schema with validation
const configSchema = z.object({
  // Server configuration
  port: z.coerce.number().default(8080),
  nodeEnv: z.enum(['development', 'test', 'production']).default('development'),
  logLevel: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),
  
  // Security
  jwtSecret: z.string().min(32),
  jwtExpiresIn: z.string().default('1h'),
  jwtRefreshExpiresIn: z.string().default('7d'),
  apiKey: z.string().min(32),
  
  // CORS
  corsOrigins: z.string().transform(val => val.split(',')),
  
  // Rate limiting
  rateLimit: z.object({
    windowMs: z.coerce.number().default(60000), // 1 minute
    max: z.coerce.number().default(100), // 100 requests per minute
  }).default({}),
  
  // Services
  services: z.object({
    auth: z.string().url(),
    blockchain: z.string().url(),
    analytics: z.string().url(),
    notification: z.string().url(),
  }),
  
  // Redis
  redis: z.object({
    host: z.string().default('localhost'),
    port: z.coerce.number().default(6379),
    password: z.string().optional(),
  }),
});

// Parse and validate configuration
export const config = configSchema.parse({
  port: process.env.PORT,
  nodeEnv: process.env.NODE_ENV,
  logLevel: process.env.LOG_LEVEL,
  
  jwtSecret: process.env.JWT_SECRET,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN,
  jwtRefreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN,
  apiKey: process.env.API_KEY,
  
  corsOrigins: process.env.CORS_ALLOWED_ORIGINS || 'http://localhost:3000',
  
  rateLimit: {
    windowMs: process.env.RATE_LIMIT_WINDOW_MS,
    max: process.env.RATE_LIMIT_MAX_REQUESTS,
  },
  
  services: {
    auth: process.env.AUTH_SERVICE_URL || 'http://auth-service:3001',
    blockchain: process.env.BLOCKCHAIN_SERVICE_URL || 'http://blockchain-service:3002',
    analytics: process.env.ANALYTICS_SERVICE_URL || 'http://analytics-service:3003',
    notification: process.env.NOTIFICATION_SERVICE_URL || 'http://notification-service:3004',
  },
  
  redis: {
    host: process.env.REDIS_HOST,
    port: process.env.REDIS_PORT,
    password: process.env.REDIS_PASSWORD,
  },
});