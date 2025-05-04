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

// TODO[roadmap]: Add DBOnboardingAdapter for persistent DB-backed storage
// #endregion

// #region Adapter Selection
const ADAPTER = (env && env.ONBOARDING_PERSISTENCE === 'file') ? new FileOnboardingAdapter() : new InMemoryOnboardingAdapter();
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
  await ADAPTER.save(onboardingConfig);
}

export async function getOnboardingConfigs(): Promise<OnboardingConfig[]> {
  return ADAPTER.getAll();
}

export async function clearOnboardingConfigs() {
  await ADAPTER.clear();
}
// #endregion 

// #region Error Handling Standardization
// For every throw new Error, ensure recordMetric is called just before
// ... existing code ...
// #endregion 

// TODO[roadmap]: Expand for advanced onboarding, feedback, and monitoring flows
// TODO[roadmap]: Add DB-backed storage and schema registry
// #endregion 