"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const supertest_1 = __importDefault(require("supertest"));
const network_1 = require("./network");
// Set required env for config validation and mocking
process.env.DATABASE_URL = 'file:./test.sqlite';
process.env.NODE_ENV = 'test';
const server_1 = require("../server");
// NOTE: This test uses mock data for integration testing. This is acceptable for test environments, but should be documented and reviewed for production.
describe('GET /api/network/info', () => {
    let server;
    beforeAll(async () => {
        server = await (0, server_1.buildServer)();
        await server.listen({ port: 0 }); // Use ephemeral port
    });
    afterAll(async () => {
        await server.close();
    });
    it('should return a valid response object (mocked)', async () => {
        const res = await (0, supertest_1.default)(server.server).get('/api/network/info');
        expect(res.status).toBe(200);
        expect(res.body).toBeDefined();
        expect(res.body.success).toBe(true);
        expect(res.body.data).toBeDefined();
        expect(res.body.data.totalNodes).toBe(8);
        expect(res.body.data.inboundConnections).toBe(2);
        expect(res.body.data.outboundConnections).toBe(2);
        expect(res.body.data.hashrateChange).toBeNull();
    });
    it('should handle errors gracefully', async () => {
        // Patch the mock to throw
        const orig = network_1.testRpcClient.getMiningInfo;
        network_1.testRpcClient.getMiningInfo = async () => { throw new Error('mock error'); };
        const res = await (0, supertest_1.default)(server.server).get('/api/network/info');
        expect(res.status).toBe(500);
        expect(res.body.success).toBe(false);
        expect(res.body.error).toBeDefined();
        // Restore
        network_1.testRpcClient.getMiningInfo = orig;
    });
});
