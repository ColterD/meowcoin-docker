// #region Browser Wizard Entrypoint
/**
 * Browser wizard entrypoint for onboarding and config flows.
 * Exposes coin listing, onboarding simulation, and config validation for UI/E2E.
 * TODO[roadmap]: Integrate with real UI and onboarding flows.
 */
// Placeholder for browser-based setup/config wizard
import { getEnabledCoins, coinRegistry } from '../../core/registry';
import { CoinModule } from '../../core/types';
import { onboardingSchema } from '../../core/validation';
import * as z from 'zod';

/**
 * Returns metadata for all enabled coins for the browser wizard UI.
 */
export function getAvailableCoinsForBrowserWizard() {
  return getEnabledCoins().map((coin: CoinModule) => coin.metadata);
}

/**
 * Starts the browser-based onboarding wizard (placeholder for UI integration).
 * Logs available coins and validates example config for Bitcoin.
 */
export function startBrowserWizard() {
  const coins = getEnabledCoins();
  // Placeholder: In a real UI, prompt user to select a coin
  console.log('Available coins:', coins.map(c => c.metadata.name).join(', '));
  // Placeholder: Simulate user selects Bitcoin
  const selectedCoin = coins.find(c => c.metadata.symbol === 'BTC');
  if (selectedCoin) {
    // Use per-coin config schema for validation (unified)
    const coinModule = coinRegistry.get(selectedCoin.metadata.symbol.toLowerCase());
    if (!coinModule || !coinModule.configSchema) {
      console.error('Unknown coin or missing config schema');
      return coins;
    }
    // Type assertion for Zod schema
    const schema = coinModule.configSchema as z.ZodTypeAny;
    const exampleConfig = { rpcUrl: 'http://localhost:8332', network: 'mainnet', enabled: true, minConfirmations: 1 };
    // Validate config using unified schema
    const configResult = schema.safeParse(exampleConfig);
    console.log('Bitcoin config validation result:', configResult.success);
    // Validate onboarding object using onboardingSchema
    const onboardingObj = { coin: 'BTC', config: exampleConfig, createdAt: new Date().toISOString() };
    const onboardingResult = onboardingSchema.safeParse(onboardingObj);
    console.log('Onboarding validation result:', onboardingResult.success);
  }
  return coins;
}

export const browserWizard = {};

/**
 * Simulates onboarding for a given coin symbol and config.
 * Returns the result of config schema validation or an error if coin not found.
 * Used for E2E and onboarding test automation.
 * @param coinSymbol - The symbol of the coin (e.g., 'BTC', 'MEWC')
 * @param config - The config object to validate
 */
export function simulateOnboarding(coinSymbol: string, config: unknown) {
  const coinModule = coinRegistry.get(coinSymbol?.toLowerCase());
  if (!coinModule) return { error: 'Coin not found' };
  if (!coinModule.configSchema) return { error: 'Missing config schema' };
  // Type assertion for Zod schema
  const schema = coinModule.configSchema as z.ZodTypeAny;
  // Validate config using unified schema
  const configResult = schema.safeParse(config);
  if (!configResult.success) return { error: 'Invalid config', details: configResult.error };
  // Validate onboarding object using onboardingSchema
  const onboardingObj = { coin: coinSymbol, config, createdAt: new Date().toISOString() };
  const onboardingResult = onboardingSchema.safeParse(onboardingObj);
  if (!onboardingResult.success) return { error: 'Invalid onboarding', details: onboardingResult.error };
  return { success: true };
}

// Placeholder for E2E test integration
// Future: Integrate with Cypress or Playwright for full onboarding E2E 
// #endregion 

// #region Browser Wizard
// TODO[roadmap]: Expand for advanced onboarding, feedback, and monitoring flows
// #endregion 