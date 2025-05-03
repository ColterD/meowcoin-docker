import { FastifyInstance } from 'fastify';
import { z } from 'zod';

export async function webhookRoutes(server: FastifyInstance) {
  // Zod schemas
  const webhookBodySchema = z.object({}).passthrough(); // Accept any object, but must be an object

  // POST /webhooks
  server.post('/', async (request, reply) => {
    try {
      webhookBodySchema.parse(request.body);
      server.log.info({ body: request.body }, 'Received webhook event');
      reply.send({ success: true as boolean });
    } catch (err) {
      if (err instanceof z.ZodError) {
        server.log.error({ err }, 'Validation error in /webhooks');
        return reply.status(400).send({ success: false, error: 'Invalid webhook body', details: err.errors });
      }
      server.log.error({ err }, 'Error in /webhooks');
      reply.status(500).send({ success: false, error: 'Internal server error' });
    }
  });

  // POST /webhook/trigger
  server.post('/trigger', async (req, res) => {
    try {
      webhookBodySchema.parse(req.body);
      const { triggerWebhook } = require('../../../blockchain/src/services/webhook');
      const result = await triggerWebhook(req.body);
      res.send({ success: true, data: result });
    } catch (err) {
      if (err instanceof z.ZodError) {
        return res.status(400).send({ success: false, error: 'Invalid webhook body', details: err.errors });
      }
      res.status(500).send({ success: false, error: 'Failed to trigger webhook', details: err instanceof Error ? err.message : err });
    }
  });
} 