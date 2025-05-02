import { FastifyInstance } from 'fastify';
import fp from 'fastify-plugin';
import Redis from 'ioredis';
import { config } from '../config';

// Redis client plugin
async function redisPlugin(fastify: FastifyInstance) {
  const redis = new Redis({
    host: config.redis.host,
    port: config.redis.port,
    password: config.redis.password,
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
async function authPlugin(fastify: FastifyInstance) {
  // Add authentication decorator
  fastify.decorate('authenticate', async (request, reply) => {
    try {
      await request.jwtVerify();
    } catch (err) {
      reply.send(err);
    }
  });

  // Add role-based authorization decorator
  fastify.decorate('authorize', (roles: string[]) => {
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
export async function registerPlugins(fastify: FastifyInstance) {
  // Register Redis plugin
  fastify.register(fp(redisPlugin));
  
  // Register authentication plugin
  fastify.register(fp(authPlugin));
  
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