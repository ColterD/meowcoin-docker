// #region TUI Onboarding Wizard
/**
 * TUI onboarding wizard with config persistence, input validation, and feedback stub.
 * Logs onboarding, feedback, and error events to monitoring/metrics.
 * TODO[roadmap]: Implement real UI, validation, and connect to core/onboarding/configStore. See core/onboarding/configStore.ts, core/validation/, docs/ONBOARDING.md
 */
import { readFileSync, existsSync } from 'fs';
import { recordMetric } from '../../core/monitoring';
import { submitUserFeedback } from '../../core/feedback';
import { coinRegistry } from '../../core/registry';
import { saveOnboardingConfig } from '../../core/onboarding/configStore';
import { OnboardingConfig } from '../../core/onboarding/configStore';
import { AuthUser } from '../../core/auth';
import * as z from 'zod';
const CONFIG_PATH = './onboardingConfig.json';

/**
 * Save onboarding config to file (TUI).
 * @param config - Onboarding config object
 * Supports advanced fields and dynamic schemas.
 * TODO[roadmap]: Add persistent DB-backed storage and advanced onboarding flows.
 */
export async function saveConfigTui(config: unknown) {
  const onboardingConfig = config as OnboardingConfig;
  const coinSymbol = onboardingConfig.coin;
  const coinModule = coinRegistry.get(coinSymbol?.toLowerCase());
  if (!coinModule || !coinModule.configSchema) {
    recordMetric({
      type: 'onboarding',
      data: { error: 'Unknown coin or missing config schema', config },
      timestamp: new Date().toISOString(),
    });
    throw new Error('Unknown coin or missing config schema');
  }
  const schema = coinModule.configSchema as z.ZodTypeAny;
  const result = schema.safeParse(onboardingConfig.config);
  if (!result.success) {
    recordMetric({
      type: 'onboarding',
      data: { error: 'Invalid config', config, details: result.error },
      timestamp: new Date().toISOString(),
    });
    throw new Error('Invalid config');
  }
  await saveOnboardingConfig(onboardingConfig);
  recordMetric({
    type: 'onboarding',
    data: { action: 'save', config },
    timestamp: new Date().toISOString(),
  });
}

/**
 * Load onboarding config from file (TUI).
 * @returns Config object or null
 */
export function loadConfigTui() {
  // TODO[roadmap]: Load config from file. See core/onboarding/configStore.ts, BACKUP_RESTORE.md
  let config = null;
  if (existsSync(CONFIG_PATH)) {
    config = JSON.parse(readFileSync(CONFIG_PATH, 'utf-8'));
  }
  recordMetric({
    type: 'onboarding',
    data: { action: 'load', config },
    timestamp: new Date().toISOString(),
  });
  return config;
}

/**
 * Submit user feedback from TUI onboarding.
 * @param feedback - Feedback string
 * @param user - Optional user object
 */
export function submitFeedbackTui(feedback: string, user?: unknown) {
  const authUser = user as AuthUser | undefined;
  if (authUser && !authUser.id) {
    recordMetric({
      type: 'feedback',
      data: { error: 'Not authenticated', feedback, user },
      timestamp: new Date().toISOString(),
    });
    throw new Error('Not authenticated');
  }
  submitUserFeedback({
    userId: authUser?.id,
    feedback,
    createdAt: new Date().toISOString(),
    context: 'tui',
  });
  console.log('Feedback submitted:', feedback);
}

export {};
// #endregion 

// #region Error Handling Standardization
// For every throw new Error, ensure recordMetric is called just before
// ... existing code ...
// #endregion 