import { FastifyInstance } from 'fastify';
import { nodeRoutes } from './node';
import { userRoutes } from './user';
import { blockchainRoutes } from './blockchain';
import { analyticsRoutes } from './analytics';
import { notificationRoutes } from './notification';
import { webhookRoutes } from './webhook';

export function registerRoutes(server: FastifyInstance) {
  // Register all API routes
  server.register(nodeRoutes, { prefix: '/api/nodes' });
  server.register(userRoutes, { prefix: '/api/users' });
  server.register(blockchainRoutes, { prefix: '/api/blockchain' });
  server.register(analyticsRoutes, { prefix: '/api/analytics' });
  server.register(notificationRoutes, { prefix: '/api/notifications' });
  server.register(webhookRoutes, { prefix: '/api/webhooks' });
  
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
    fastify.get('/node-updates', { websocket: true }, (connection, req) => {
      // Handle WebSocket connection for node updates
      connection.socket.on('message', (message) => {
        // Process message
        const data = JSON.parse(message.toString());
        
        // Send updates
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
    
    fastify.get('/blockchain-updates', { websocket: true }, (connection, req) => {
      // Handle WebSocket connection for blockchain updates
      connection.socket.on('message', (message) => {
        // Process message
        const data = JSON.parse(message.toString());
        
        // Send updates
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