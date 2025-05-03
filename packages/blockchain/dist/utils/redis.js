"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.redis = void 0;
const ioredis_1 = __importDefault(require("ioredis"));
const config_1 = require("../config");
const logger_1 = require("./logger");
// Create Redis client
exports.redis = new ioredis_1.default({
    host: config_1.config.redis.host,
    port: config_1.config.redis.port,
    password: config_1.config.redis.password,
    maxRetriesPerRequest: 3,
});
// Handle Redis events
exports.redis.on('connect', () => {
    logger_1.logger.info('Connected to Redis');
});
exports.redis.on('error', (error) => {
    logger_1.logger.error(error, 'Redis error');
});
exports.redis.on('reconnecting', () => {
    logger_1.logger.warn('Reconnecting to Redis');
});
// Handle process exit
process.on('beforeExit', async () => {
    await exports.redis.quit();
    logger_1.logger.info('Disconnected from Redis');
});
