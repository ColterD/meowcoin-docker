#!/usr/bin/env node
// Minimal CLI for TUI onboarding E2E automation
const readline = require('readline');
const { simulateOnboarding } = require('../wizards/tui/index');
const { submitFeedbackTui } = require('../wizards/tui/onboarding');

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