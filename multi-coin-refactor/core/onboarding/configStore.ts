// #region Onboarding Config Store
/**
 * Interface for onboarding state/config persistence.
 * Supports in-memory, file, and DB-backed storage (feature-flagged).
 * Logs onboarding config events to monitoring/metrics.
 * Cross-link to feedback and monitoring modules.
 * TODO[roadmap]: Add persistent DB-backed storage and advanced onboarding fields.
 */
import { recordMetric } from '../monitoring';
import { StorageAdapter } from '../types';
import { onboardingSchema } from '../validation';
// Use dynamic import for 'fs' to avoid linter errors in non-Node environments
let writeFileSync: ((...args: unknown[]) => void) | undefined, readFileSync: ((...args: unknown[]) => string) | undefined, existsSync: ((...args: unknown[]) => boolean) | undefined;
const hasRequire = typeof (globalThis as unknown as { require?: NodeRequire }).require !== 'undefined';
try {
  if (hasRequire) {
    ({ writeFileSync, readFileSync, existsSync } = (globalThis as unknown as { require: NodeRequire }).require('fs'));
  } else {
    writeFileSync = readFileSync = existsSync = () => { throw new Error('fs not available'); };
  }
} catch (e) {
  writeFileSync = readFileSync = existsSync = () => { throw new Error('fs not available'); };
}
const getProcessCwd = () => (typeof (globalThis as unknown as { process?: { cwd?: () => string } }).process !== 'undefined' && (globalThis as unknown as { process?: { cwd?: () => string } }).process?.cwd ? (globalThis as unknown as { process: { cwd: () => string } }).process.cwd() : '.');
const CONFIG_PATH = (typeof (globalThis as unknown as { __dirname?: string }).__dirname !== 'undefined' ? (globalThis as unknown as { __dirname: string }).__dirname : getProcessCwd()) + '/onboarding-configs.json';
const env = (typeof (globalThis as any).process !== 'undefined' && typeof (globalThis as any).process.env !== 'undefined')
  ? (globalThis as any).process.env as { ONBOARDING_PERSISTENCE?: string }
  : undefined;

export interface OnboardingConfig {
  coin: string;
  config: Record<string, unknown>;
  createdAt: string;
  // Advanced onboarding fields
  advanced?: Record<string, unknown>;
}

// #region Storage Adapters
class InMemoryOnboardingAdapter implements StorageAdapter<OnboardingConfig> {
  private items: OnboardingConfig[] = [];
  async save(item: OnboardingConfig) { this.items.push(item); }
  async getAll() { return this.items; }
  async clear() { this.items = []; }
}

class FileOnboardingAdapter implements StorageAdapter<OnboardingConfig> {
  async save(item: OnboardingConfig) {
    const items = await this.getAll();
    items.push(item);
    if (writeFileSync) writeFileSync(CONFIG_PATH, JSON.stringify(items, null, 2));
  }
  async getAll() {
    if (existsSync && existsSync(CONFIG_PATH)) {
      try {
        return readFileSync ? JSON.parse(readFileSync(CONFIG_PATH, 'utf-8')) : [];
      } catch (e) {
        return [];
      }
    }
    return [];
  }
  async clear() { if (writeFileSync) writeFileSync(CONFIG_PATH, '[]'); }
}

// Import the DB adapter (dynamically to avoid issues in browser environments)
let DBOnboardingAdapter: any;
try {
  ({ DBOnboardingAdapter } = require('./db-adapter'));
} catch (e) {
  // DB adapter not available, will fall back to other adapters
}
// #endregion

// #region Adapter Selection
// Create a function to get the adapter to ensure we always use the current environment variable value
function getAdapter(): StorageAdapter<OnboardingConfig> {
  const persistenceType = env?.ONBOARDING_PERSISTENCE;
  
  if (persistenceType === 'file') {
    return new FileOnboardingAdapter();
  } else if (persistenceType === 'db') {
    if (!DBOnboardingAdapter) {
      console.warn('DB adapter requested but not available, falling back to in-memory');
      return new InMemoryOnboardingAdapter();
    }
    try {
      return new DBOnboardingAdapter();
    } catch (error) {
      console.error('Failed to initialize DB adapter:', error);
      console.warn('Falling back to in-memory adapter');
      return new InMemoryOnboardingAdapter();
    }
  } else {
    // Default to in-memory
    return new InMemoryOnboardingAdapter();
  }
}
// #endregion

export async function saveOnboardingConfig(onboardingConfig: OnboardingConfig) {
  // Unified validation using shared schema
  const result = onboardingSchema.safeParse(onboardingConfig);
  if (!result.success) throw new Error('Invalid onboarding config: ' + JSON.stringify(result.error));
  recordMetric({
    type: 'onboarding',
    data: onboardingConfig,
    timestamp: onboardingConfig.createdAt,
  });
  await getAdapter().save(onboardingConfig);
}

export async function getOnboardingConfigs(): Promise<OnboardingConfig[]> {
  return getAdapter().getAll();
}

export async function clearOnboardingConfigs() {
  await getAdapter().clear();
}

/**
 * Get an onboarding configuration by coin.
 * Only works with DB adapter that implements getByCoin method.
 * @param coin - The coin symbol
 * @returns The onboarding configuration or null if not found
 */
export async function getOnboardingConfigByCoin(coin: string): Promise<OnboardingConfig | null> {
  const adapter = getAdapter();
  
  // Check if the adapter has a getByCoin method
  if ('getByCoin' in adapter && typeof (adapter as any).getByCoin === 'function') {
    return (adapter as any).getByCoin(coin);
  }
  
  // Fall back to filtering all configs
  const configs = await adapter.getAll();
  return configs.find(config => config.coin === coin) || null;
}
// #endregion 

// #region Error Handling Standardization
// For every throw new Error, ensure recordMetric is called just before
// ... existing code ...
// #endregion 

// TODO[roadmap]: Expand for advanced onboarding, feedback, and monitoring flows
// TODO[roadmap]: Add DB-backed storage and schema registry
// #endregion 