"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.networkRoutes = networkRoutes;
const meowcoinRPC_1 = require("../../../blockchain/src/services/meowcoinRPC");
const config_1 = require("../../../blockchain/src/config");
// TODO: Replace with real service imports
// import { getCurrentNetworkMetrics, getHistoricalNetworkHashrate } from '../services/network';
const rpcClient = new meowcoinRPC_1.MeowCoinRPC({
    host: config_1.config.meowcoin.rpcHost,
    port: config_1.config.meowcoin.rpcPort,
    user: config_1.config.meowcoin.rpcUser,
    password: config_1.config.meowcoin.rpcPassword,
});
async function networkRoutes(server) {
    server.get('/network/info', async (_request, reply) => {
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
            // Log error internally, but do not leak sensitive info
            console.error('Error in /network/info:', err);
            reply.status(500).send({ success: false, error: 'Internal server error' });
        }
    });
}
