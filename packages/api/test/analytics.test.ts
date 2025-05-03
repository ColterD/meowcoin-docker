import * as request from 'supertest';
import { buildServer } from '../src/server';

describe('/analytics/historical endpoint', () => {
  let server: any;

  beforeAll(async () => {
    server = await buildServer();
    await server.ready();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should return blockTime and transactions on success', async () => {
    const mockBlocks = [
      { time: new Date(Date.now() - 1000 * 60 * 60), transactionCount: 5 },
      { time: new Date(), transactionCount: 10 },
    ];
    jest.spyOn((server as any).prisma.block, 'findMany').mockImplementation(({ where, select }: any) => {
      if (select) return Promise.resolve(mockBlocks);
      return Promise.resolve(mockBlocks);
    });
    const res = await request(server.server).get('/api/analytics/historical');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.blockTime).toBeDefined();
    expect(res.body.data.transactions).toBeDefined();
  });

  it('should return 500 on DB error', async () => {
    jest.spyOn((server as any).prisma.block, 'findMany').mockRejectedValueOnce(new Error('DB error'));
    const res = await request(server.server).get('/api/analytics/historical');
    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
    expect(res.body.error).toMatch(/internal server error/i);
  });
}); 