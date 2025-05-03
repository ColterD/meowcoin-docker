import * as request from 'supertest';
import { buildServer } from '../src/server';

describe('/health endpoint', () => {
  let server: any;

  beforeAll(async () => {
    server = await buildServer();
    await server.ready();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should return healthy when node is synced', async () => {
    jest.spyOn(server.axios, 'get').mockResolvedValueOnce({
      data: { data: { blocks: 100, headers: 100, initialblockdownload: false } }
    });
    const res = await request(server.server).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('healthy');
    expect(res.body.node.syncProgress).toBe(100);
  });

  it('should return degraded when node is syncing', async () => {
    jest.spyOn(server.axios, 'get').mockResolvedValueOnce({
      data: { data: { blocks: 50, headers: 100, initialblockdownload: true } }
    });
    const res = await request(server.server).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('degraded');
    expect(res.body.node.syncProgress).toBe(50);
  });

  it('should return unhealthy when node is unreachable', async () => {
    jest.spyOn(server.axios, 'get').mockRejectedValueOnce(new Error('Node unreachable'));
    const res = await request(server.server).get('/health');
    expect(res.status).toBe(503);
    expect(res.body.status).toBe('unhealthy');
    expect(res.body.node.message).toMatch(/unreachable/i);
  });
}); 