"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.nodeRoutes = nodeRoutes;
const shared_1 = require("@meowcoin/shared");
async function nodeRoutes(fastify) {
    // Get all nodes
    fastify.get('/', {
        schema: {
            response: {
                200: {
                    type: 'object',
                    properties: {
                        success: { type: 'boolean' },
                        data: {
                            type: 'array',
                            items: {
                                type: 'object',
                                properties: {
                                    id: { type: 'string' },
                                    name: { type: 'string' },
                                    type: { type: 'string' },
                                    status: { type: 'string' },
                                    // Additional properties...
                                },
                            },
                        },
                    },
                },
            },
        },
        onRequest: [fastify.authenticate],
        handler: async (request, reply) => {
            // Forward to blockchain service
            const blockchainServiceUrl = fastify.config.services.blockchain;
            const response = await fastify.axios.get(`${blockchainServiceUrl}/nodes`, {
                headers: {
                    Authorization: request.headers.authorization,
                },
            });
            return reply.send(response.data);
        },
    });
    // Get node by ID
    fastify.get('/:id', {
        schema: {
            params: {
                type: 'object',
                required: ['id'],
                properties: {
                    id: { type: 'string' },
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
                                id: { type: 'string' },
                                name: { type: 'string' },
                                type: { type: 'string' },
                                status: { type: 'string' },
                                // Additional properties...
                            },
                        },
                    },
                },
            },
        },
        onRequest: [fastify.authenticate],
        handler: async (request, reply) => {
            const { id } = request.params;
            // Forward to blockchain service
            const blockchainServiceUrl = fastify.config.services.blockchain;
            const response = await fastify.axios.get(`${blockchainServiceUrl}/nodes/${id}`, {
                headers: {
                    Authorization: request.headers.authorization,
                },
            });
            return reply.send(response.data);
        },
    });
    // Create a new node
    fastify.post('/', {
        schema: {
            body: {
                type: 'object',
                required: ['name', 'type'],
                properties: {
                    name: { type: 'string' },
                    type: {
                        type: 'string',
                        enum: Object.values(shared_1.NodeType),
                    },
                    rpcEnabled: { type: 'boolean' },
                    rpcPort: { type: 'number' },
                    p2pPort: { type: 'number' },
                    // Additional properties...
                },
            },
            response: {
                201: {
                    type: 'object',
                    properties: {
                        success: { type: 'boolean' },
                        data: {
                            type: 'object',
                            properties: {
                                id: { type: 'string' },
                                name: { type: 'string' },
                                // Additional properties...
                            },
                        },
                    },
                },
            },
        },
        onRequest: [fastify.authenticate, fastify.authorize(['admin', 'operator'])],
        handler: async (request, reply) => {
            // Forward to blockchain service
            const blockchainServiceUrl = fastify.config.services.blockchain;
            const response = await fastify.axios.post(`${blockchainServiceUrl}/nodes`, request.body, {
                headers: {
                    Authorization: request.headers.authorization,
                },
            });
            return reply.status(201).send(response.data);
        },
    });
    // Update a node
    fastify.patch('/:id', {
        schema: {
            params: {
                type: 'object',
                required: ['id'],
                properties: {
                    id: { type: 'string' },
                },
            },
            body: {
                type: 'object',
                properties: {
                    name: { type: 'string' },
                    rpcEnabled: { type: 'boolean' },
                    rpcPort: { type: 'number' },
                    p2pPort: { type: 'number' },
                    // Additional properties...
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
                                id: { type: 'string' },
                                name: { type: 'string' },
                                // Additional properties...
                            },
                        },
                    },
                },
            },
        },
        onRequest: [fastify.authenticate, fastify.authorize(['admin', 'operator'])],
        handler: async (request, reply) => {
            const { id } = request.params;
            // Forward to blockchain service
            const blockchainServiceUrl = fastify.config.services.blockchain;
            const response = await fastify.axios.patch(`${blockchainServiceUrl}/nodes/${id}`, request.body, {
                headers: {
                    Authorization: request.headers.authorization,
                },
            });
            return reply.send(response.data);
        },
    });
    // Delete a node
    fastify.delete('/:id', {
        schema: {
            params: {
                type: 'object',
                required: ['id'],
                properties: {
                    id: { type: 'string' },
                },
            },
            response: {
                200: {
                    type: 'object',
                    properties: {
                        success: { type: 'boolean' },
                        message: { type: 'string' },
                    },
                },
            },
        },
        onRequest: [fastify.authenticate, fastify.authorize(['admin'])],
        handler: async (request, reply) => {
            const { id } = request.params;
            // Forward to blockchain service
            const blockchainServiceUrl = fastify.config.services.blockchain;
            const response = await fastify.axios.delete(`${blockchainServiceUrl}/nodes/${id}`, {
                headers: {
                    Authorization: request.headers.authorization,
                },
            });
            return reply.send(response.data);
        },
    });
    // Perform an action on a node
    fastify.post('/:id/actions', {
        schema: {
            params: {
                type: 'object',
                required: ['id'],
                properties: {
                    id: { type: 'string' },
                },
            },
            body: {
                type: 'object',
                required: ['action'],
                properties: {
                    action: {
                        type: 'string',
                        enum: Object.values(shared_1.NodeAction),
                    },
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
                                id: { type: 'string' },
                                status: { type: 'string' },
                                // Additional properties...
                            },
                        },
                    },
                },
            },
        },
        onRequest: [fastify.authenticate, fastify.authorize(['admin', 'operator'])],
        handler: async (request, reply) => {
            const { id } = request.params;
            // Forward to blockchain service
            const blockchainServiceUrl = fastify.config.services.blockchain;
            const response = await fastify.axios.post(`${blockchainServiceUrl}/nodes/${id}/actions`, request.body, {
                headers: {
                    Authorization: request.headers.authorization,
                },
            });
            return reply.send(response.data);
        },
    });
    // Get node metrics
    fastify.get('/:id/metrics', {
        schema: {
            params: {
                type: 'object',
                required: ['id'],
                properties: {
                    id: { type: 'string' },
                },
            },
            querystring: {
                type: 'object',
                properties: {
                    timeRange: { type: 'string', enum: ['1h', '6h', '24h', '7d', '30d'] },
                    interval: { type: 'string', enum: ['minute', 'hour', 'day'] },
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
                                cpu: {
                                    type: 'array',
                                    items: {
                                        type: 'object',
                                        properties: {
                                            timestamp: { type: 'string' },
                                            value: { type: 'number' },
                                        },
                                    },
                                },
                                memory: {
                                    type: 'array',
                                    items: {
                                        type: 'object',
                                        properties: {
                                            timestamp: { type: 'string' },
                                            value: { type: 'number' },
                                        },
                                    },
                                },
                                // Additional metrics...
                            },
                        },
                    },
                },
            },
        },
        onRequest: [fastify.authenticate],
        handler: async (request, reply) => {
            const { id } = request.params;
            const query = request.query;
            // Forward to analytics service
            const analyticsServiceUrl = fastify.config.services.analytics;
            const response = await fastify.axios.get(`${analyticsServiceUrl}/nodes/${id}/metrics`, {
                params: query,
                headers: {
                    Authorization: request.headers.authorization,
                },
            });
            return reply.send(response.data);
        },
    });
    // Get node backups
    fastify.get('/:id/backups', {
        schema: {
            params: {
                type: 'object',
                required: ['id'],
                properties: {
                    id: { type: 'string' },
                },
            },
            response: {
                200: {
                    type: 'object',
                    properties: {
                        success: { type: 'boolean' },
                        data: {
                            type: 'array',
                            items: {
                                type: 'object',
                                properties: {
                                    id: { type: 'string' },
                                    createdAt: { type: 'string' },
                                    size: { type: 'number' },
                                    // Additional properties...
                                },
                            },
                        },
                    },
                },
            },
        },
        onRequest: [fastify.authenticate],
        handler: async (request, reply) => {
            const { id } = request.params;
            // Forward to blockchain service
            const blockchainServiceUrl = fastify.config.services.blockchain;
            const response = await fastify.axios.get(`${blockchainServiceUrl}/nodes/${id}/backups`, {
                headers: {
                    Authorization: request.headers.authorization,
                },
            });
            return reply.send(response.data);
        },
    });
}
