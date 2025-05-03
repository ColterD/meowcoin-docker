/* eslint-env jest */
process.env.jwtSecret = 'test_jwt_secret';
process.env.apiKey = 'test_api_key';
process.env.DATABASE_URL = 'file:./test.sqlite';
import * as request from 'supertest';
import { testRpcClient } from '../src/routes/network';
import { buildServer } from '../src/server';
// ... existing code ... 