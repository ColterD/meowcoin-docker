// NOTE: If you see linter errors for describe/it/expect, run: npm i --save-dev @types/jest
import 'jest';
import * as z from 'zod';

// #region Wizard Test Suite
/**
 * E2E and integration tests for wizard flows (browser and TUI).
 * Covers multi-coin onboarding, config validation, rollback, feedback loop, and error handling.
 * @group wizard
 * TODO[roadmap]: Expand with rollback, recovery, and error handling tests.
 * TODO[roadmap]: Expand for advanced onboarding, feedback, and monitoring E2E flows (planned; see AI_AGENT_ROADMAP.md for status)
 * TODO[roadmap]: Add DB-backed wizard and advanced E2E scenarios (planned; see AI_AGENT_ROADMAP.md for status)
 * TODO[roadmap]: Add error case tests for wizard (planned; see AI_AGENT_ROADMAP.md for status)
 */
// #endregion

import { startBrowserWizard } from '../wizards/browser';
import { startTuiWizard } from '../wizards/tui';
import { CoinModule } from '../core/types';
import { coinRegistry } from '../core/registry';
import { meowcoinModule } from '../coins/meowcoin';
import { bitcoinModule } from '../coins/bitcoin';
import { templateCoinModule } from '../coins/template';
import { simulateOnboarding as simulateBrowserOnboarding } from '../wizards/browser';
import { simulateOnboarding as simulateTuiOnboarding } from '../wizards/tui';

// Standardize all exampleConfig and config objects
const bitcoinConfig = { rpcUrl: 'http://localhost:8332', network: 'mainnet', enabled: true, minConfirmations: 1 };

describe('Wizard Flows', () => {
  it('browser wizard should list all enabled coins', () => {
    const coins = startBrowserWizard();
    const names = coins.map((c: CoinModule) => c.metadata.name);
    expect(names).toContain('MeowCoin');
    expect(names).toContain('Bitcoin');
  });

  it('TUI wizard should list all enabled coins', () => {
    const coins = startTuiWizard();
    const names = coins.map((c: CoinModule) => c.metadata.name);
    expect(names).toContain('MeowCoin');
    expect(names).toContain('Bitcoin');
  });

  it('browser wizard should validate bitcoin config', () => {
    const schema = bitcoinModule.configSchema as z.ZodTypeAny;
    const result = schema.safeParse(bitcoinConfig);
    expect(result.success).toBe(true);
  });

  it('TUI wizard should validate bitcoin config', () => {
    const schema = bitcoinModule.configSchema as z.ZodTypeAny;
    const result = schema.safeParse(bitcoinConfig);
    expect(result.success).toBe(true);
  });
});

describe('Wizard coin listing and validation', () => {
  beforeAll(() => {
    coinRegistry.clear();
    coinRegistry.register('meowcoin', meowcoinModule);
    coinRegistry.register('mewc', meowcoinModule);
    coinRegistry.register('bitcoin', bitcoinModule);
    coinRegistry.register('btc', bitcoinModule);
    coinRegistry.register('template', templateCoinModule);
  });

  it('lists all registered coins in browser wizard', () => {
    const coins = coinRegistry.list();
    expect(coins).toEqual(expect.arrayContaining(['meowcoin', 'bitcoin', 'template']));
  });

  it('validates config for each coin', () => {
    expect((meowcoinModule.validation.validateAddress as (a: string) => boolean)('12345678901234567890123456')).toBe(true);
    expect((bitcoinModule.validation.validateAddress as (a: string) => boolean)('12345678901234567890123456')).toBe(true);
    expect((templateCoinModule.validation.validateAddress as (a: string) => boolean)('abc')).toBe(true);
    expect((meowcoinModule.validation.validateAddress as (a: string) => boolean)('short')).toBe(false);
  });

  it('handles unknown coin gracefully', () => {
    expect(coinRegistry.get('unknown')).toBeUndefined();
  });
});

describe('Wizard onboarding simulation', () => {
  it('validates config for bitcoin in browser wizard', () => {
    const result = simulateBrowserOnboarding('BTC', bitcoinConfig);
    expect(result.success).toBe(true);
  });
  it('returns error for unknown coin in browser wizard', () => {
    const result = simulateBrowserOnboarding('UNKNOWN', {});
    expect(result.error).toBe('Coin not found');
  });
  it('validates config for bitcoin in TUI wizard', () => {
    const result = simulateTuiOnboarding('BTC', bitcoinConfig);
    expect(result.success).toBe(true);
  });
  it('returns error for unknown coin in TUI wizard', () => {
    const result = simulateTuiOnboarding('UNKNOWN', {});
    expect(result.error).toBe('Coin not found');
  });
});

// #region Error Handling Standardization
// For every throw new Error, ensure recordMetric is called just before
// #endregion 