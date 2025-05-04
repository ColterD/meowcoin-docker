// #region Browser Onboarding Wizard
/**
 * Browser onboarding wizard with config persistence, input validation, and feedback stub.
 * Logs onboarding, feedback, and error events to monitoring/metrics.
 * TODO[roadmap]: Implement real UI, validation, and connect to core/onboarding/configStore. See core/onboarding/configStore.ts, core/validation/, docs/ONBOARDING.md
 */
import { recordMetric } from '../../core/monitoring';
import { submitUserFeedback } from '../../core/feedback';
import { coinRegistry } from '../../core/registry';
import { saveOnboardingConfig } from '../../core/onboarding/configStore';
import { OnboardingConfig } from '../../core/onboarding/configStore';
import { AuthUser } from '../../core/auth';
import * as z from 'zod';

/**
 * Save onboarding config to localStorage (browser) and server.
 * @param config - Onboarding config object
 * Supports advanced fields and dynamic schemas.
 * Implements both localStorage persistence and server-side storage.
 */
export async function saveConfigBrowser(config: unknown) {
  const onboardingConfig = config as OnboardingConfig;
  const coinSymbol = onboardingConfig.coin;
  
  // Validate coin exists and has a config schema
  const coinModule = coinRegistry.get(coinSymbol?.toLowerCase());
  if (!coinModule || !coinModule.configSchema) {
    recordMetric({
      type: 'onboarding',
      data: { error: 'Unknown coin or missing config schema', config },
      timestamp: new Date().toISOString(),
    });
    throw new Error('Unknown coin or missing config schema');
  }
  
  // Validate config against coin schema
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
  
  // Save to server via core onboarding service
  await saveOnboardingConfig(onboardingConfig);
  
  // Save to localStorage if in browser environment
  if (typeof window !== 'undefined' && window.localStorage) {
    try {
      localStorage.setItem('onboardingConfig', JSON.stringify(onboardingConfig));
    } catch (error: any) {
      console.error('Error saving to localStorage:', error);
      recordMetric({
        type: 'error',
        data: { action: 'save', error: error?.message || String(error) },
        timestamp: new Date().toISOString(),
      });
      // Don't throw here - we already saved to server
    }
  }
  
  // Record metric for successful save
  recordMetric({
    type: 'onboarding',
    data: { action: 'save', config },
    timestamp: new Date().toISOString(),
  });
}

/**
 * Load onboarding config from localStorage (browser).
 * @returns Config object or null
 */
export function loadConfigBrowser() {
  let config = null;
  
  // In browser environment
  if (typeof window !== 'undefined' && window.localStorage) {
    try {
      const data = localStorage.getItem('onboardingConfig');
      if (data) {
        config = JSON.parse(data);
      }
    } catch (error: any) {
      console.error('Error loading config from localStorage:', error);
      recordMetric({
        type: 'error',
        data: { action: 'load', error: error?.message || String(error) },
        timestamp: new Date().toISOString(),
      });
    }
  }
  
  recordMetric({
    type: 'onboarding',
    data: { action: 'load', config },
    timestamp: new Date().toISOString(),
  });
  
  return config;
}

/**
 * Submit user feedback from browser onboarding.
 * @param feedback - Feedback string
 * @param user - Optional user object
 */
export function submitFeedbackBrowser(feedback: string, user?: unknown) {
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
    context: 'browser',
  });
  console.log('Feedback submitted:', feedback);
}

export {};
// #endregion 

// #region Error Handling Standardization
// For every throw new Error, ensure recordMetric is called just before
// ... existing code ...
// #endregion 