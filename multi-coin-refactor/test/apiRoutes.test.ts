// #region ApiRoutes Test Suite
/**
 * Tests for API route logic, including multi-coin support and validation.
 * Ensures correct status codes, error handling, and coin module integration.
 * @group api
 * TODO[roadmap]: Expand with tests for new endpoints, error flows, and rollback.
 * TODO[roadmap]: Expand for advanced onboarding, feedback, and monitoring E2E flows (planned; see AI_AGENT_ROADMAP.md for status)
 * TODO[roadmap]: Add DB-backed API routes and advanced E2E scenarios (planned; see AI_AGENT_ROADMAP.md for status)
 * TODO[roadmap]: Add error case tests for API routes (planned; see AI_AGENT_ROADMAP.md for status)
 */
// #endregion

import 'jest';

import { getApiRoutes } from '../api/routes';
import { coinRegistry } from '../core/registry';
import { meowcoinModule } from '../coins/meowcoin';
import { bitcoinModule } from '../coins/bitcoin';

describe('API Routes', () => {
  it('should return 400 for invalid MeowCoin address', async () => {
    const routes = getApiRoutes();
    const meowRoute = routes.find((r: unknown) => (r as { path: string }).path.includes('mewc'));
    if (!meowRoute) throw new Error('meowRoute is undefined');
    const res = await meowRoute.handler({ query: { address: 'short' } });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Invalid address');
  });

  it('should return 200 and a balance for a valid MeowCoin address', async () => {
    const routes = getApiRoutes();
    const meowRoute = routes.find((r: unknown) => (r as { path: string }).path.includes('mewc'));
    if (!meowRoute) throw new Error('meowRoute is undefined');
    const res = await meowRoute.handler({ query: { address: 'M1234567890123456789012345678901' } });
    expect(res.status).toBe(200);
    expect(typeof res.body.balance).toBe('number');
  });

  it('should return 400 for invalid Bitcoin address', async () => {
    const routes = getApiRoutes();
    const btcRoute = routes.find((r: unknown) => (r as { path: string }).path.includes('btc'));
    if (!btcRoute) throw new Error('btcRoute is undefined');
    const res = await btcRoute.handler({ query: { address: 'short' } });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Invalid address');
  });

  it('should return 200 and a balance for a valid Bitcoin address', async () => {
    const routes = getApiRoutes();
    const btcRoute = routes.find((r: unknown) => (r as { path: string }).path.includes('btc'));
    if (!btcRoute) throw new Error('btcRoute is undefined');
    const res = await btcRoute.handler({ query: { address: '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa' } });
    expect(res.status).toBe(200);
    expect(typeof res.body.balance).toBe('number');
  });
});

describe('API routes multi-coin', () => {
  beforeAll(() => {
    coinRegistry.clear();
    coinRegistry.register('meowcoin', meowcoinModule);
    coinRegistry.register('mewc', meowcoinModule);
    coinRegistry.register('bitcoin', bitcoinModule);
    coinRegistry.register('btc', bitcoinModule);
  });

  it('returns correct module for meowcoin', () => {
    const mod = coinRegistry.get('meowcoin');
    expect(mod).toBe(meowcoinModule);
    expect(mod?.metadata.symbol).toBe('MEWC');
  });

  it('returns correct module for bitcoin', () => {
    const mod = coinRegistry.get('bitcoin');
    expect(mod).toBe(bitcoinModule);
    expect(mod?.metadata.symbol).toBe('BTC');
  });

  it('returns undefined for unknown coin', () => {
    expect(coinRegistry.get('unknown')).toBeUndefined();
  });

  it('validates address using correct logic', () => {
    const isValidMeow = (meowcoinModule.validation.validateAddress as (address: string) => boolean);
    const isValidBtc = (bitcoinModule.validation.validateAddress as (address: string) => boolean);
    expect(isValidMeow('12345678901234567890123456')).toBe(true);
    expect(isValidBtc('12345678901234567890123456')).toBe(true);
    expect(isValidMeow('short')).toBe(false);
    expect(isValidBtc('short')).toBe(false);
  });
}); 