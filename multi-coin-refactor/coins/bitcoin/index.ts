// #region Bitcoin Module
/**
 * Bitcoin module implementing the CoinModule interface.
 * Used for registry, onboarding, and API flows.
 * @module Bitcoin
 */
import { CoinModule } from '../../core/types';
import { BITCOIN_CONSTANTS } from './constants';
import { getBalance } from './rpc';
import { validateAddress } from './validation';
import { bitcoinConfigSchema } from '../../core/config';

// NOTE: If you see a linter error for configSchema, ensure CoinModule interface in core/types/coin.ts includes configSchema?: any

export const Bitcoin: CoinModule = {
  metadata: { name: 'Bitcoin', symbol: 'BTC', decimals: 8, logoUrl: '', features: [] },
  rpc: {
    getBalance
  },
  validation: {
    validateAddress
  },
  constants: BITCOIN_CONSTANTS,
  configSchema: bitcoinConfigSchema,
  // TODO[roadmap]: Add advanced onboarding fields to configSchema as needed
};

/**
 * Alias for Bitcoin module for registry/test compatibility.
 */
export { Bitcoin as bitcoinModule };
// #endregion

// #region Bitcoin Coin Module
// TODO[roadmap]: Expand for advanced onboarding, config, and monitoring features
// #endregion 