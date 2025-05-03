import { FastifyInstance } from 'fastify';
// @ts-ignore: No type declaration for dist import
import { prisma } from '@meowcoin/blockchain/dist/utils/prisma';
import { Block } from '@meowcoin/shared';
import { z } from 'zod';

function toDate(val: Date | number): Date {
  return val instanceof Date ? val : new Date(val);
}

export async function analyticsRoutes(server: FastifyInstance) {
  // Zod schemas for possible query params (future extensibility)
  const historicalQuerySchema = z.object({}); // No query params currently
  const summaryQuerySchema = z.object({}); // No query params currently

  // GET /analytics/historical
  server.get('/historical', async (req, reply) => {
    try {
      historicalQuerySchema.parse(req.query);
      // Get block time series (last 24 hours, hourly)
      const now = new Date();
      const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
      const blocks = await prisma.block.findMany({
        where: { time: { gte: oneDayAgo } },
        orderBy: { time: 'asc' },
      });
      const blockTime = {
        x: blocks.map((b: Block) => toDate(b.time).toISOString()),
        y: blocks.map((b: Block, i: number, arr: Block[]) => i === 0 ? 0 : (toDate(b.time).getTime() - toDate(arr[i-1].time).getTime()) / 1000),
      };
      // Get transaction count per block (last 7 days, daily)
      const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      const txBlocks = await prisma.block.findMany({
        where: { time: { gte: sevenDaysAgo } },
        orderBy: { time: 'asc' },
        select: { time: true, transactionCount: true },
      });
      const transactions = {
        x: txBlocks.map((b: { time: Date | number }) => toDate(b.time).toISOString()),
        y: txBlocks.map((b: { transactionCount: number }) => b.transactionCount),
      };
      reply.send({ success: true, data: { blockTime, transactions } as {
        blockTime: { x: string[]; y: number[] },
        transactions: { x: string[]; y: number[] },
      }});
    } catch (err) {
      if (err instanceof z.ZodError) {
        server.log.error({ err }, 'Validation error in /analytics/historical');
        return reply.status(400).send({ success: false, error: 'Invalid query parameters', details: err.errors });
      }
      server.log.error({ err }, 'Error in /analytics/historical');
      reply.status(500).send({ success: false, error: 'Internal server error' });
    }
  });

  // GET /analytics/summary
  server.get('/summary', async (req, res) => {
    try {
      summaryQuerySchema.parse(req.query);
      // Replace with real analytics logic (e.g., query DB, aggregate node stats)
      const { getAnalyticsSummary } = require('../../../blockchain/src/services/analytics');
      const summary = await getAnalyticsSummary();
      res.send({ success: true, data: summary });
    } catch (err) {
      if (err instanceof z.ZodError) {
        return res.status(400).send({ success: false, error: 'Invalid query parameters', details: err.errors });
      }
      res.status(500).send({ success: false, error: 'Failed to fetch analytics summary', details: err instanceof Error ? err.message : err });
    }
  });
} 