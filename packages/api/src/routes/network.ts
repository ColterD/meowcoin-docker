import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { NetworkMetrics, NodeInfo } from '@meowcoin/shared';
// @ts-ignore: No type declaration for dist import
import { MeowCoinRPC } from '@meowcoin/blockchain/dist/services/meowcoinRPC';
// @ts-ignore: No type declaration for dist import
import { config } from '@meowcoin/blockchain/dist/config';
import { z } from 'zod';

// TODOs and Gaps (2025-05-XX):
// - Several TODOs for analytics, bandwidth, and distribution stats remain.
// - Use of 'any' in some places; type safety should be improved.
// - Mock/test logic for integration tests is present (acceptable for test env, but should be documented).
// - Error logging now uses structured logger, but review all error handling for consistency.

// Mock or real MeowCoinRPC depending on environment
let MeowCoinRPC, config;
if (process.env.NODE_ENV === 'test') {
  // Use mock only in test
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
} else if (process.env.NODE_ENV === 'development' || process.env.NODE_ENV === 'production') {
  try {
    ({ MeowCoinRPC } = require('../../../../node_modules/@meowcoin/blockchain/dist/services/meowcoinRPC.js'));
    ({ config } = require('../../../../node_modules/@meowcoin/blockchain/dist/config.js'));
  } catch (e) {
    try {
      ({ MeowCoinRPC } = require('@meowcoin/blockchain/dist/services/meowcoinRPC.js'));
      ({ config } = require('@meowcoin/blockchain/dist/config.js'));
    } catch (err) {
      throw new Error(
        'Failed to load MeowCoinRPC or config in production/development. Ensure the blockchain package is installed and built.'
      );
    }
  }
} else {
  throw new Error(
    `NODE_ENV ${process.env.NODE_ENV} is not supported. Use NODE_ENV=test for tests, or NODE_ENV=development/production for real node integration.`
  );
}

// TODO: Replace with real service imports
// import { getCurrentNetworkMetrics, getHistoricalNetworkHashrate } from '../services/network';

const rpcClient = new MeowCoinRPC({
  host: config.meowcoin.rpcHost,
  port: config.meowcoin.rpcPort,
  user: config.meowcoin.rpcUser,
  password: config.meowcoin.rpcPassword,
});

export async function networkRoutes(server: FastifyInstance) {
  // Zod schemas for possible query params (future extensibility)
  const infoQuerySchema = z.object({}); // No query params currently
  const statusQuerySchema = z.object({}); // No query params currently

  // Attach rpcClient for testability
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (server as any).rpcClient = rpcClient;
  server.get('/info', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      infoQuerySchema.parse(request.query);
      // Fetch current network stats
      const miningInfo = await rpcClient.getMiningInfo();
      const networkInfo = await rpcClient.getNetworkInfo();
      const peerInfo = await rpcClient.getPeerInfo(); // Array of peers
      const currentHashrate = miningInfo.networkhashps;

      // Parse inbound/outbound connections
      let inboundConnections = 0;
      let outboundConnections = 0;
      const geoDist: Record<string, number> = {};
      const versionDist: Record<string, number> = {};
      let totalBandwidth = 0;
      let inboundBandwidth = 0;
      let outboundBandwidth = 0;
      if (Array.isArray(peerInfo)) {
        for (const peer of peerInfo) {
          if (peer.inbound) inboundConnections++;
          else outboundConnections++;
          // Geographic distribution (by addr prefix, e.g., country code or IP block)
          const geoKey = peer.addr ? peer.addr.split(':')[0] : 'unknown';
          geoDist[geoKey] = (geoDist[geoKey] || 0) + 1;
          // Version distribution
          const verKey = peer.subver || 'unknown';
          versionDist[verKey] = (versionDist[verKey] || 0) + 1;
          // Bandwidth
          totalBandwidth += (peer.bytesSent || 0) + (peer.bytesRecv || 0);
          inboundBandwidth += peer.inbound ? (peer.bytesRecv || 0) : 0;
          outboundBandwidth += !peer.inbound ? (peer.bytesSent || 0) : 0;
        }
      }

      // Estimate previous hashrate (7 days ago)
      let previousHashrate: number | null = null;
      try {
        const blockCount = await rpcClient.getBlockCount();
        const blockHash7d = await rpcClient.getBlockHash(blockCount - 1008); // ~7 days ago at 10min/block
        const block7d = await rpcClient.getBlock(blockHash7d);
        const blockHashNow = await rpcClient.getBlockHash(blockCount);
        const blockNow = await rpcClient.getBlock(blockHashNow);
        const seconds = (blockNow.time - block7d.time);
        const hashes = (blockNow.difficulty + block7d.difficulty) / 2 * 2 ** 32 * 1008;
        previousHashrate = seconds > 0 ? hashes / seconds : null;
      } catch (e) {
        previousHashrate = null;
      }
      let hashrateChange: number | null = null;
      if (previousHashrate && previousHashrate > 0) {
        hashrateChange = ((currentHashrate - previousHashrate) / previousHashrate) * 100;
      }

      // TODO: Implement geographicDistribution, versionDistribution, bandwidth stats
      const metrics: NetworkMetrics = {
        totalNodes: networkInfo.connections,
        activeNodes: networkInfo.connections,
        totalConnections: networkInfo.connections,
        inboundConnections,
        outboundConnections,
        geographicDistribution: geoDist,
        versionDistribution: versionDist,
        totalBandwidth,
        inboundBandwidth,
        outboundBandwidth,
        lastUpdated: new Date().toISOString(),
        hashrateChange,
      };

      reply.send({ success: true, data: metrics as NetworkMetrics });
    } catch (err) {
      if (err instanceof z.ZodError) {
        server.log.error({ err }, 'Validation error in /network/info');
        return reply.status(400).send({ success: false, error: 'Invalid query parameters', details: err.errors });
      }
      // TODO: Replace with structured logger (pino)
      server.log.error({ err }, 'Error in /info:');
      reply.status(500).send({ success: false, error: 'Internal server error' });
    }
  });

  // GET /network/status
  server.get('/status', async (req, res) => {
    try {
      statusQuerySchema.parse(req.query);
      const { getNetworkStatus } = require('../../../blockchain/src/services/nodeManager');
      const status = await getNetworkStatus();
      res.send({ success: true, data: status as NodeInfo });
    } catch (err) {
      if (err instanceof z.ZodError) {
        return res.status(400).send({ success: false, error: 'Invalid query parameters', details: err.errors });
      }
      res.status(500).send({ success: false, error: 'Failed to fetch network status', details: err instanceof Error ? err.message : err });
    }
  });
}

export const testRpcClient = rpcClient; 