import { FastifyInstance } from 'fastify';
// @ts-ignore: No type declaration for dist import
import { MeowCoinRPC } from '@meowcoin/blockchain/dist/services/meowcoinRPC';
// @ts-ignore: No type declaration for dist import
import { config } from '@meowcoin/blockchain/dist/config';
import { Block, Transaction, MempoolInfo, BlockchainInfo } from '@meowcoin/shared';
import { z } from 'zod';

const blockHashSchema = z.object({ hash: z.string().min(1) });
const txidSchema = z.object({ txid: z.string().min(1) });

export async function blockchainRoutes(server: FastifyInstance) {
  const rpc = new MeowCoinRPC({
    host: config.meowcoin.rpcHost,
    port: config.meowcoin.rpcPort,
    user: config.meowcoin.rpcUser,
    password: config.meowcoin.rpcPassword,
  });

  // GET /blockchain/info
  server.get('/info', async (req, res) => {
    try {
      const info = await rpc.getBlockchainInfo();
      res.send({ success: true, data: info });
    } catch (err) {
      res.status(500).send({ success: false, error: 'Failed to fetch blockchain info', details: err instanceof Error ? err.message : err });
    }
  });

  // GET /blockchain/block/:hash
  server.get('/block/:hash', async (req, reply) => {
    try {
      const params = blockHashSchema.parse(req.params);
      const { hash } = params;
      const block = await rpc.getBlock(hash);
      reply.send({ success: true, data: block as Block });
    } catch (err) {
      server.log.error({ err }, 'Error in /blockchain/block/:hash');
      reply.status(500).send({ success: false, error: 'Internal server error' });
    }
  });

  // GET /blockchain/transaction/:txid
  server.get('/transaction/:txid', async (req, reply) => {
    try {
      const params = txidSchema.parse(req.params);
      const { txid } = params;
      const tx = await rpc.getRawTransaction(txid);
      reply.send({ success: true, data: tx as Transaction });
    } catch (err) {
      server.log.error({ err }, 'Error in /blockchain/transaction/:txid');
      reply.status(500).send({ success: false, error: 'Internal server error' });
    }
  });

  // GET /blockchain/mempool
  server.get('/mempool', async (_req, reply) => {
    try {
      const mempool = await rpc.getMempoolInfo();
      reply.send({ success: true, data: mempool as MempoolInfo });
    } catch (err) {
      server.log.error({ err }, 'Error in /blockchain/mempool');
      reply.status(500).send({ success: false, error: 'Internal server error' });
    }
  });
} 