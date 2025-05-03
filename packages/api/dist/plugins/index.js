"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.registerPlugins = registerPlugins;
const fastify_plugin_1 = __importDefault(require("fastify-plugin"));
const ioredis_1 = __importDefault(require("ioredis"));
const config_1 = require("../config");
// Redis client plugin
async function redisPlugin(fastify) {
    const redis = new ioredis_1.default({
        host: config_1.config.redis.host,
        port: config_1.config.redis.port,
        password: config_1.config.redis.password,
        maxRetriesPerRequest: 3,
    });
    // Handle Redis connection events
    redis.on('connect', () => {
        fastify.log.info('Redis client connected');
    });
    redis.on('error', (err) => {
        fastify.log.error({ err }, 'Redis client error');
    });
    // Add Redis client to Fastify instance
    fastify.decorate('redis', redis);
    // Close Redis connection when Fastify closes
    fastify.addHook('onClose', async (instance) => {
        await instance.redis.quit();
    });
}
// Authentication plugin
async function authPlugin(fastify) {
    // Add authentication decorator
    fastify.decorate('authenticate', async (request, reply) => {
        try {
            await request.jwtVerify();
        }
        catch (err) {
            reply.send(err);
        }
    });
    // Add role-based authorization decorator
    fastify.decorate('authorize', (roles) => {
        return async (request, reply) => {
            if (!request.user) {
                return reply.status(401).send({
                    success: false,
                    message: 'Authentication required',
                    code: 'UNAUTHORIZED',
                    timestamp: new Date().toISOString(),
                });
            }
            const userRole = request.user.role;
            if (!roles.includes(userRole)) {
                return reply.status(403).send({
                    success: false,
                    message: 'Insufficient permissions',
                    code: 'FORBIDDEN',
                    timestamp: new Date().toISOString(),
                });
            }
        };
    });
}
// Register all plugins
async function registerPlugins(fastify) {
    // Register Redis plugin
    fastify.register((0, fastify_plugin_1.default)(redisPlugin));
    // Register authentication plugin
    fastify.register((0, fastify_plugin_1.default)(authPlugin));
    // Add request ID to each request
    fastify.addHook('onRequest', (request, _, done) => {
        request.id = request.id || crypto.randomUUID();
        done();
    });
    // Add response time header
    fastify.addHook('onResponse', (request, reply, done) => {
        reply.header('X-Response-Time', reply.getResponseTime().toFixed(2) + 'ms');
        done();
    });
}
