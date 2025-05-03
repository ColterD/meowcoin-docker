import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import fp from 'fastify-plugin';
import Redis from 'ioredis';
import { config } from '../config';
import axios from 'axios';

declare module 'fastify' {
  interface FastifyInstance {
    redis: Redis;
    authenticate: (request: FastifyRequest, reply: FastifyReply) => Promise<void>;
    authorize: (roles: string[]) => (request: FastifyRequest, reply: FastifyReply) => Promise<void>;
    config: typeof config;
    axios: typeof axios;
  }
}

// Redis client plugin
async function redisPlugin(fastify: FastifyInstance) {
  const redis = new Redis({
    host: config.redis.host,
    port: config.redis.port,
    password: config.redis.password,
    maxRetriesPerRequest: 3,
  });

  redis.on('connect', () => {
    fastify.log.info('Redis client connected');
  });

  redis.on('error', (err) => {
    fastify.log.error({ err }, 'Redis client error');
  });

  fastify.decorate('redis', redis);
  fastify.addHook('onClose', async (instance: FastifyInstance) => {
    await instance.redis.quit();
  });
}

// User type guard for FastifyRequest.user
function hasUserRole(user: unknown): user is { role: string } {
  return typeof user === 'object' && user !== null && 'role' in user && typeof (user as any).role === 'string';
}

// Authentication plugin
async function authPlugin(fastify: FastifyInstance) {
  fastify.decorate('authenticate', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      await request.jwtVerify();
    } catch (err) {
      reply.send(err);
    }
  });

  fastify.decorate('authorize', (roles: string[]) => {
    return async (request: FastifyRequest, reply: FastifyReply) => {
      let userRole: string | undefined;
      if (hasUserRole(request.user)) {
        userRole = request.user.role;
      }
      if (!userRole || !roles.includes(userRole)) {
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
  
  // Decorate config and axios
  fastify.decorate('config', config);
  fastify.decorate('axios', axios.create());
  
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