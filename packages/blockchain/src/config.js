"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.config = void 0;
const dotenv_1 = __importDefault(require("dotenv"));
const zod_1 = require("zod");
// Load environment variables
dotenv_1.default.config();
// Define configuration schema with validation
const configSchema = zod_1.z.object({
    // Server configuration
    port: zod_1.z.coerce.number().default(3002),
    nodeEnv: zod_1.z.enum(['development', 'test', 'production']).default('development'),
    logLevel: zod_1.z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),
    // Security
    jwtSecret: zod_1.z.string().min(32),
    // Database
    database: zod_1.z.object({
        url: zod_1.z.string().url(),
    }),
    // Redis
    redis: zod_1.z.object({
        host: zod_1.z.string().default('localhost'),
        port: zod_1.z.coerce.number().default(6379),
        password: zod_1.z.string().optional(),
    }),
    // MeowCoin node
    meowcoin: zod_1.z.object({
        rpcHost: zod_1.z.string().default('localhost'),
        rpcPort: zod_1.z.coerce.number().default(9332),
        rpcUser: zod_1.z.string(),
        rpcPassword: zod_1.z.string(),
        dataDir: zod_1.z.string().default('/data/meowcoin'),
    }),
    // Backup
    backup: zod_1.z.object({
        enabled: zod_1.z.boolean().default(true),
        interval: zod_1.z.coerce.number().default(86400), // 24 hours in seconds
        maxBackups: zod_1.z.coerce.number().default(7),
        storageDir: zod_1.z.string().default('/data/backups'),
    }),
});
// Parse and validate configuration
exports.config = configSchema.parse({
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
