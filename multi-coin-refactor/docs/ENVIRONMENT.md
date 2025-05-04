// #region Environment Variables & Secrets
/**
 * # Environment Variables & Secrets
 * List all required environment variables and secrets for setup and operation.
 * Follows OWASP best practices: secure storage, rotation, backup/restore, auditing.
 * Cross-link to README.md, SECURITY.md, ONBOARDING.md, BACKUP_RESTORE.md, and core/secrets/index.ts.
 * TODO[roadmap]: Expand with new variables and onboarding flows as needed.
 */

## Environment Variables
- `NODE_ENV`: Node environment (development, production, test)
- `PORT`: API server port
- `DB_URL`: Database connection string
- ...

## Secrets
- `DB_PASSWORD`: Database password (see secrets/db_password.txt)
- All secrets managed via core/secrets/index.ts (see BACKUP_RESTORE.md for backup/restore)
- ...

## Usage
- Set env vars in your shell or .env file.
- Store secrets securely (see SECURITY.md).
- Use `backupSecrets()` and `restoreSecrets()` for backup/restore (see BACKUP_RESTORE.md).
- Audit secret usage and access regularly.

## Best Practices
- Never commit secrets to version control.
- Rotate secrets regularly and after restore.
- Revoke unused or exposed secrets.
- Audit environment and secret usage (see SECURITY.md and getSecretAuditLog in core/secrets/index.ts).
- See [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html) for more.

## Cross-links
- [README.md](../README.md)
- [SECURITY.md](../SECURITY.md)
- [ONBOARDING.md](../ONBOARDING.md)
- [BACKUP_RESTORE.md](./BACKUP_RESTORE.md)
- [core/secrets/index.ts](../core/secrets/index.ts)
- Feedback is persisted to core/feedback/feedbacks.json and validated (see core/feedback/index.ts).
- All feedback is logged to monitoring/metrics (see core/monitoring/).
- TODO[roadmap]: Integrate persistent DB storage for feedback.
// #endregion 