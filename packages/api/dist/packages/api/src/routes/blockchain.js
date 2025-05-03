"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.blockchainRoutes = blockchainRoutes;
async function blockchainRoutes(server) {
    server.get('/blockchain/ping', async (_req, reply) => reply.send({ pong: true }));
}
