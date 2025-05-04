// #region CoinRegistry Test Suite
/**
 * Tests for the coin registry module.
 * Ensures registration, retrieval, duplicate handling, and unknown coin logic.
 * @group registry
 * TODO[roadmap]: Expand with tests for dynamic coin loading and error flows.
 * TODO[roadmap]: Expand for advanced onboarding, feedback, and monitoring E2E flows (planned; see AI_AGENT_ROADMAP.md for status)
 * TODO[roadmap]: Add DB-backed coin registry and advanced E2E scenarios (planned; see AI_AGENT_ROADMAP.md for status)
 * TODO[roadmap]: Add error case tests for coin registry (planned; see AI_AGENT_ROADMAP.md for status)
 */
// #endregion

import 'jest';
import { coinRegistry } from '../core/registry';
import { meowcoinModule } from '../coins/meowcoin';
import { bitcoinModule } from '../coins/bitcoin';

describe('coinRegistry', () => {
  beforeEach(() => {
    coinRegistry.clear();
  });

  it('registers and retrieves multiple coins', () => {
    coinRegistry.register('meowcoin', meowcoinModule);
    coinRegistry.register('bitcoin', bitcoinModule);
    expect(coinRegistry.get('meowcoin')).toBe(meowcoinModule);
    expect(coinRegistry.get('bitcoin')).toBe(bitcoinModule);
  });

  it('lists all registered coins', () => {
    coinRegistry.register('meowcoin', meowcoinModule);
    coinRegistry.register('bitcoin', bitcoinModule);
    expect(coinRegistry.list()).toEqual(['meowcoin', 'bitcoin']);
  });

  it('throws on duplicate registration', () => {
    coinRegistry.register('meowcoin', meowcoinModule);
    expect(() => coinRegistry.register('meowcoin', meowcoinModule)).toThrow();
  });

  it('returns undefined for unknown coin', () => {
    expect(coinRegistry.get('unknown')).toBeUndefined();
  });
}); 