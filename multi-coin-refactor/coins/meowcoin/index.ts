// #region MeowCoin Module
/**
 * MeowCoin module implementing the CoinModule interface.
 * Used for registry, onboarding, and API flows.
 * @module MeowCoin
 */
import { CoinModule } from '../../core/types';
import { MEOWCOIN_CONSTANTS } from './constants';
import { getBalance } from './rpc';
import { validateAddress } from './validation';
import { meowcoinConfigSchema } from '../../core/config';

// NOTE: If you see a linter error for configSchema, ensure CoinModule interface in core/types/coin.ts includes configSchema?: any

export const MeowCoin: CoinModule = {
  metadata: { name: 'MeowCoin', symbol: 'MEWC', decimals: 8, logoUrl: '', features: [] },
  rpc: {
    getBalance
  },
  validation: {
    validateAddress
  },
  constants: MEOWCOIN_CONSTANTS,
  configSchema: meowcoinConfigSchema
};

/**
 * Alias for MeowCoin module for registry/test compatibility.
 */
export { MeowCoin as meowcoinModule };
// #endregion 