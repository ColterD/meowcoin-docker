// #region CoinModule Interface Compliance Tests
/**
 * Tests for CoinModule interface compliance and per-coin module logic.
 * Ensures all modules conform to the interface and have working RPC/validation methods.
 * @group coin
 * TODO[roadmap]: Expand with negative/edge case tests and new coin templates.
 * TODO[roadmap]: Expand for advanced onboarding, feedback, and monitoring E2E flows (planned; see AI_AGENT_ROADMAP.md for status)
 * TODO[roadmap]: Add DB-backed coin module and advanced E2E scenarios (planned; see AI_AGENT_ROADMAP.md for status)
 * TODO[roadmap]: Add error case tests for coin module (planned; see AI_AGENT_ROADMAP.md for status)
 */
// #endregion

import 'jest';
// @jest-environment node
import { MeowCoin } from '../coins/meowcoin';
import { Bitcoin } from '../coins/bitcoin';
import { meowcoinModule } from '../coins/meowcoin';
import { bitcoinModule } from '../coins/bitcoin';
import { templateCoinModule } from '../coins/template';

describe('CoinModule interface compliance', () => {
  const modules = [meowcoinModule, bitcoinModule, templateCoinModule];

  it('has required fields', () => {
    for (const mod of modules) {
      expect(mod).toHaveProperty('metadata');
      expect(mod).toHaveProperty('rpc');
      expect(mod).toHaveProperty('validation');
      expect(mod).toHaveProperty('constants');
    }
  });

  it('rpc.getBalance returns a Promise<number>', async () => {
    for (const mod of modules) {
      const getBalance = mod.rpc.getBalance as () => Promise<number>;
      const result = await getBalance();
      expect(typeof result).toBe('number');
    }
  });

  it('validation.validateAddress returns boolean', () => {
    for (const mod of modules) {
      const validateAddress = mod.validation.validateAddress as (address: string) => boolean;
      const result = validateAddress('dummy');
      expect(typeof result).toBe('boolean');
    }
  });

  it('MeowCoin should have working getBalance and validateAddress methods', async () => {
    const address = 'M1234567890123456789012345678901';
    const validateMeow = MeowCoin.validation.validateAddress as (address: string) => boolean;
    const getMeowBalance = MeowCoin.rpc.getBalance as () => Promise<number>;
    expect(typeof validateMeow).toBe('function');
    expect(validateMeow(address)).toBe(true);
    const balance = await getMeowBalance();
    expect(typeof balance).toBe('number');
  });

  it('Bitcoin should have working getBalance and validateAddress methods', async () => {
    const address = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';
    const validateBtc = Bitcoin.validation.validateAddress as (address: string) => boolean;
    const getBtcBalance = Bitcoin.rpc.getBalance as () => Promise<number>;
    expect(typeof validateBtc).toBe('function');
    expect(validateBtc(address)).toBe(true);
    const balance = await getBtcBalance();
    expect(typeof balance).toBe('number');
  });
}); 