// NOTE: If using TypeScript in a Node.js environment, ensure @types/node is installed for process.env support.
// If not present, run: npm i --save-dev @types/node

import * as fs from 'fs';
import * as path from 'path';
import crypto from 'crypto';
import Database from 'better-sqlite3';

const SECRETS_PATH = path.resolve(__dirname, 'secrets.json');
const ENCRYPTION_KEY = process.env.SECRET_ENCRYPTION_KEY || null; // 32 bytes for AES-256

function encrypt(text: string): string {
  if (!ENCRYPTION_KEY) return text;
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv('aes-256-cbc', Buffer.from(ENCRYPTION_KEY, 'utf-8'), iv);
  let encrypted = cipher.update(text, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  return iv.toString('hex') + ':' + encrypted;
}
function decrypt(text: string): string {
  if (!ENCRYPTION_KEY) return text;
  const [ivHex, encrypted] = text.split(':');
  const iv = Buffer.from(ivHex, 'hex');
  const decipher = crypto.createDecipheriv('aes-256-cbc', Buffer.from(ENCRYPTION_KEY, 'utf-8'), iv);
  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  return decrypted;
}

class FileSecretAdapter {
  load(): Secret[] {
    if (!fs.existsSync(SECRETS_PATH)) return [];
    try {
      const raw = fs.readFileSync(SECRETS_PATH, 'utf-8');
      const decrypted = decrypt(raw);
      return JSON.parse(decrypted);
    } catch {
      return [];
    }
  }
  save(secrets: Secret[]) {
    const data = JSON.stringify(secrets, null, 2);
    const encrypted = encrypt(data);
    fs.writeFileSync(SECRETS_PATH, encrypted);
  }
}

class DBSecretAdapter {
  private db: any;
  constructor() {
    try {
      this.db = new Database(path.resolve(__dirname, 'secrets.db'));
      this.db.exec(`CREATE TABLE IF NOT EXISTS secrets (
        key TEXT PRIMARY KEY,
        value TEXT,
        createdAt TEXT,
        rotatedAt TEXT,
        revoked INTEGER
      )`);
    } catch (e) {
      this.db = null;
    }
  }
  load(): Secret[] {
    if (!this.db) return [];
    try {
      // Normalize null to undefined for rotatedAt to match Secret interface (see AI_AGENT_ROADMAP.md, docs/ONBOARDING.md, docs/TROUBLESHOOTING.md)
      return this.db.prepare('SELECT * FROM secrets').all().map((row: any) => ({
        key: row.key,
        value: row.value,
        createdAt: row.createdAt,
        rotatedAt: row.rotatedAt === null ? undefined : row.rotatedAt,
        revoked: !!row.revoked
      }));
    } catch {
      return [];
    }
  }
  save(secrets: Secret[]) {
    if (!this.db) return;
    const insert = this.db.prepare('INSERT OR REPLACE INTO secrets (key, value, createdAt, rotatedAt, revoked) VALUES (?, ?, ?, ?, ?)');
    this.db.prepare('DELETE FROM secrets').run();
    for (const s of secrets) {
      insert.run(s.key, s.value, s.createdAt, s.rotatedAt || null, s.revoked ? 1 : 0);
    }
  }
}

class ExternalSecretManagerAdapter {
  // Mock: uses process.env for demo; replace with real API integration
  load(): Secret[] {
    const keys = (process.env.EXTERNAL_SECRETS || '').split(',').filter(Boolean);
    return keys.map(key => ({
      key,
      value: process.env[key] || '',
      createdAt: new Date().toISOString()
    }));
  }
  save() {
    // No-op for mock; real implementation would push to external API
  }
}

// Select storage backend
let secretAdapter: any = null;
if (process.env.SECRET_PERSISTENCE === 'file') {
  secretAdapter = new FileSecretAdapter();
} else if (process.env.SECRET_PERSISTENCE === 'db') {
  secretAdapter = new DBSecretAdapter();
} else if (process.env.SECRET_PERSISTENCE === 'external') {
  secretAdapter = new ExternalSecretManagerAdapter();
}

const secrets: Secret[] = secretAdapter ? secretAdapter.load() : [];

// #region Secret Management
/**
 * Interface for secret storage, retrieval, rotation, backup, and restore.
 * TODO[roadmap]: Integrate with secure secret management system and persistent storage (planned; see AI_AGENT_ROADMAP.md for status)
 * Follows OWASP best practices: rotation, revocation, auditing, backup/restore.
 * Cross-links: BACKUP_RESTORE.md, SECURITY.md
 */
export interface Secret {
  key: string;
  value: string;
  createdAt: string;
  rotatedAt?: string;
  revoked?: boolean;
}

// #region Internal (Unexported) Implementations
function _saveSecret(secret: Secret) {
  secrets.push(secret);
  if (secretAdapter) secretAdapter.save(secrets);
}
function _rotateSecret(key: string, newValue: string) {
  const secret = secrets.find(s => s.key === key);
  if (secret) {
    secret.value = newValue;
    secret.rotatedAt = new Date().toISOString();
    if (secretAdapter) secretAdapter.save(secrets);
  }
}
function _revokeSecret(key: string) {
  const secret = secrets.find(s => s.key === key);
  if (secret) {
    secret.revoked = true;
    if (secretAdapter) secretAdapter.save(secrets);
    // TODO[roadmap]: Log revocation event for auditing (planned; see AI_AGENT_ROADMAP.md for status)
  }
}
function _backupSecrets(): Secret[] {
  // TODO[roadmap]: Encrypt secrets before backup (planned; see AI_AGENT_ROADMAP.md for status)
  return JSON.parse(JSON.stringify(secrets));
}
function _restoreSecrets(backup: Secret[]) {
  // TODO[roadmap]: Decrypt secrets after restore (planned; see AI_AGENT_ROADMAP.md for status)
  secrets.length = 0;
  backup.forEach(s => secrets.push(s));
  if (secretAdapter) secretAdapter.save(secrets);
}
// #endregion

// #region Advanced Secret Management Extensions
/**
 * Inject secrets as environment variables (stub).
 * TODO[roadmap]: Implement secure env var injection for production/cloud (planned; see AI_AGENT_ROADMAP.md for status)
 * @param secret - The secret to inject
 */
export function injectSecretToEnv(secret: Secret) {
  // WARNING: Only for demonstration; do not use in production as-is.
  if (typeof (globalThis as any).process !== 'undefined' && (globalThis as any).process.env) {
    (globalThis as any).process.env[secret.key] = secret.value;
    // TODO[roadmap]: Log injection event for auditing
  }
}

/**
 * Stub for integration with external secret manager (e.g., AWS Secrets Manager, HashiCorp Vault).
 * TODO[roadmap]: Replace with real external secret manager call (planned; see AI_AGENT_ROADMAP.md for status)
 * @param key - The secret key to fetch
 * @returns Secret value (stub)
 */
export async function fetchSecretFromExternalManager(): Promise<string | undefined> {
  // TODO[roadmap]: Replace with real external secret manager call
  // Simulate async fetch
  return Promise.resolve(undefined);
}

/**
 * Audit log for secret lifecycle events (in-memory, stub).
 * TODO[roadmap]: Integrate with persistent audit log/monitoring (planned; see AI_AGENT_ROADMAP.md for status)
 */
const secretAuditLog: { event: string; key: string; timestamp: string; details?: unknown }[] = [];

function logSecretEvent(event: string, _key: string, details?: unknown) {
  secretAuditLog.push({ event, key: _key, timestamp: new Date().toISOString(), details });
}

// Exported, audit-logging versions
/**
 * Save a secret and log the event.
 */
export function saveSecret(secret: Secret) {
  _saveSecret(secret);
  logSecretEvent('save', secret.key);
}
/**
 * Rotate a secret and log the event.
 */
export function rotateSecret(key: string, newValue: string) {
  _rotateSecret(key, newValue);
  logSecretEvent('rotate', key, { newValue });
}
/**
 * Revoke a secret and log the event.
 */
export function revokeSecret(key: string) {
  _revokeSecret(key);
  logSecretEvent('revoke', key);
}
/**
 * Backup all secrets and log the event.
 */
export function backupSecrets(): Secret[] {
  const backup = _backupSecrets();
  logSecretEvent('backup', 'ALL');
  return backup;
}
/**
 * Restore secrets from backup and log the event.
 */
export function restoreSecrets(backup: Secret[]) {
  _restoreSecrets(backup);
  logSecretEvent('restore', 'ALL');
}

/**
 * Get the in-memory secret audit log (stub).
 * TODO[roadmap]: Integrate with persistent monitoring/auditing
 */
export function getSecretAuditLog() {
  return secretAuditLog;
}

/**
 * Get all secrets.
 */
export function getAllSecrets(): Secret[] {
  return secrets;
}
// #endregion

// #region Secrets Management
// TODO[roadmap]: Expand for advanced onboarding, feedback, and monitoring secret flows (planned; see AI_AGENT_ROADMAP.md for status)
// TODO[roadmap]: Add DB-backed secret storage and advanced audit logging (planned; see AI_AGENT_ROADMAP.md for status)
// #endregion

// NOTE: Requires 'better-sqlite3' package. Run: npm install better-sqlite3
// TODO[roadmap]: DBSecretAdapter uses SQLite for demo; production should support async/clustered DBs. ExternalSecretManagerAdapter is a mock; replace with real API integration (AWS, Vault, Doppler, etc.). (planned; see AI_AGENT_ROADMAP.md for status)

export { DBSecretAdapter, ExternalSecretManagerAdapter }; 