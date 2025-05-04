// #region Config Schemas
/**
 * Shared config schemas for all coins.
 * Used by onboarding, validation, and API modules.
 * TODO[roadmap]: Add schemas for all supported coins and advanced onboarding fields.
 */
import * as z from 'zod';

export const coinConfigSchema = z.object({
  rpcUrl: z.string().url(),
  network: z.string(),
  enabled: z.boolean().default(true),
  // Advanced: allow custom fields for extensibility
  custom: z.record(z.any()).optional(),
});

export const bitcoinConfigSchema = z.object({
  rpcUrl: z.string().url(),
  network: z.enum(['mainnet', 'testnet', 'regtest']),
  enabled: z.boolean().default(true),
  minConfirmations: z.number().int().min(0).default(1),
  multiSig: z.boolean().default(false),
  feeRate: z.number().min(0).optional(),
  custom: z.record(z.any()).optional(),
});

export const meowcoinConfigSchema = z.object({
  rpcUrl: z.string().url(),
  network: z.string(),
  enabled: z.boolean().default(true),
  advancedOption: z.string().optional(),
  custom: z.record(z.any()).optional(),
});

export const templateCoinConfigSchema = z.object({
  rpcUrl: z.string().url(),
  network: z.string(),
  enabled: z.boolean().default(true),
  custom: z.record(z.any()).optional(),
});

export const configSchemas = {
  coin: coinConfigSchema,
  bitcoin: bitcoinConfigSchema,
  meowcoin: meowcoinConfigSchema,
  template: templateCoinConfigSchema,
};
// TODO[roadmap]: Expand for advanced onboarding, feedback, and config flows
// TODO[roadmap]: Add schema registry and unified config
// #endregion 