import * as request from 'supertest';
import { buildServer } from '../src/server';

describe('/network/info endpoint', () => {
  let server: any;

  beforeAll(async () => {
    server = await buildServer();
    await server.ready();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should return network metrics on success', async () => {
    // Mock the rpcClient methods
    const mockMiningInfo = { networkhashps: 123456789 };
    const mockNetworkInfo = { connections: 8 };
    const mockPeerInfo = [
      { inbound: true },
      { inbound: false },
      { inbound: true },
      { inbound: false },
    ];
    jest.spyOn((server as any).rpcClient, 'getMiningInfo').mockResolvedValueOnce(mockMiningInfo);
    jest.spyOn((server as any).rpcClient, 'getNetworkInfo').mockResolvedValueOnce(mockNetworkInfo);
    jest.spyOn((server as any).rpcClient, 'getPeerInfo').mockResolvedValueOnce(mockPeerInfo);

    const res = await request(server.server).get('/api/network/info');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.totalNodes).toBe(8);
    expect(res.body.data.inboundConnections).toBe(2);
    expect(res.body.data.outboundConnections).toBe(2);
  });

  it('should return 500 on RPC error', async () => {
    jest.spyOn((server as any).rpcClient, 'getMiningInfo').mockRejectedValueOnce(new Error('RPC error'));
    const res = await request(server.server).get('/api/network/info');
    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
    expect(res.body.error).toMatch(/internal server error/i);
  });
}); 