"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.config = void 0;
const dotenv = __importStar(require("dotenv"));
const zod_1 = require("zod");
// Load environment variables
dotenv.config();
// Define configuration schema with validation
const configSchema = zod_1.z.object({
    // Server configuration
    port: zod_1.z.coerce.number().default(8080),
    nodeEnv: zod_1.z.enum(['development', 'test', 'production']).default('development'),
    logLevel: zod_1.z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),
    // Security
    jwtSecret: zod_1.z.string().min(32),
    jwtExpiresIn: zod_1.z.string().default('1h'),
    jwtRefreshExpiresIn: zod_1.z.string().default('7d'),
    apiKey: zod_1.z.string().min(32),
    // CORS
    corsOrigins: zod_1.z.string().transform(val => val.split(',')),
    // Rate limiting
    rateLimit: zod_1.z.object({
        windowMs: zod_1.z.coerce.number().default(60000), // 1 minute
        max: zod_1.z.coerce.number().default(100), // 100 requests per minute
    }).default({}),
    // Services
    services: zod_1.z.object({
        auth: zod_1.z.string().url(),
        blockchain: zod_1.z.string().url(),
        analytics: zod_1.z.string().url(),
        notification: zod_1.z.string().url(),
    }),
    // Redis
    redis: zod_1.z.object({
        host: zod_1.z.string().default('localhost'),
        port: zod_1.z.coerce.number().default(6379),
        password: zod_1.z.string().optional(),
    }),
});
// Parse and validate configuration
exports.config = configSchema.parse({
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
