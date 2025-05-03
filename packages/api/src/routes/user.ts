import { FastifyInstance } from 'fastify';
import { UserProfile } from '@meowcoin/shared';
import { z } from 'zod';

const userIdSchema = z.object({ id: z.string().min(1) });

export async function userRoutes(server: FastifyInstance) {
  // GET /users/me
  server.get('/me', { preValidation: [server.authenticate] }, async (request, reply) => {
    // Return the authenticated user's info
    // @ts-ignore: user is injected by authentication middleware
    const user = request.user;
    if (!user) {
      return reply.status(401).send({ success: false, error: 'Unauthorized' });
    }
    reply.send({ success: true, data: user as UserProfile });
  });

  // GET /user/:id
  server.get('/:id', async (req, res) => {
    try {
      const { getUserById } = require('../../../blockchain/src/services/user');
      const params = userIdSchema.parse(req.params);
      const { id } = params;
      const user = await getUserById(id);
      if (!user) return res.status(404).send({ success: false, error: 'User not found' });
      res.send({ success: true, data: user as UserProfile });
    } catch (err) {
      res.status(500).send({ success: false, error: 'Failed to fetch user', details: err instanceof Error ? err.message : err });
    }
  });
} 