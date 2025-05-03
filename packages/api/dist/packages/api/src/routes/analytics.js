"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.analyticsRoutes = analyticsRoutes;
async function analyticsRoutes(server) {
    server.get('/analytics/ping', async (_req, reply) => reply.send({ pong: true }));
}
