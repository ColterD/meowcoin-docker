"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.webhookRoutes = webhookRoutes;
async function webhookRoutes(server) {
    server.get('/webhook/ping', async (_req, reply) => reply.send({ pong: true }));
}
