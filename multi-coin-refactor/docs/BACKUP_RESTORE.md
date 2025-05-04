// #region Backup & Restore Guide
/**
 * # Backup & Restore Guide
 * Steps for backing up and restoring configs, secrets, onboarding state, and user feedback.
 * Follows OWASP best practices: backup, restore, rotation, revocation, auditing.
 * Cross-link to ENVIRONMENT.md, README.md, ONBOARDING.md, SECURITY.md, and core/secrets/index.ts.
 * See also: [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
 */

## What to Back Up
- Config files (core/onboarding/configStore.ts data)
- Secrets (core/secrets/index.ts, secrets/ directory)
- User feedback (core/feedback/index.ts data, now supports pluggable async storage: in-memory, file, DB)

## Backup Steps
1. Copy config and secrets directories to a secure location.
2. Export onboarding and feedback data if using persistent storage (file or DB-backed, see core/types/index.ts for StorageAdapter interface).
3. Use `backupSecrets()` from core/secrets/index.ts to export secrets (see SECURITY.md for encryption guidance).
4. Store backups encrypted and restrict access (least privilege).

## Restore Steps
1. Copy backed-up files to their original locations.
2. Use `restoreSecrets()` from core/secrets/index.ts to import secrets.
3. Restart the application.
4. Audit restored secrets for rotation/revocation needs.
5. Review the secret audit log for all backup/restore events (see getSecretAuditLog in core/secrets/index.ts).

## Best Practices
- Rotate secrets regularly and after restore (see SECURITY.md).
- Revoke any secrets that should no longer be valid.
- Audit backup/restore events and access (see getSecretAuditLog in core/secrets/index.ts).
- Never store plaintext secrets in version control or logs.
- See [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html) for more.

## Cross-links
- [ENVIRONMENT.md](./ENVIRONMENT.md)
- [README.md](../README.md)
- [SECURITY.md](../SECURITY.md)
- [core/secrets/index.ts](../core/secrets/index.ts)
- Feedback is persisted to core/feedback/feedbacks.json and validated (see core/feedback/index.ts).
- All feedback is logged to monitoring/metrics (see core/monitoring/).
// #endregion 

// #region Documentation Index
// TODO[roadmap]: OpenAPI/Swagger integration, DB-backed storage, advanced E2E, and region folding best practices are planned; see AI_AGENT_ROADMAP.md for tracking and implementation status.
// #endregion 