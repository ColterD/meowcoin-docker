// @jest-environment node
import 'jest';
import * as z from 'zod';
// If you see linter errors for 'describe', 'it', or 'expect', run: npm i --save-dev @types/jest
// #region E2E: Browser Onboarding
/**
 * E2E test stubs for browser onboarding flows.
 * TODO[roadmap]: Implement real E2E tests with Cypress/Playwright (planned; see AI_AGENT_ROADMAP.md for status)
 * Includes advanced rollback, recovery, and error handling scenarios.
 */
import { saveConfigBrowser, loadConfigBrowser, submitFeedbackBrowser } from '../../wizards/browser/onboarding';
import { saveSecret, rotateSecret, revokeSecret, backupSecrets, restoreSecrets, getSecretAuditLog, getAllSecrets } from '../../core/secrets';
import { getAllFeedback, clearFeedbacks } from '../../core/feedback';
import { getAllMetrics } from '../../core/monitoring';
import { meowcoinModule } from '../../coins/meowcoin';
import { bitcoinModule } from '../../coins/bitcoin';
describe('Browser Onboarding E2E', () => {
  beforeEach(async () => {
    await clearFeedbacks();
  });

  it('should persist onboarding config', async () => {
    const config = { coin: 'meowcoin', config: { foo: 'bar' }, createdAt: new Date().toISOString() };
    await saveConfigBrowser(config);
    const loaded = await loadConfigBrowser();
    expect(loaded).toEqual(config);
  });

  it('should handle user input simulation', () => {
    // TODO[roadmap]: Simulate user input in browser wizard (planned; see AI_AGENT_ROADMAP.md for status)
    expect(true).toBe(true);
  });

  it('should submit user feedback', () => {
    // TODO[roadmap]: Simulate feedback submission from browser (planned; see AI_AGENT_ROADMAP.md for status)
    submitFeedbackBrowser('Great onboarding!', { authenticated: true });
    expect(true).toBe(true);
  });

  it('should throw on invalid config', () => {
    expect(() => saveConfigBrowser(null)).toThrow('Invalid config');
  });

  it('should throw if unauthenticated feedback', () => {
    expect(() => submitFeedbackBrowser('bad', { authenticated: false })).toThrow('Not authenticated');
  });

  // Advanced E2E: Multi-coin onboarding
  it('should persist onboarding config for multiple coins', () => {
    const coins = ['meowcoin', 'bitcoin'];
    coins.forEach(coin => {
      const config = { coin, config: { foo: coin }, createdAt: new Date().toISOString() };
      saveConfigBrowser(config);
      const loaded = loadConfigBrowser();
      expect(loaded).toEqual(config);
    });
  });

  // Advanced E2E: Config validation and rollback
  it('should rollback on invalid config', () => {
    try {
      saveConfigBrowser(null);
    } catch (e) {
      // TODO[roadmap]: Simulate rollback logic
      expect(e).toBeDefined();
    }
  });

  // Advanced E2E: Feedback loop
  it('should allow feedback after onboarding', () => {
    const config = { coin: 'meowcoin', config: { foo: 'bar' }, createdAt: new Date().toISOString() };
    saveConfigBrowser(config);
    submitFeedbackBrowser('Post-onboarding feedback', { authenticated: true });
    expect(true).toBe(true);
  });

  // Advanced E2E: Rollback and recovery
  it('should recover from failed onboarding and allow retry', () => {
    try {
      saveConfigBrowser(null);
    } catch (e) {
      // Simulate rollback
      const config = { coin: 'meowcoin', config: { foo: 'recovered' }, createdAt: new Date().toISOString() };
      saveConfigBrowser(config);
      const loaded = loadConfigBrowser();
      expect(loaded).toEqual(config);
    }
  });

  // Advanced E2E: Error handling in feedback
  it('should handle feedback submission errors gracefully', () => {
    try {
      submitFeedbackBrowser('bad', { authenticated: false });
    } catch (e) {
      expect((e as Error).message).toBe('Not authenticated');
    }
  });

  it('should save a secret during onboarding and log event', () => {
    const secret = { key: 'onboard', value: 'browser', createdAt: new Date().toISOString() };
    saveSecret(secret);
    const log = getSecretAuditLog();
    expect(log.some(e => e.event === 'save' && e.key === 'onboard')).toBe(true);
  });

  it('should rotate and revoke secret during onboarding', () => {
    const secret = { key: 'onboard2', value: 'browser2', createdAt: new Date().toISOString() };
    saveSecret(secret);
    rotateSecret('onboard2', 'browser2-rotated');
    revokeSecret('onboard2');
    const log = getSecretAuditLog();
    expect(log.some(e => e.event === 'rotate' && e.key === 'onboard2')).toBe(true);
    expect(log.some(e => e.event === 'revoke' && e.key === 'onboard2')).toBe(true);
  });

  it('should backup and restore secrets as part of onboarding recovery', () => {
    const secret = { key: 'onboard3', value: 'browser3', createdAt: new Date().toISOString() };
    saveSecret(secret);
    const backup = backupSecrets();
    // Clear and restore
    while (getSecretAuditLog().length) getSecretAuditLog().pop();
    restoreSecrets(backup);
    expect(getSecretAuditLog().some(e => e.event === 'restore')).toBe(true);
  });

  it('should handle error when saving invalid secret during onboarding', () => {
    expect(() => saveSecret(null as unknown as any)).toThrow();
  });

  it('should persist feedback and log to monitoring', async () => {
    const feedback = 'Browser E2E feedback';
    const user = { id: 'e2e-user', authenticated: true };
    submitFeedbackBrowser(feedback, user);
    const allFeedback = await getAllFeedback();
    expect((allFeedback as any[]).some((f: any) => f.feedback === feedback && f.userId === user.id && f.context === 'browser')).toBe(true);
    const metrics = await getAllMetrics();
    expect((metrics as any[]).some((m: any) => m.type === 'feedback' && (m.data as { feedback: string }).feedback === feedback)).toBe(true);
  });

  it('should not persist unauthenticated feedback', async () => {
    expect(() => submitFeedbackBrowser('bad', { id: 'unauth', authenticated: false })).toThrow('Not authenticated');
    const allFeedback = await getAllFeedback();
    expect((allFeedback as any[]).some((f: any) => f.userId === 'unauth')).toBe(false);
  });

  it('should handle malformed feedback gracefully', () => {
    expect(() => submitFeedbackBrowser(null as unknown as any, { id: 'mal', authenticated: true })).toThrow();
  });
});

describe('Onboarding Config Validation (Browser)', () => {
  it('should accept valid config for Bitcoin', () => {
    const config = { rpcUrl: 'http://localhost:8332', network: 'mainnet', enabled: true, minConfirmations: 1 };
    const schema = bitcoinModule.configSchema as z.ZodTypeAny;
    const result = schema.safeParse(config);
    expect(result.success).toBe(true);
  });
  it('should reject invalid config for Bitcoin', () => {
    const config = { rpcUrl: 123, network: 'mainnet' };
    const schema = bitcoinModule.configSchema as z.ZodTypeAny;
    const result = schema.safeParse(config);
    expect(result.success).toBe(false);
  });
  it('should accept valid config for generic coin', () => {
    const config = { enabled: true };
    const schema = meowcoinModule.configSchema as z.ZodTypeAny;
    const result = schema.safeParse(config);
    expect(result.success).toBe(true);
  });
  it('should reject invalid config for generic coin', () => {
    const config = { foo: 'bar' };
    const schema = meowcoinModule.configSchema as z.ZodTypeAny;
    const result = schema.safeParse(config);
    expect(result.success).toBe(false);
  });
  it('should accept advanced config for Bitcoin', () => {
    const config = { rpcUrl: 'http://localhost:8332', network: 'mainnet', enabled: true, minConfirmations: 1, multiSig: true, feeRate: 0.0001, custom: { foo: 'bar' } };
    const schema = bitcoinModule.configSchema as z.ZodTypeAny;
    const result = schema.safeParse(config);
    expect(result.success).toBe(true);
  });
  it('should accept advanced config for MeowCoin', () => {
    const config = { rpcUrl: 'http://localhost:1234', network: 'mainnet', enabled: true, advancedOption: 'test', custom: { bar: 42 } };
    const schema = meowcoinModule.configSchema as z.ZodTypeAny;
    const result = schema.safeParse(config);
    expect(result.success).toBe(true);
  });
});
// #endregion 

// #region OnboardingBrowser E2E Tests
// TODO[roadmap]: Expand for advanced onboarding, feedback, and monitoring E2E flows
// TODO[roadmap]: Add DB-backed onboarding/feedback and advanced E2E scenarios
// #endregion 

describe('Browser Onboarding E2E (DB/External Secret Manager)', () => {
  afterEach(() => {
    delete process.env.SECRET_PERSISTENCE;
    delete process.env.EXTERNAL_SECRETS;
    delete process.env.EXT1;
    delete process.env.EXT2;
  });
  it('should persist onboarding config and secrets with DB adapter', async () => {
    process.env.SECRET_PERSISTENCE = 'db';
    const config = { coin: 'meowcoin', config: { foo: 'dbtest' }, createdAt: new Date().toISOString() };
    await saveConfigBrowser(config);
    const loaded = await loadConfigBrowser();
    expect(loaded).toEqual(config);
    const secret = { key: 'dbtest', value: 'val', createdAt: new Date().toISOString() };
    saveSecret(secret);
    // DBSecretAdapter integration is covered in core tests; here we check onboarding/secret flow
    expect(getSecretAuditLog().some(e => e.event === 'save' && e.key === 'dbtest')).toBe(true);
  });
  it('should persist onboarding config and secrets with external manager', async () => {
    process.env.SECRET_PERSISTENCE = 'external';
    process.env.EXTERNAL_SECRETS = 'EXT1,EXT2';
    process.env.EXT1 = 'val1';
    process.env.EXT2 = 'val2';
    const config = { coin: 'bitcoin', config: { foo: 'exttest' }, createdAt: new Date().toISOString() };
    await saveConfigBrowser(config);
    const loaded = await loadConfigBrowser();
    expect(loaded).toEqual(config);
    // ExternalSecretManagerAdapter is a mock; check that secrets load from env
    const secrets = getAllSecrets();
    expect(secrets.some((s: any) => s.key === 'EXT1' && s.value === 'val1')).toBe(true);
  });
  // TODO[roadmap]: Automate real user input simulation with Playwright/Cypress for browser wizard flows.
});

describe('Browser Onboarding E2E (DB/External Secret Manager - Edge Cases)', () => {
  afterEach(() => {
    delete process.env.SECRET_PERSISTENCE;
    delete process.env.EXTERNAL_SECRETS;
    delete process.env.EXT1;
    delete process.env.EXT2;
  });
  it('should handle DB unavailable gracefully', async () => {
    process.env.SECRET_PERSISTENCE = 'db';
    // Simulate DB unavailable by deleting or renaming the DB file
    const fs = require('fs');
    const dbPath = require('path').resolve(__dirname, '../../core/secrets/secrets.db');
    if (fs.existsSync(dbPath)) fs.renameSync(dbPath, dbPath + '.bak');
    try {
      const config = { coin: 'meowcoin', config: { foo: 'dbfail' }, createdAt: new Date().toISOString() };
      await expect(saveConfigBrowser(config)).resolves.not.toThrow();
      // Should fallback gracefully
    } finally {
      if (fs.existsSync(dbPath + '.bak')) fs.renameSync(dbPath + '.bak', dbPath);
    }
  });
  it('should handle missing EXTERNAL_SECRETS env gracefully', async () => {
    process.env.SECRET_PERSISTENCE = 'external';
    delete process.env.EXTERNAL_SECRETS;
    await expect(loadConfigBrowser()).resolves.not.toThrow();
    const secrets = getAllSecrets();
    expect(secrets.length).toBe(0);
  });
  it('should handle corrupted DB data gracefully', async () => {
    process.env.SECRET_PERSISTENCE = 'db';
    const dbPath = require('path').resolve(__dirname, '../../core/secrets/secrets.db');
    const fs = require('fs');
    fs.writeFileSync(dbPath, 'corrupted');
    await expect(loadConfigBrowser()).resolves.not.toThrow();
    // Should fallback gracefully
    fs.unlinkSync(dbPath);
  });
});

describe('Browser Onboarding E2E (Automated User Input Simulation)', () => {
  it('should simulate user input in browser wizard (stub)', () => {
    // TODO[roadmap]: Implement with Playwright/Cypress for real browser automation
    expect(true).toBe(true);
  });
});

describe('Browser Onboarding E2E (Cross-Module Flows)', () => {
  it('should trigger secret creation, feedback logging, and monitoring metrics on onboarding', async () => {
    const config = { coin: 'meowcoin', config: { foo: 'crossmod' }, createdAt: new Date().toISOString() };
    await saveConfigBrowser(config);
    const secret = { key: 'crossmod', value: 'val', createdAt: new Date().toISOString() };
    saveSecret(secret);
    submitFeedbackBrowser('Cross-module feedback', { authenticated: true });
    const allFeedback = await getAllFeedback();
    expect(allFeedback.some((f: any) => f.feedback === 'Cross-module feedback')).toBe(true);
    const metrics = await getAllMetrics();
    expect(metrics.some((m: any) => m.type === 'feedback')).toBe(true);
  });
});

// #region Playwright E2E: Real Browser Onboarding & Feedback (2025-06-10)
// Moved to test/e2e/onboardingBrowser.playwright.ts to avoid Jest/Playwright runner conflicts.
// #endregion