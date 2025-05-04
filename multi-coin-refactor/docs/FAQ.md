// #region FAQ
/**
 * # Frequently Asked Questions
 * Answers to common questions about setup, onboarding, config, monitoring, feedback, and troubleshooting.
 * Cross-link to TROUBLESHOOTING.md, ONBOARDING.md, E2E tests, monitoring, and feedback modules.
 */

## Q: How do I add a new coin?
A: See ONBOARDING.md and follow the wizard instructions. For advanced onboarding, see E2E tests in test/e2e/onboardingBrowser.e2e.ts and test/e2e/onboardingTui.e2e.ts. Now supports advanced onboarding fields (multi-sig, custom, advancedOption, etc.), persistent storage (file/DB-backed, feature-flagged), and pluggable async storage adapters (in-memory, file, DB). See core/types/index.ts for StorageAdapter interface. All onboarding/feedback storage is now async and feature-flagged.

## Q: Where are configs and secrets stored?
A: See ENVIRONMENT.md and BACKUP_RESTORE.md for details.

## Q: How do I monitor onboarding and feedback events?
A: Onboarding and feedback events are logged to monitoring/metrics (see core/monitoring/index.ts and core/feedback/index.ts).

## Q: How do I back up my data?
A: See BACKUP_RESTORE.md for backup steps.

## Q: What if onboarding fails?
A: See TROUBLESHOOTING.md for diagnostic steps. For rollback scenarios, see E2E tests and scripts/bulk-edit-examples.md.

## Q: How do I rollback a bulk edit?
A: See scripts/bulk-edit-examples.md for rollback and recovery best practices.

## Cross-links
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
- [ONBOARDING.md](./ONBOARDING.md)
- [core/monitoring/index.ts](../core/monitoring/index.ts)
- [core/feedback/index.ts](../core/feedback/index.ts)
- [test/e2e/onboardingBrowser.e2e.ts](../test/e2e/onboardingBrowser.e2e.ts)
- [test/e2e/onboardingTui.e2e.ts](../test/e2e/onboardingTui.e2e.ts)
- [scripts/bulk-edit-examples.md](../scripts/bulk-edit-examples.md)

// TODO[roadmap]: Persistent DB storage for onboarding and feedback is planned; see AI_AGENT_ROADMAP.md for current status and migration steps. Document migration and async usage when implemented.

// #endregion 

// #region Documentation Index
// TODO[roadmap]: Add OpenAPI/Swagger integration, DB-backed storage, advanced E2E, and region folding best practices
// #endregion 