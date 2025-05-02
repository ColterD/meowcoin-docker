import Fastify, { FastifyInstance } from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import jwt from '@fastify/jwt';
import rateLimit from '@fastify/rate-limit';
import swagger from '@fastify/swagger';
import websocket from '@fastify/websocket';

import { config } from './config';
import { logger } from './utils/logger';
import { errorHandler } from './plugins/errorHandler';
import { registerRoutes } from './routes';
import { registerPlugins } from './plugins';

export async function buildServer(): Promise<FastifyInstance> {
  // Create Fastify instance
  const server = Fastify({
    logger,
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
  await registerPlugins(server);

  // Register global error handler
  server.setErrorHandler(errorHandler);

  // Register routes
  registerRoutes(server);

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