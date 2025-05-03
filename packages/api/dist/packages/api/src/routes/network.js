"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.testRpcClient = void 0;
exports.networkRoutes = networkRoutes;
// TODOs and Gaps (2025-05-XX):
// - Several TODOs for analytics, bandwidth, and distribution stats remain.
// - Use of 'any' in some places; type safety should be improved.
// - Mock/test logic for integration tests is present (acceptable for test env, but should be documented).
// - Error logging now uses structured logger, but review all error handling for consistency.
// Mock or real MeowCoinRPC depending on environment
let MeowCoinRPC, config;
if (process.env.NODE_ENV === 'test' || process.env.NODE_ENV === 'development' || process.env.NODE_ENV === 'production') {
    // Use real or mock based on test/dev/prod
    if (process.env.NODE_ENV === 'test') {
        // Simple mock for integration tests
        MeowCoinRPC = class {
            async getMiningInfo() {
                return { networkhashps: 123456789 };
            }
            async getNetworkInfo() {
                return { connections: 8 };
            }
            async getPeerInfo() {
                return [
                    { inbound: true },
                    { inbound: false },
                    { inbound: true },
                    { inbound: false },
                ];
            }
        };
        config = { meowcoin: { rpcHost: '', rpcPort: 0, rpcUser: '', rpcPassword: '' } };
    }
    else {
        try {
            ({ MeowCoinRPC } = require('../../../../node_modules/@meowcoin/blockchain/dist/services/meowcoinRPC.js'));
            ({ config } = require('../../../../node_modules/@meowcoin/blockchain/dist/config.js'));
        }
        catch (e) {
            ({ MeowCoinRPC } = require('@meowcoin/blockchain/dist/services/meowcoinRPC.js'));
            ({ config } = require('@meowcoin/blockchain/dist/config.js'));
        }
    }
}
else {
    // Default to mock for unknown NODE_ENV
    MeowCoinRPC = class {
        async getMiningInfo() {
            return { networkhashps: 123456789 };
        }
        async getNetworkInfo() {
            return { connections: 8 };
        }
        async getPeerInfo() {
            return [
                { inbound: true },
                { inbound: false },
                { inbound: true },
                { inbound: false },
            ];
        }
    };
    config = { meowcoin: { rpcHost: '', rpcPort: 0, rpcUser: '', rpcPassword: '' } };
}
// TODO: Replace with real service imports
// import { getCurrentNetworkMetrics, getHistoricalNetworkHashrate } from '../services/network';
const rpcClient = new MeowCoinRPC({
    host: config.meowcoin.rpcHost,
    port: config.meowcoin.rpcPort,
    user: config.meowcoin.rpcUser,
    password: config.meowcoin.rpcPassword,
});
async function networkRoutes(server) {
    // Attach rpcClient for testability
    server.rpcClient = rpcClient;
    server.get('/info', async (_request, reply) => {
        try {
            // Fetch current network stats
            const miningInfo = await rpcClient.getMiningInfo();
            const networkInfo = await rpcClient.getNetworkInfo();
            const peerInfo = await rpcClient.getPeerInfo(); // Array of peers
            const currentHashrate = miningInfo.networkhashps;
            // Parse inbound/outbound connections
            let inboundConnections = 0;
            let outboundConnections = 0;
            if (Array.isArray(peerInfo)) {
                for (const peer of peerInfo) {
                    if (peer.inbound)
                        inboundConnections++;
                    else
                        outboundConnections++;
                }
            }
            // TODO: Estimate previous hashrate (7 days ago) using analytics or block history
            const previousHashrate = null; // Not implemented yet
            let hashrateChange = null;
            if (previousHashrate && previousHashrate > 0) {
                hashrateChange = ((currentHashrate - previousHashrate) / previousHashrate) * 100;
            }
            // TODO: Implement geographicDistribution, versionDistribution, bandwidth stats
            const metrics = {
                totalNodes: networkInfo.connections, // Approximation
                activeNodes: networkInfo.connections, // Approximation
                totalConnections: networkInfo.connections,
                inboundConnections,
                outboundConnections,
                geographicDistribution: {}, // TODO: Implement if available
                versionDistribution: {}, // TODO: Implement if available
                totalBandwidth: 0, // TODO: Implement if available
                inboundBandwidth: 0, // TODO: Implement if available
                outboundBandwidth: 0, // TODO: Implement if available
                lastUpdated: new Date().toISOString(),
                hashrateChange,
            };
            reply.send({ success: true, data: metrics });
        }
        catch (err) {
            // TODO: Replace with structured logger (pino)
            server.log.error({ err }, 'Error in /info:');
            reply.status(500).send({ success: false, error: 'Internal server error' });
        }
    });
}
exports.testRpcClient = rpcClient;
