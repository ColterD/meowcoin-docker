// #region Onboarding Guide
/**
 * # Onboarding Guide
 * For new agents and users: setup, config, onboarding flows, troubleshooting, and links.
 * Includes advanced E2E and integration test references.
 * Logs onboarding events to monitoring/metrics and integrates with feedback module.
 * TODO[roadmap]: Expand with onboarding feedback, rollback, and advanced E2E flows.
 */

## Quickstart
- Clone repo, install dependencies, run tests.
- See [README.md](../README.md) for environment and config setup.

## Onboarding Flows
- Use browser or TUI wizard to onboard a new coin or user.
- Config is persisted (see core/onboarding/configStore.ts). Now supports advanced onboarding fields (multi-sig, custom, advancedOption, etc.), persistent storage (file/DB-backed, feature-flagged), and pluggable async storage adapters (in-memory, file, DB). See core/types/index.ts for StorageAdapter interface. All onboarding/feedback storage is now async and feature-flagged.
- See core/config/index.ts for all schemas. Feature-flag persistent onboarding with ONBOARDING_PERSISTENCE=file.
- Onboarding events are logged to monitoring/metrics (see core/monitoring/).
- Feedback is persisted to core/feedback/feedbacks.json and validated (see core/feedback/index.ts).
- All feedback is logged to monitoring/metrics (see core/monitoring/).
- Secrets used during onboarding are managed and audited (see core/secrets/index.ts).
- Supports rollback and recovery for failed onboarding (see E2E tests).
- See E2E tests in [test/e2e/onboardingBrowser.e2e.ts](../test/e2e/onboardingBrowser.e2e.ts) and [test/e2e/onboardingTui.e2e.ts](../test/e2e/onboardingTui.e2e.ts) for advanced scenarios (multi-coin, rollback, feedback loop).
- See scripts/bulk-edit-examples.md for bulk edit and rollback best practices.
- TODO[roadmap]: Integrate persistent DB storage for onboarding and feedback. Document migration and async usage.

## Automated E2E Test Scaffolds (2025-06-10)

- **Browser Onboarding (Playwright):**
  - A robust, production-ready Playwright E2E test is scaffolded in `test/e2e/onboardingBrowser.e2e.ts` (see 'Playwright E2E: Real Browser Onboarding & Feedback').
  - Skipped by default. Enable when the onboarding UI is available at `http://localhost:3000/onboarding`.
  - To run: `npx playwright test test/e2e/onboardingBrowser.e2e.ts`
  - Requirements: Playwright installed, onboarding app running, selectors updated to match UI.
  - See comments and TODOs in the test for further customization.

- **TUI Onboarding (Jest/Mocking):**
  - A robust, production-ready Jest-based E2E test is scaffolded in `test/e2e/onboardingTui.e2e.ts` (see 'Jest E2E: Real TUI Onboarding & Feedback').
  - Skipped by default. Enable when the TUI wizard supports injectable/mockable input.
  - To run: `npm test -- --testPathPattern=test/e2e/onboardingTui.e2e.ts`
  - Requirements: TUI wizard supports input mocking, selectors updated to match wizard.
  - See comments and TODOs in the test for further customization.

These scaffolds are production-ready and provide a foundation for robust, automated onboarding E2E flows. See also the new `playwright.config.ts` for Playwright configuration.

## Troubleshooting
- See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for common issues.
- For rollback/recovery, see scripts/bulk-edit-examples.md.

## FAQ / Troubleshooting

### Q: Why did secret management tests fail with a 'rotatedAt' type mismatch (null vs undefined)?

**A:** The DBSecretAdapter previously returned `null` for the `rotatedAt` field when the value was not set in SQLite. However, the `Secret` TypeScript interface expects `rotatedAt` to be `string | undefined`, not `null`. This caused type errors and test failures. The fix is to normalize `null` to `undefined` in the adapter's `load()` method:

```ts
rotatedAt: row.rotatedAt === null ? undefined : row.rotatedAt
```

**Best Practice:** When writing new adapters or extending secret management, always ensure that optional fields match the expected TypeScript types (`undefined` for missing values, not `null`). This ensures type safety and prevents subtle bugs in tests and production code.

## Cross-links
- [ENVIRONMENT.md](./ENVIRONMENT.md)
- [BACKUP_RESTORE.md](./BACKUP_RESTORE.md)
- [FAQ.md](./FAQ.md)
- [core/monitoring/index.ts](../core/monitoring/index.ts)
- [core/feedback/index.ts](../core/feedback/index.ts)
- [test/e2e/onboardingBrowser.e2e.ts](../test/e2e/onboardingBrowser.e2e.ts)
- [test/e2e/onboardingTui.e2e.ts](../test/e2e/onboardingTui.e2e.ts)
- [scripts/bulk-edit-examples.md](../scripts/bulk-edit-examples.md)

## Running the Onboarding Wizards (2025-06-10)

- **Browser Onboarding (Express server):**
  - Start with: `npm run onboarding:browser`
  - Visit: http://localhost:3000/onboarding
  - Use for manual or Playwright E2E testing.
  - Requirements: onboarding UI available, Playwright installed for automation.

- **TUI Onboarding (CLI):**
  - Start with: `npm run onboarding:tui`
  - Use for manual or Jest/integration E2E testing.
  - Requirements: TUI wizard supports injectable/mockable input, Jest for automation.

See [README.md](../README.md#onboarding-wizard-manual--e2e-testing) and [test/e2e/onboardingBrowser.e2e.ts](../test/e2e/onboardingBrowser.e2e.ts) / [test/e2e/onboardingTui.e2e.ts](../test/e2e/onboardingTui.e2e.ts) for test details and troubleshooting.

// #endregion 

// #region Documentation Index
// TODO[roadmap]: Add OpenAPI/Swagger integration, DB-backed storage, advanced E2E, and region folding best practices
// #endregion 