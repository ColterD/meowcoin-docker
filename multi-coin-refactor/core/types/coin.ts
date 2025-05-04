// #region Coin Types
/**
 * Types and interfaces for coin modules.
 * Used by all coin implementations and registry.
 */
export interface CoinMetadata {
  name: string;
  symbol: string;
  decimals: number;
  logoUrl?: string;
  features?: string[];
  [key: string]: unknown;
}

export interface CoinRPC {
  // TODO[roadmap]: Define RPC methods and properties here
  [key: string]: unknown;
}

export interface CoinValidation {
  // TODO[roadmap]: Define validation methods and properties here
  [key: string]: unknown;
}

export interface CoinConstants {
  // TODO[roadmap]: Define constants here
  [key: string]: unknown;
}

export interface CoinModule {
  metadata: CoinMetadata;
  rpc: CoinRPC;
  validation: CoinValidation;
  constants: CoinConstants;
  /**
   * Optional config schema for onboarding/config validation (Zod schema).
   */
  configSchema?: unknown; // TODO[roadmap]: Type as Zod schema if available
}
// TODO[roadmap]: Expand for multi-coin, advanced features, and cross-link to config schemas
// #endregion 