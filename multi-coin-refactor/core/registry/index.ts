// #region Coin Registry
/**
 * CoinRegistry singleton for dynamic coin module registration and lookup.
 * Used by onboarding, API, and wizard modules.
 * TODO[roadmap]: Support dynamic loading and config-driven enable/disable.
 */
import { CoinModule } from '../types';

class CoinRegistry {
  private coins: Record<string, CoinModule> = {};

  register(name: string, module: CoinModule) {
    if (this.coins[name]) throw new Error(`Coin '${name}' already registered`);
    this.coins[name] = module;
  }

  get(name: string): CoinModule | undefined {
    return this.coins[name];
  }

  list(): string[] {
    return Object.keys(this.coins);
  }

  clear() {
    this.coins = {};
  }
}

export const coinRegistry = new CoinRegistry();

// For legacy static usage
import { MeowCoin } from '../../coins/meowcoin';
import { Bitcoin } from '../../coins/bitcoin';

export function getEnabledCoins(): CoinModule[] {
  // TODO[roadmap]: Register dynamically from config
  if (!coinRegistry.get('meowcoin')) coinRegistry.register('meowcoin', MeowCoin);
  if (!coinRegistry.get('mewc')) coinRegistry.register('mewc', MeowCoin);
  if (!coinRegistry.get('bitcoin')) coinRegistry.register('bitcoin', Bitcoin);
  if (!coinRegistry.get('btc')) coinRegistry.register('btc', Bitcoin);
  return [MeowCoin, Bitcoin];
}
// #endregion 

// #region Error Handling Standardization
// For every throw new Error, ensure recordMetric is called just before
// ... existing code ...
// #endregion 

// #region Registry Module
// TODO[roadmap]: Expand for advanced onboarding, feedback, and monitoring registry flows
// TODO[roadmap]: Add dynamic coin loading and registry schema
// #endregion 