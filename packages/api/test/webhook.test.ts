import * as request from 'supertest';
import { buildServer } from '../src/server';

describe('/webhooks endpoint', () => {
  let server: any;

  beforeAll(async () => {
    server = await buildServer();
    await server.ready();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should log and return success on POST', async () => {
    const logSpy = jest.spyOn(server.log, 'info').mockImplementation(() => {});
    const res = await request(server.server).post('/api/webhooks').send({ event: 'test' });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(logSpy).toHaveBeenCalledWith({ body: { event: 'test' } }, 'Received webhook event');
  });
}); 