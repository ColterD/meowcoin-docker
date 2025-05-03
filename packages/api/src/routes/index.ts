import { FastifyInstance, RouteShorthandOptions } from 'fastify';
import { nodeRoutes } from './node';
import { userRoutes } from './user';
import { blockchainRoutes } from './blockchain';
import { analyticsRoutes } from './analytics';
import { notificationRoutes } from './notification';
import { webhookRoutes } from './webhook';
import { networkRoutes } from './network';
import WebSocket from 'ws';

export function registerRoutes(server: FastifyInstance) {
  // Register all API routes
  server.register(nodeRoutes, { prefix: '/api/nodes' });
  server.register(userRoutes, { prefix: '/api/users' });
  server.register(blockchainRoutes, { prefix: '/api/blockchain' });
  server.register(analyticsRoutes, { prefix: '/api/analytics' });
  server.register(notificationRoutes, { prefix: '/api/notifications' });
  server.register(webhookRoutes, { prefix: '/api/webhooks' });
  server.register(networkRoutes, { prefix: '/api/network' });
  
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
    // Node updates: stream real-time node info
    const wsOptions: RouteShorthandOptions = { websocket: true };
    fastify.get('/node-updates', wsOptions, (connection, _req) => {
      let interval: NodeJS.Timeout | null = null;
      let getNodeInfo: any;
      try {
        // Prefer local source import for dev
        getNodeInfo = require('../../../blockchain/src/services/nodeManager').getNodeInfo;
      } catch (e) {
        // Fallback to dist import for prod
        getNodeInfo = require('@meowcoin/blockchain/dist/services/nodeManager').getNodeInfo;
      }
      const sendNodeInfo = async () => {
        try {
          const nodeInfo = await getNodeInfo();
          (connection.socket as WebSocket).send(JSON.stringify({
            type: 'node-update',
            data: nodeInfo,
          }));
        } catch (err) {
          (connection.socket as WebSocket).send(JSON.stringify({
          type: 'node-update',
            error: 'Failed to fetch node info',
            details: err instanceof Error ? err.message : err,
        }));
        }
      };
      interval = setInterval(sendNodeInfo, 10000);
      sendNodeInfo();
      connection.socket.on('close', () => {
        if (interval) clearInterval(interval);
        fastify.log.info('WebSocket connection closed');
      });
    });
    // Blockchain updates: stream real-time blockchain info
    fastify.get('/blockchain-updates', wsOptions, (connection, _req) => {
      let interval: NodeJS.Timeout | null = null;
      let MeowCoinRPC: any, config: any;
      try {
        // Prefer local source import for dev
        MeowCoinRPC = require('../../../blockchain/src/services/meowcoinRPC').MeowCoinRPC;
        config = require('../../../blockchain/src/config').getConfig();
      } catch (e) {
        // Fallback to dist import for prod
        MeowCoinRPC = require('@meowcoin/blockchain/dist/services/meowcoinRPC').MeowCoinRPC;
        config = require('@meowcoin/blockchain/dist/config').config;
      }
      const sendBlockchainInfo = async () => {
        try {
          const rpc = new MeowCoinRPC({
            host: config.meowcoin.rpcHost,
            port: config.meowcoin.rpcPort,
            user: config.meowcoin.rpcUser,
            password: config.meowcoin.rpcPassword,
          });
          const info = await rpc.getBlockchainInfo();
          (connection.socket as WebSocket).send(JSON.stringify({
            type: 'blockchain-update',
            data: info,
          }));
        } catch (err) {
          (connection.socket as WebSocket).send(JSON.stringify({
          type: 'blockchain-update',
            error: 'Failed to fetch blockchain info',
            details: err instanceof Error ? err.message : err,
        }));
        }
      };
      interval = setInterval(sendBlockchainInfo, 10000);
      sendBlockchainInfo();
      connection.socket.on('close', () => {
        if (interval) clearInterval(interval);
        fastify.log.info('WebSocket connection closed');
      });
    });
  }, { prefix: '/ws' });
}