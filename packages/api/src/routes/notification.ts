import { FastifyInstance } from 'fastify';
// @ts-ignore: No type declaration for dist import
import { prisma } from '@meowcoin/blockchain/dist/utils/prisma';
import { NodeAlert, Notification } from '@meowcoin/shared';
import { z } from 'zod';

export async function notificationRoutes(server: FastifyInstance) {
  // Zod schemas
  const notificationIdSchema = z.object({ id: z.string().min(1) });
  // GET /notifications
  server.get('/', async (_req, reply) => {
    try {
      const alerts = await prisma.nodeAlert.findMany({ orderBy: { createdAt: 'desc' } });
      reply.send({ success: true, data: alerts as NodeAlert[] });
    } catch (err) {
      server.log.error({ err }, 'Error in /notifications');
      reply.status(500).send({ success: false, error: 'Internal server error' });
    }
  });

  // GET /notification/:id
  server.get('/:id', async (req, res) => {
    try {
      const params = notificationIdSchema.parse(req.params);
      const { getNotificationById } = require('../../../blockchain/src/services/notifications');
      const { id } = params;
      const notification = await getNotificationById(id);
      if (!notification) return res.status(404).send({ success: false, error: 'Notification not found' });
      res.send({ success: true, data: notification as Notification });
    } catch (err) {
      if (err instanceof z.ZodError) {
        return res.status(400).send({ success: false, error: 'Invalid parameters', details: err.errors });
      }
      res.status(500).send({ success: false, error: 'Failed to fetch notification', details: err instanceof Error ? err.message : err });
    }
  });
} 