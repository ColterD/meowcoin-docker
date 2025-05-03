"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.registerRoutes = registerRoutes;
const node_1 = require("./node");
const user_1 = require("./user");
const blockchain_1 = require("./blockchain");
const analytics_1 = require("./analytics");
const notification_1 = require("./notification");
const webhook_1 = require("./webhook");
const network_1 = require("./network");
function registerRoutes(server) {
    // Register all API routes
    server.register(node_1.nodeRoutes, { prefix: '/api/nodes' });
    server.register(user_1.userRoutes, { prefix: '/api/users' });
    server.register(blockchain_1.blockchainRoutes, { prefix: '/api/blockchain' });
    server.register(analytics_1.analyticsRoutes, { prefix: '/api/analytics' });
    server.register(notification_1.notificationRoutes, { prefix: '/api/notifications' });
    server.register(webhook_1.webhookRoutes, { prefix: '/api/webhooks' });
    server.register(network_1.networkRoutes, { prefix: '/api/network' });
    // Register authentication routes
    server.register(async function authRoutes(fastify) {
        // Login route
        fastify.post('/login', {
            schema: {
                body: {
                    type: 'object',
                    required: ['username', 'password'],
                    properties: {
                        username: { type: 'string' },
                        password: { type: 'string' },
                        mfaCode: { type: 'string' },
                    },
                },
                response: {
                    200: {
                        type: 'object',
                        properties: {
                            success: { type: 'boolean' },
                            data: {
                                type: 'object',
                                properties: {
                                    accessToken: { type: 'string' },
                                    refreshToken: { type: 'string' },
                                    expiresIn: { type: 'number' },
                                    user: { type: 'object' },
                                    requiresMfa: { type: 'boolean' },
                                },
                            },
                        },
                    },
                },
            },
            handler: async (request, reply) => {
                // Forward to auth service
                const authServiceUrl = server.config.services.auth;
                const response = await server.axios.post(`${authServiceUrl}/login`, request.body);
                return reply.send(response.data);
            },
        });
        // Refresh token route
        fastify.post('/refresh-token', {
            schema: {
                body: {
                    type: 'object',
                    required: ['refreshToken'],
                    properties: {
                        refreshToken: { type: 'string' },
                    },
                },
            },
            handler: async (request, reply) => {
                // Forward to auth service
                const authServiceUrl = server.config.services.auth;
                const response = await server.axios.post(`${authServiceUrl}/refresh-token`, request.body);
                return reply.send(response.data);
            },
        });
        // Logout route
        fastify.post('/logout', {
            schema: {
                body: {
                    type: 'object',
                    required: ['refreshToken'],
                    properties: {
                        refreshToken: { type: 'string' },
                    },
                },
            },
            handler: async (request, reply) => {
                // Forward to auth service
                const authServiceUrl = server.config.services.auth;
                const response = await server.axios.post(`${authServiceUrl}/logout`, request.body);
                return reply.send(response.data);
            },
        });
    }, { prefix: '/api/auth' });
    // Register WebSocket routes
    server.register(async function wsRoutes(fastify) {
        // TODO: Replace 'any' with a proper type for WebSocket route options
        fastify.get('/node-updates', { websocket: true }, (connection, req) => {
            // Handle WebSocket connection for node updates
            // TODO: Replace 'any' with a proper type for WebSocket message
            connection.socket.on('message', (message) => {
                // Process message
                const data = JSON.parse(message.toString());
                // Send updates
                // TODO: Replace 'any' with a proper type for WebSocket socket
                connection.socket.send(JSON.stringify({
                    type: 'node-update',
                    data: {
                        // Node data would come from the blockchain service
                        id: data.nodeId,
                        status: 'running',
                        resources: {
                            cpuUsage: 45,
                            memoryUsage: 60,
                            diskUsage: 30,
                        },
                        timestamp: new Date().toISOString(),
                    },
                }));
            });
            // Handle disconnection
            connection.socket.on('close', () => {
                fastify.log.info('WebSocket connection closed');
            });
        });
        // TODO: Replace 'any' with a proper type for WebSocket route options
        fastify.get('/blockchain-updates', { websocket: true }, (connection, req) => {
            // Handle WebSocket connection for blockchain updates
            // TODO: Replace 'any' with a proper type for WebSocket message
            connection.socket.on('message', (message) => {
                // Process message
                const data = JSON.parse(message.toString());
                // Send updates
                // TODO: Replace 'any' with a proper type for WebSocket socket
                connection.socket.send(JSON.stringify({
                    type: 'blockchain-update',
                    data: {
                        // Blockchain data would come from the blockchain service
                        blockHeight: 12345,
                        transactions: 100,
                        timestamp: new Date().toISOString(),
                    },
                }));
            });
            // Handle disconnection
            connection.socket.on('close', () => {
                fastify.log.info('WebSocket connection closed');
            });
        });
    }, { prefix: '/ws' });
}
