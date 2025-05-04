#!/usr/bin/env node
// Minimal CLI for TUI onboarding E2E automation
const readline = require('readline');

// Try to load from dist/ first (compiled version)
let simulateOnboarding, submitFeedbackTui;
try {
  ({ simulateOnboarding } = require('../dist/wizards/tui/index'));
  ({ submitFeedbackTui } = require('../dist/wizards/tui/onboarding'));
  console.log('Loaded TUI wizard from dist/');
} catch (e) {
  console.error('Failed to load from dist/, trying source version with ts-node:', e);
  try {
    // Fall back to source version with ts-node
    require('ts-node/register');
    ({ simulateOnboarding } = require('../wizards/tui/index.ts'));
    ({ submitFeedbackTui } = require('../wizards/tui/onboarding.ts'));
    console.log('Loaded TUI wizard from source with ts-node');
  } catch (e2) {
    console.error('Failed to start TUI wizard:', e2);
    console.log('Please make sure you have run `npm install` and `npx tsc` first.');
    process.exit(1);
  }
}

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function ask(question) {
  return new Promise(resolve => rl.question(question, answer => resolve(answer)));
}

(async () => {
  console.log('TUI Onboarding Wizard');
  const coin = await ask('Coin: ');
  const foo = await ask('Config Foo: ');
  const onboardingResult = simulateOnboarding(coin, { foo });
  if (onboardingResult.success) {
    console.log('Onboarding complete.');
  } else {
    console.error('Onboarding failed:', onboardingResult.error || onboardingResult.details);
    rl.close();
    process.exit(1);
  }
  const feedback = await ask('Feedback: ');
  submitFeedbackTui(feedback, { authenticated: true, id: 'e2e-user' });
  console.log('Thank you for your feedback.');
  rl.close();
})(); 