"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.userRoutes = userRoutes;
async function userRoutes(server) {
    server.get('/user/ping', async (_req, reply) => reply.send({ pong: true }));
}
