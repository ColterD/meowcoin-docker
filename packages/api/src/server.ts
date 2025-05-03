import Fastify, { FastifyInstance } from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import jwt from '@fastify/jwt';
import rateLimit from '@fastify/rate-limit';
import swagger from '@fastify/swagger';
import websocket from '@fastify/websocket';
import { MeowCoinRPC } from '@meowcoin/shared';
import { URL } from 'url';

import { config } from './config';
import { errorHandler } from './plugins/errorHandler';
import { registerRoutes } from './routes';
import { registerPlugins } from './plugins';

export async function buildServer(deps: { rpcClient?: any } = {}): Promise<FastifyInstance> {
  // Create Fastify instance
  const server = Fastify({
    logger: true,
    trustProxy: true,
  });

  // Register plugins
  await server.register(cors, {
    origin: config.corsOrigins,
    credentials: true,
  });

  await server.register(helmet, {
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", 'data:'],
      },
    },
  });

  await server.register(jwt, {
    secret: config.jwtSecret,
    sign: {
      expiresIn: config.jwtExpiresIn,
    },
  });

  await server.register(rateLimit, {
    max: config.rateLimit.max,
    timeWindow: config.rateLimit.windowMs,
    allowList: ['127.0.0.1'],
  });

  await server.register(websocket, {
    options: { maxPayload: 1048576 }, // 1MB
  });

  await server.register(swagger, {
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
      host: `localhost:${config.port}`,
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
  } as any);

  // Register custom plugins
  await registerPlugins(server);

  // Register global error handler
  server.setErrorHandler(errorHandler);

  // Register routes
  registerRoutes(server);

  // Health check route
  server.get('/health', async (request, reply) => {
    try {
      // Attempt to fetch node status via RPC
      const blockchainServiceUrl = config.services.blockchain;
      const response = await server.axios.get(`${blockchainServiceUrl}/blockchain/info`);
      const info = response.data?.data;
      let status: 'healthy' | 'degraded' | 'unhealthy' = 'healthy';
      let syncProgress = 100;
      let nodeMessage = 'Node is healthy and fully synced.';

      if (!info) {
        status = 'unhealthy';
        nodeMessage = 'Node info unavailable.';
      } else if (info.initialblockdownload || info.blocks < info.headers) {
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
    } catch (err: any) {
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
  const blockchainUrl = new URL(config.services.blockchain);
  const rpcConfig = {
    host: blockchainUrl.hostname,
    port: Number(blockchainUrl.port) || 9332,
    user: process.env.MEOWCOIN_RPC_USER || 'meowcoinuser',
    password: process.env.MEOWCOIN_RPC_PASSWORD || 'meowcoinpass',
    // add timeout if needed
  };
  const rpcClient = deps.rpcClient || new MeowCoinRPC(rpcConfig);
  (server as any).rpcClient = rpcClient;

  return server;
}