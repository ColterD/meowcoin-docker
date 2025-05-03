import * as request from 'supertest';
import { buildServer } from '../src/server';

describe('/notifications endpoint', () => {
  let server: any;

  beforeAll(async () => {
    server = await buildServer();
    await server.ready();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should return alerts on success', async () => {
    const mockAlerts = [{ id: '1', message: 'test' }];
    jest.spyOn((server as any).prisma.nodeAlert, 'findMany').mockResolvedValueOnce(mockAlerts);
    const res = await request(server.server).get('/api/notifications');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toEqual(mockAlerts);
  });

  it('should return 500 on DB error', async () => {
    jest.spyOn((server as any).prisma.nodeAlert, 'findMany').mockRejectedValueOnce(new Error('fail'));
    const res = await request(server.server).get('/api/notifications');
    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
    expect(res.body.error).toMatch(/internal server error/i);
  });
}); 