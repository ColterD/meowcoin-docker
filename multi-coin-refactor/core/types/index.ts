// #region Coin Types Barrel
/**
 * Barrel export for coin types.
 * Used by all coin modules and registry.
 */
export * from './coin';
// #endregion 

// #region Storage Adapter Interface
export interface StorageAdapter<T> {
  save(item: T): Promise<void>;
  getAll(): Promise<T[]>;
  clear(): Promise<void>;
}
// #endregion 

// #region Types Barrel
// TODO[roadmap]: Expand for advanced onboarding, feedback, and monitoring types
// TODO[roadmap]: Add unified type registry and advanced type features
// #endregion 