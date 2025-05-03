"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.notificationRoutes = notificationRoutes;
async function notificationRoutes(server) {
    server.get('/notification/ping', async (_req, reply) => reply.send({ pong: true }));
}
