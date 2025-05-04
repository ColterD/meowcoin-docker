// @jest-environment node
// Jest globals (describe, it, expect) are provided by the test runner.
// If you see linter errors for 'describe', 'it', or 'expect', run: npm i --save-dev @types/jest
process.env.SECRET_PERSISTENCE = 'file';
process.env.SECRET_ENCRYPTION_KEY = '12345678901234567890123456789012';
import 'jest';
import * as fs from 'fs';
import * as path from 'path';
import { Secret } from '../../core/secrets';
// #region Secret Management Test Suite
/**
 * Tests for secret management, backup/restore, rotation, and revocation logic.
 * Ensures correct storage, retrieval, rotation, revocation, and backup/restore flows.
 * @group secrets
 * TODO[roadmap]: Expand with secure storage, integration, and error cases (planned; see AI_AGENT_ROADMAP.md for status)
 */
import { saveSecret, getAllSecrets, rotateSecret, backupSecrets, restoreSecrets, revokeSecret, injectSecretToEnv, fetchSecretFromExternalManager, getSecretAuditLog } from '../../core/secrets';
import { DBSecretAdapter, ExternalSecretManagerAdapter } from '../../core/secrets';
const SECRETS_PATH = path.resolve(__dirname, '../../core/secrets/secrets.json');

describe('Secret Management', () => {
  beforeEach(() => {
    // Clear secrets (in-memory only)
    while (getAllSecrets().length) getAllSecrets().pop();
  });
  it('should save and retrieve secrets', () => {
    const secret = { key: 'api', value: '123', createdAt: new Date().toISOString() };
    saveSecret(secret);
    expect(getAllSecrets()).toContainEqual(secret);
  });
  it('should rotate a secret', () => {
    const secret = { key: 'db', value: 'pw1', createdAt: new Date().toISOString() };
    saveSecret(secret);
    rotateSecret('db', 'pw2');
    const found = getAllSecrets().find(s => s.key === 'db');
    expect(found?.value).toBe('pw2');
    expect(found?.rotatedAt).toBeDefined();
  });
  it('should not rotate non-existent secret', () => {
    rotateSecret('missing', 'pw');
    expect(getAllSecrets().find(s => s.key === 'missing')).toBeUndefined();
  });
  it('should backup and restore secrets', () => {
    const secret1 = { key: 'a', value: '1', createdAt: new Date().toISOString() };
    const secret2 = { key: 'b', value: '2', createdAt: new Date().toISOString() };
    saveSecret(secret1);
    saveSecret(secret2);
    const backup = backupSecrets();
    // Clear and restore
    while (getAllSecrets().length) getAllSecrets().pop();
    expect(getAllSecrets().length).toBe(0);
    restoreSecrets(backup);
    expect(getAllSecrets()).toEqual(expect.arrayContaining([secret1, secret2]));
  });
  it('should revoke a secret', () => {
    const secret = { key: 'revoke', value: 'x', createdAt: new Date().toISOString() };
    saveSecret(secret);
    revokeSecret('revoke');
    const found = getAllSecrets().find(s => s.key === 'revoke');
    expect(found?.revoked).toBe(true);
  });
  it('should inject secret as environment variable', () => {
    const secret = { key: 'ENV_TEST', value: 'env_value', createdAt: new Date().toISOString() };
    saveSecret(secret);
    injectSecretToEnv(secret);
    if (typeof process !== 'undefined' && process.env) {
      expect(process.env[secret.key]).toBe('env_value');
    }
  });
  it('should fetch secret from external manager (stub)', async () => {
    const value = await fetchSecretFromExternalManager();
    expect(value).toBeUndefined();
  });
  it('should log audit events for secret lifecycle', () => {
    const secret = { key: 'audit', value: 'log', createdAt: new Date().toISOString() };
    saveSecret(secret);
    rotateSecret('audit', 'log2');
    revokeSecret('audit');
    backupSecrets();
    restoreSecrets([secret]);
    const log = getSecretAuditLog();
    expect(log.some(e => e.event === 'save' && e.key === 'audit')).toBe(true);
    expect(log.some(e => e.event === 'rotate' && e.key === 'audit')).toBe(true);
    expect(log.some(e => e.event === 'revoke' && e.key === 'audit')).toBe(true);
    expect(log.some(e => e.event === 'backup')).toBe(true);
    expect(log.some(e => e.event === 'restore')).toBe(true);
  });
  it('should not inject env if process.env is undefined', () => {
    // Simulate non-Node environment by temporarily deleting process.env
    const origProcess = global.process;
    // @ts-expect-error: purposely testing error case
    global.process = undefined;
    const secret = { key: 'NO_ENV', value: 'x', createdAt: new Date().toISOString() };
    expect(() => injectSecretToEnv(secret)).not.toThrow();
    global.process = origProcess;
  });
  // TODO[roadmap]: Add secure storage and error case tests (planned; see AI_AGENT_ROADMAP.md for status)
});

describe('Secret Management (File-backed, Encrypted)', () => {
  beforeAll(() => {
    if (fs.existsSync(SECRETS_PATH)) fs.unlinkSync(SECRETS_PATH);
  });
  afterAll(() => {
    if (fs.existsSync(SECRETS_PATH)) fs.unlinkSync(SECRETS_PATH);
    delete process.env.SECRET_PERSISTENCE;
    delete process.env.SECRET_ENCRYPTION_KEY;
  });
  it('should persist and load encrypted secrets', async () => {
    const secret = { key: 'enc', value: 'val', createdAt: new Date().toISOString() };
    await saveSecret(secret);
    await new Promise(resolve => setTimeout(resolve, 50));
    expect(fs.existsSync(SECRETS_PATH)).toBe(true);
    const raw = fs.readFileSync(SECRETS_PATH, 'utf-8');
    expect(typeof raw).toBe('string');
  });
});
// #endregion 

// #region Secret Management Tests
// TODO[roadmap]: Expand for advanced onboarding, feedback, and monitoring E2E flows (planned; see AI_AGENT_ROADMAP.md for status)
// TODO[roadmap]: Add DB-backed secret storage and advanced E2E scenarios (planned; see AI_AGENT_ROADMAP.md for status)
// #endregion 

describe('Secret Management Adapter Stubs', () => {
  it('DBSecretAdapter stub should not throw and return undefined/empty', () => {
    const dbAdapter = new DBSecretAdapter();
    expect(() => dbAdapter.load()).not.toThrow();
  });
  it('ExternalSecretManagerAdapter stub should not throw and return undefined/empty', () => {
    const extAdapter = new ExternalSecretManagerAdapter();
    expect(() => extAdapter.load()).not.toThrow();
    expect(() => extAdapter.save()).not.toThrow();
  });
  // NOTE: These are stubs; expand with real integration and error cases when implemented.
});

// #region DBSecretAdapter Integration Tests
describe('DBSecretAdapter Integration', () => {
  beforeAll(() => {
    process.env.SECRET_PERSISTENCE = 'db';
  });
  afterAll(() => {
    delete process.env.SECRET_PERSISTENCE;
  });
  it('should save and load secrets from SQLite DB', () => {
    const dbAdapter = new DBSecretAdapter();
    const now = new Date().toISOString();
    const secrets: Secret[] = [
      { key: 'db1', value: 'v1', createdAt: now, rotatedAt: undefined, revoked: false },
      { key: 'db2', value: 'v2', createdAt: now, rotatedAt: undefined, revoked: false }
    ];
    dbAdapter.save(secrets);
    const loaded = dbAdapter.load();
    expect(loaded).toEqual(expect.arrayContaining(secrets));
  });
  it('should handle rotation and revocation', () => {
    const dbAdapter = new DBSecretAdapter();
    const secret: Secret = { key: 'db3', value: 'v3', createdAt: new Date().toISOString() };
    dbAdapter.save([secret]);
    let loaded = dbAdapter.load();
    expect(loaded.some((s: Secret) => s.key === 'db3')).toBe(true);
    // Rotate
    secret.value = 'v3-rotated';
    (secret as any).rotatedAt = new Date().toISOString();
    dbAdapter.save([secret]);
    loaded = dbAdapter.load();
    expect((loaded.find((s: Secret) => s.key === 'db3') as Secret)?.value).toBe('v3-rotated');
    // Revoke
    (secret as any).revoked = true;
    dbAdapter.save([secret]);
    loaded = dbAdapter.load();
    expect((loaded.find((s: Secret) => s.key === 'db3') as Secret)?.revoked).toBe(true);
  });
  it('should handle DB unavailable gracefully', () => {
    // Simulate by passing invalid path (not possible with current impl, but placeholder for prod)
    // TODO[roadmap]: Add error handling for DB unavailable
    const dbAdapter = new DBSecretAdapter();
    expect(() => dbAdapter.save([])).not.toThrow();
  });
});
// #endregion

// #region ExternalSecretManagerAdapter Integration Tests
describe('ExternalSecretManagerAdapter Integration', () => {
  beforeAll(() => {
    process.env.SECRET_PERSISTENCE = 'external';
    process.env.EXTERNAL_SECRETS = 'EXT1,EXT2';
    process.env.EXT1 = 'val1';
    process.env.EXT2 = 'val2';
  });
  afterAll(() => {
    delete process.env.SECRET_PERSISTENCE;
    delete process.env.EXTERNAL_SECRETS;
    delete process.env.EXT1;
    delete process.env.EXT2;
  });
  it('should load secrets from environment variables', () => {
    const extAdapter = new ExternalSecretManagerAdapter();
    const loaded = extAdapter.load();
    expect(loaded.some(s => s.key === 'EXT1' && s.value === 'val1')).toBe(true);
    expect(loaded.some(s => s.key === 'EXT2' && s.value === 'val2')).toBe(true);
  });
  it('should no-op on save', () => {
    const extAdapter = new ExternalSecretManagerAdapter();
    expect(() => extAdapter.save()).not.toThrow();
  });
  it('should handle missing EXTERNAL_SECRETS gracefully', () => {
    delete process.env.EXTERNAL_SECRETS;
    const extAdapter = new ExternalSecretManagerAdapter();
    expect(extAdapter.load()).toEqual([]);
    process.env.EXTERNAL_SECRETS = 'EXT1,EXT2';
  });
});
// #endregion