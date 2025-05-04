# Onboarding Guide

This guide provides comprehensive instructions for setting up, configuring, and using the Multi-Coin Blockchain Platform's onboarding system. It covers both browser-based and terminal-based onboarding flows, as well as testing, troubleshooting, and advanced features.

## Table of Contents
- [Quickstart](#quickstart)
- [Onboarding Flows](#onboarding-flows)
  - [Browser-Based Onboarding](#browser-based-onboarding)
  - [Terminal-Based Onboarding](#terminal-based-onboarding)
- [Configuration Options](#configuration-options)
- [Persistence and Storage](#persistence-and-storage)
- [Monitoring and Feedback](#monitoring-and-feedback)
- [Security and Secrets Management](#security-and-secrets-management)
- [Automated Testing](#automated-testing)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq--troubleshooting)
- [Cross-links](#cross-links)

## Quickstart

1. Clone the repository:
   ```bash
   git clone https://github.com/your-org/multi-coin-refactor.git
   cd multi-coin-refactor
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Build the TypeScript code:
   ```bash
   npm run build
   ```

4. Start the browser onboarding wizard:
   ```bash
   npm run onboarding:browser
   ```
   Then visit: http://localhost:12000/onboarding

5. Or start the TUI onboarding wizard:
   ```bash
   npm run onboarding:tui
   ```

See [README.md](../README.md) for more detailed environment and configuration setup.

## Onboarding Flows

The platform supports two main onboarding flows:

### Browser-Based Onboarding

The browser-based onboarding provides a user-friendly web interface for configuring coins and submitting feedback.

**Features:**
- Intuitive form-based interface
- Real-time validation
- Configuration persistence in localStorage
- Server-side validation and storage
- Feedback submission
- Advanced configuration options
- Tabbed interface for easy navigation

**Usage:**
1. Start the server: `npm run onboarding:browser`
2. Open http://localhost:12000/onboarding in your browser
3. Select a coin from the dropdown
4. Fill in the required configuration fields
5. (Optional) Expand "Advanced Options" for additional settings
6. Click "Save Configuration"
7. Switch to the "Feedback" tab to submit feedback

**Implementation Details:**
- Frontend: HTML, CSS, JavaScript with localStorage persistence
- Backend: Express server with validation and persistence
- See `scripts/browser-onboarding-server.js` for the server implementation
- See `wizards/browser/onboarding.ts` for the core functionality

### Terminal-Based Onboarding

The TUI (Terminal User Interface) onboarding provides a command-line interface for configuring coins and submitting feedback.

**Features:**
- Lightweight command-line interface
- Step-by-step guided configuration
- File-based persistence
- Validation and error handling
- Feedback submission

**Usage:**
1. Start the TUI wizard: `npm run onboarding:tui`
2. Follow the prompts to select a coin and configure it
3. Provide feedback when prompted

**Implementation Details:**
- Node.js readline interface
- File-based persistence
- See `scripts/tui-onboarding-cli.js` for the CLI implementation
- See `wizards/tui/onboarding.ts` for the core functionality

## Configuration Options

The platform supports a variety of configuration options for each coin:

### Common Configuration Fields

| Field | Description | Type | Default | Required |
|-------|-------------|------|---------|----------|
| `rpcUrl` | URL for the coin's RPC endpoint | String | - | Yes |
| `network` | Network type (mainnet, testnet, regtest) | String | mainnet | Yes |
| `enabled` | Whether the coin is enabled | Boolean | true | Yes |
| `minConfirmations` | Minimum confirmations required | Number | 1 | No |
| `timeout` | RPC timeout in milliseconds | Number | 30000 | No |

### Coin-Specific Configuration

Each coin may have additional specific configuration options. For example:

**Bitcoin (BTC):**
- `feeRate`: Fee rate in satoshis per byte
- `addressType`: Address type (legacy, segwit, bech32)

**MeowCoin (MEWC):**
- `miningEnabled`: Whether mining is enabled
- `miningThreads`: Number of mining threads

### Advanced Configuration

Advanced configuration options are available for each coin and can be accessed by expanding the "Advanced Options" section in the browser interface or by responding to additional prompts in the TUI.

## Persistence and Storage

The platform supports multiple persistence mechanisms for onboarding configurations:

### Browser Storage

- **localStorage**: Configurations are saved to the browser's localStorage for persistence across sessions
- Implementation: See `wizards/browser/onboarding.ts` for the localStorage implementation

### Server-Side Storage

- **File-based**: Configurations can be saved to JSON files on the server
- **In-memory**: Configurations can be stored in memory (for testing or development)
- **Database**: Support for SQLite and other databases is planned
- Implementation: See `core/onboarding/configStore.ts` for the storage adapters

### Environment Variables

The storage mechanism can be controlled via environment variables:

- `ONBOARDING_PERSISTENCE=file`: Use file-based persistence
- `ONBOARDING_PERSISTENCE=memory`: Use in-memory persistence (default)
- `ONBOARDING_PERSISTENCE=db`: Use database persistence (planned)

## Monitoring and Feedback

The platform includes comprehensive monitoring and feedback mechanisms:

### Monitoring

- All onboarding events are logged to the monitoring system
- Events include: configuration saves, loads, validation errors, and more
- Implementation: See `core/monitoring/index.ts` for the monitoring implementation

### Feedback

- Users can submit feedback via the browser or TUI interface
- Feedback is validated and stored
- Feedback is also logged to the monitoring system
- Implementation: See `core/feedback/index.ts` for the feedback implementation

## Security and Secrets Management

The platform includes robust security and secrets management:

### Secrets Management

- Secrets (e.g., API keys, passwords) are securely stored and managed
- Support for rotation, revocation, and auditing
- Implementation: See `core/secrets/index.ts` for the secrets management implementation

### Authentication

- Basic authentication is supported for the API and onboarding interfaces
- Implementation: See `core/auth/index.ts` for the authentication implementation

## Automated Testing

The platform includes comprehensive automated testing for onboarding flows:

### Browser Onboarding Tests (Playwright)

- A robust, production-ready Playwright E2E test is scaffolded in `test/e2e/onboardingBrowser.e2e.ts`
- Tests the complete browser onboarding flow, including form submission and feedback
- To run: `npx playwright test test/e2e/onboardingBrowser.e2e.ts`
- Requirements: Playwright installed, onboarding app running

### TUI Onboarding Tests (Jest/Mocking)

- A robust, production-ready Jest-based E2E test is scaffolded in `test/e2e/onboardingTui.e2e.ts`
- Tests the complete TUI onboarding flow, including input handling and feedback
- To run: `npm test -- --testPathPattern=test/e2e/onboardingTui.e2e.ts`
- Requirements: TUI wizard supports input mocking

These tests are production-ready and provide a foundation for robust, automated onboarding E2E flows. See also the `playwright.config.ts` for Playwright configuration.

## Troubleshooting

Common issues and their solutions:

### Browser Onboarding Issues

- **"Bad Gateway" error**: Ensure the server is running on the correct port (12000) and host (0.0.0.0)
- **Validation errors**: Check the console for detailed error messages
- **localStorage errors**: Ensure your browser supports localStorage and has sufficient space

### TUI Onboarding Issues

- **"Module not found" error**: Ensure you've built the TypeScript code with `npm run build`
- **Input validation errors**: Check the error messages for details on required fields

For more troubleshooting information, see [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).

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