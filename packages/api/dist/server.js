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
const config_1 = require("./config");
const logger_1 = require("./utils/logger");
const errorHandler_1 = require("./plugins/errorHandler");
const routes_1 = require("./routes");
const plugins_1 = require("./plugins");
async function buildServer() {
    // Create Fastify instance
    const server = (0, fastify_1.default)({
        logger: logger_1.logger,
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
        routePrefix: '/documentation',
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
                bearerAuth: {
                    type: 'http',
                    scheme: 'bearer',
                    bearerFormat: 'JWT',
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
    server.get('/health', async () => {
        return {
            status: 'healthy',
            version: '2.0.0',
            timestamp: new Date().toISOString(),
            services: {
                auth: 'healthy',
                blockchain: 'healthy',
                analytics: 'healthy',
                notification: 'healthy',
            },
        };
    });
    return server;
}
