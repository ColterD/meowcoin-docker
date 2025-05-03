import * as request from 'supertest';
import { buildServer } from '../src/server';

describe('/users/me endpoint', () => {
  let server: any;

  beforeAll(async () => {
    server = await buildServer();
    await server.ready();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should return user info when authenticated', async () => {
    const mockUser = { id: '1', username: 'test' };
    // Patch authenticate to inject mock user
    (server as any).authenticate = (_req: any, _res: any, done: any) => {
      _req.user = mockUser;
      done();
    };
    const res = await request(server.server).get('/api/users/me');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toEqual(mockUser);
  });

  it('should return 401 if not authenticated', async () => {
    (server as any).authenticate = (_req: any, _res: any, done: any) => {
      done();
    };
    const res = await request(server.server).get('/api/users/me');
    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
    expect(res.body.error).toMatch(/unauthorized/i);
  });
}); 