import * as request from 'supertest';
import { buildServer } from '../src/server';

describe('/blockchain endpoints', () => {
  let server: any;

  beforeAll(async () => {
    server = await buildServer();
    await server.ready();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should return blockchain info on /info', async () => {
    jest.spyOn((server as any).rpcClient, 'getBlockchainInfo').mockResolvedValueOnce({ chain: 'main' });
    const res = await request(server.server).get('/api/blockchain/info');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.chain).toBe('main');
  });

  it('should return block by hash', async () => {
    jest.spyOn((server as any).rpcClient, 'getBlock').mockResolvedValueOnce({ hash: 'abc' });
    const res = await request(server.server).get('/api/blockchain/block/abc');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.hash).toBe('abc');
  });

  it('should return transaction by txid', async () => {
    jest.spyOn((server as any).rpcClient, 'getRawTransaction').mockResolvedValueOnce({ txid: 'txid' });
    const res = await request(server.server).get('/api/blockchain/transaction/txid');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.txid).toBe('txid');
  });

  it('should return mempool info', async () => {
    jest.spyOn((server as any).rpcClient, 'getMempoolInfo').mockResolvedValueOnce({ loaded: true });
    const res = await request(server.server).get('/api/blockchain/mempool');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.loaded).toBe(true);
  });

  it('should return 500 on RPC error', async () => {
    jest.spyOn((server as any).rpcClient, 'getBlockchainInfo').mockRejectedValueOnce(new Error('fail'));
    const res = await request(server.server).get('/api/blockchain/info');
    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
    expect(res.body.error).toMatch(/internal server error/i);
  });
}); 