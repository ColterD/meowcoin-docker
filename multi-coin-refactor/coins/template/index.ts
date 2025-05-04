// #region TemplateCoin Module
/**
 * TemplateCoin module implementing the CoinModule interface.
 * Used as a starting point for new coins, registry, onboarding, and API flows.
 * @module TemplateCoin
 */
import { CoinModule } from '../../core/types';
import { TEMPLATE_COIN_CONSTANTS } from './constants';
import { getBalance } from './rpc';
import { validateAddress } from './validation';
import { templateCoinConfigSchema } from '../../core/config';

// NOTE: If you see a linter error for configSchema, ensure CoinModule interface in core/types/coin.ts includes configSchema?: any

export const TemplateCoin: CoinModule = {
  metadata: { name: 'TemplateCoin', symbol: 'TCOIN', decimals: 8, logoUrl: '', features: [] },
  rpc: {
    getBalance
  },
  validation: {
    validateAddress
  },
  constants: TEMPLATE_COIN_CONSTANTS,
  configSchema: templateCoinConfigSchema
};

/**
 * Alias for TemplateCoin module for registry/test compatibility.
 */
export { TemplateCoin as templateCoinModule };
// TODO[roadmap]: Add advanced onboarding fields to configSchema as needed
// TODO[roadmap]: Expand for advanced onboarding, config, and monitoring features
// #endregion 