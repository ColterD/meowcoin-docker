"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildServer = buildServer;
const fastify_1 = __importDefault(require("fastify"));
const cors_1 = __importDefault(require("@fastify/cors"));
const helmet_1 = __importDefault(require("@fastify/helmet"));
const jwt_1 = __importDefault(require("@fastify/jwt"));
const rate_limit_1 = __importDefault(require("@fastify/rate-limit"));
const swagger_1 = __importDefault(require("@fastify/swagger"));
const websocket_1 = __importDefault(require("@fastify/websocket"));
const shared_1 = require("@meowcoin/shared");
const url_1 = require("url");
const config_1 = require("./config");
const errorHandler_1 = require("./plugins/errorHandler");
const routes_1 = require("./routes");
const plugins_1 = require("./plugins");
async function buildServer(deps = {}) {
    // Create Fastify instance
    const server = (0, fastify_1.default)({
        logger: true,
        trustProxy: true,
    });
    // Register plugins
    await server.register(cors_1.default, {
        origin: config_1.config.corsOrigins,
        credentials: true,
    });
    await server.register(helmet_1.default, {
        contentSecurityPolicy: {
            directives: {
                defaultSrc: ["'self'"],
                scriptSrc: ["'self'"],
                styleSrc: ["'self'", "'unsafe-inline'"],
                imgSrc: ["'self'", 'data:'],
            },
        },
    });
    await server.register(jwt_1.default, {
        secret: config_1.config.jwtSecret,
        sign: {
            expiresIn: config_1.config.jwtExpiresIn,
        },
    });
    await server.register(rate_limit_1.default, {
        max: config_1.config.rateLimit.max,
        timeWindow: config_1.config.rateLimit.windowMs,
        allowList: ['127.0.0.1'],
    });
    await server.register(websocket_1.default, {
        options: { maxPayload: 1048576 }, // 1MB
    });
    await server.register(swagger_1.default, {
        swagger: {
            info: {
                title: 'MeowCoin Platform API',
                description: 'API documentation for MeowCoin Platform',
                version: '2.0.0',
            },
            externalDocs: {
                url: 'https://meowcoin.com/docs',
                description: 'Find more info here',
            },
            host: `localhost:${config_1.config.port}`,
            schemes: ['http', 'https'],
            consumes: ['application/json'],
            produces: ['application/json'],
            securityDefinitions: {
                apiKey: {
                    type: 'apiKey',
                    name: 'x-api-key',
                    in: 'header',
                },
            },
        },
        exposeRoute: true,
    });
    // Register custom plugins
    await (0, plugins_1.registerPlugins)(server);
    // Register global error handler
    server.setErrorHandler(errorHandler_1.errorHandler);
    // Register routes
    (0, routes_1.registerRoutes)(server);
    // Health check route
    server.get('/health', async (request, reply) => {
        try {
            // Attempt to fetch node status via RPC
            const blockchainServiceUrl = config_1.config.services.blockchain;
            const response = await server.axios.get(`${blockchainServiceUrl}/blockchain/info`);
            const info = response.data?.data;
            let status = 'healthy';
            let syncProgress = 100;
            let nodeMessage = 'Node is healthy and fully synced.';
            if (!info) {
                status = 'unhealthy';
                nodeMessage = 'Node info unavailable.';
            }
            else if (info.initialblockdownload || info.blocks < info.headers) {
                status = 'degraded';
                syncProgress = Math.round((info.blocks / info.headers) * 100);
                nodeMessage = `Node is syncing (${syncProgress}%)`;
            }
            const result = {
                status,
                version: '2.0.0',
                timestamp: new Date().toISOString(),
                node: {
                    status,
                    message: nodeMessage,
                    version: info?.version,
                    protocolVersion: info?.protocolversion,
                    blocks: info?.blocks,
                    headers: info?.headers,
                    syncProgress,
                    initialBlockDownload: info?.initialblockdownload,
                },
                services: {
                    auth: 'healthy',
                    blockchain: status,
                    analytics: 'healthy',
                    notification: 'healthy',
                },
            };
            if (status === 'unhealthy') {
                return reply.status(503).send(result);
            }
            return result;
        }
        catch (err) {
            return reply.status(503).send({
                status: 'unhealthy',
                version: '2.0.0',
                timestamp: new Date().toISOString(),
                node: {
                    status: 'unhealthy',
                    message: err?.message || 'Node unreachable',
                },
                services: {
                    auth: 'healthy',
                    blockchain: 'unhealthy',
                    analytics: 'healthy',
                    notification: 'healthy',
                },
            });
        }
    });
    // Parse blockchain service URL for host/port
    const blockchainUrl = new url_1.URL(config_1.config.services.blockchain);
    const rpcConfig = {
        host: blockchainUrl.hostname,
        port: Number(blockchainUrl.port) || 9332,
        user: process.env.MEOWCOIN_RPC_USER || 'meowcoinuser',
        password: process.env.MEOWCOIN_RPC_PASSWORD || 'meowcoinpass',
        // add timeout if needed
    };
    const rpcClient = deps.rpcClient || new shared_1.MeowCoinRPC(rpcConfig);
    server.rpcClient = rpcClient;
    return server;
}
