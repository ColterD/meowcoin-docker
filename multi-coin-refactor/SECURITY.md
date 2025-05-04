// #region Security Guide
/**
 * # Security Guide
 * Input validation, authentication, RBAC, secret management, backup/restore, rotation, revocation, and auditing best practices.
 * Follows OWASP best practices for secrets: secure storage, rotation, revocation, auditing, backup/restore.
 * Cross-link to ENVIRONMENT.md, BACKUP_RESTORE.md, README.md, ONBOARDING.md, and core/secrets/index.ts.
 * See also: [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
 * TODO[roadmap]: Expand with onboarding, monitoring, and advanced security flows.
 */

## Input Validation
- All API/user input should be validated and sanitized.
- See core/validation/ for schemas and middleware.
- Wizard flows (browser/TUI) now include input validation stubs.

## Authentication & RBAC
- Use authentication middleware for protected routes (stubbed, see core/auth/ and api/middleware/auth.ts).
- Wizard flows (browser/TUI) now include authentication stubs.
- Role-based access control (RBAC) recommended for admin/user separation.

## Secret Management
- Store secrets in secrets/ directory or via core/secrets/index.ts.
- Use `backupSecrets()` and `restoreSecrets()` for backup/restore (see BACKUP_RESTORE.md).
- Rotate secrets regularly and after restore.
- Revoke unused or exposed secrets.
- Audit secret usage and access (see ENVIRONMENT.md).
- Never commit secrets to version control or logs.
- See [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html) for more.

## Monitoring & Alerting
- See core/monitoring/ for metrics and alerting stubs.
- Monitor onboarding, API, and feedback events for suspicious activity.

## Best Practices
- Use strong passwords and keys.
- Limit access to sensitive files.
- Review security logs regularly.
- Audit backup/restore and secret rotation events.

## Cross-links
- [ENVIRONMENT.md](docs/ENVIRONMENT.md)
- [BACKUP_RESTORE.md](docs/BACKUP_RESTORE.md)
- [README.md](README.md)
- [ONBOARDING.md](docs/ONBOARDING.md)
- [core/secrets/index.ts](core/secrets/index.ts)
- [wizards/browser/onboarding.ts](wizards/browser/onboarding.ts)
- [wizards/tui/onboarding.ts](wizards/tui/onboarding.ts)
- [core/monitoring/](core/monitoring/)

## Feedback Security
- Feedback is persisted to core/feedback/feedbacks.json and validated (see core/feedback/index.ts).
- All feedback is logged to monitoring/metrics (see core/monitoring/).
- TODO[roadmap]: Integrate persistent DB storage for feedback.
// #endregion 