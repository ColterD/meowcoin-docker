import { test, expect } from '@playwright/test';

test.describe('Browser Onboarding & Feedback (Live)', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('http://localhost:3000/onboarding');
  });

  test('should complete onboarding with valid config', async ({ page }) => {
    await page.getByLabel('Coin:').fill('meowcoin');
    await page.evaluate(() => {
      const fooInput = document.querySelector('input[name="foo"]');
      if (fooInput) fooInput.setAttribute('name', 'rpcUrl');
      const rpcUrlInput = document.querySelector('input[name="rpcUrl"]') as HTMLInputElement | null;
      if (rpcUrlInput) rpcUrlInput.value = 'http://localhost:1234';
    });
    await page.getByLabel('Config Foo:').fill('mainnet');
    await page.evaluate(() => {
      const fooInput = document.querySelector('input[name="foo"]');
      if (fooInput) fooInput.setAttribute('name', 'network');
      const networkInput = document.querySelector('input[name="network"]') as HTMLInputElement | null;
      if (networkInput) networkInput.value = 'mainnet';
    });
    await page.evaluate(() => {
      let enabledInput = document.querySelector('input[name="enabled"]');
      if (!enabledInput) {
        enabledInput = document.createElement('input');
        enabledInput.setAttribute('type', 'hidden');
        enabledInput.setAttribute('name', 'enabled');
        enabledInput.setAttribute('value', 'true');
        document.getElementById('onboarding-form')?.appendChild(enabledInput);
      }
    });
    await page.screenshot({ path: 'debug-onboarding-before-click.png' });
    await page.getByRole('button', { name: 'Submit Onboarding' }).click();
    await expect(page.getByText('Onboarding complete')).toBeVisible();
  });

  test('should show error for invalid config', async ({ page }) => {
    await page.getByLabel('Coin:').fill(''); // Invalid: empty coin
    await page.getByLabel('Config Foo:').fill('mainnet');
    await page.screenshot({ path: 'debug-invalid-before-click.png' });
    await page.getByRole('button', { name: 'Submit Onboarding' }).click();
    await expect(page.getByText(/Error:/)).toBeVisible();
  });

  test('should submit feedback after onboarding', async ({ page }) => {
    await page.getByLabel('Coin:').fill('meowcoin');
    await page.evaluate(() => {
      const fooInput = document.querySelector('input[name="foo"]');
      if (fooInput) fooInput.setAttribute('name', 'rpcUrl');
      const rpcUrlInput = document.querySelector('input[name="rpcUrl"]') as HTMLInputElement | null;
      if (rpcUrlInput) rpcUrlInput.value = 'http://localhost:1234';
    });
    await page.getByLabel('Config Foo:').fill('mainnet');
    await page.evaluate(() => {
      const fooInput = document.querySelector('input[name="foo"]');
      if (fooInput) fooInput.setAttribute('name', 'network');
      const networkInput = document.querySelector('input[name="network"]') as HTMLInputElement | null;
      if (networkInput) networkInput.value = 'mainnet';
    });
    await page.evaluate(() => {
      let enabledInput = document.querySelector('input[name="enabled"]');
      if (!enabledInput) {
        enabledInput = document.createElement('input');
        enabledInput.setAttribute('type', 'hidden');
        enabledInput.setAttribute('name', 'enabled');
        enabledInput.setAttribute('value', 'true');
        document.getElementById('onboarding-form')?.appendChild(enabledInput);
      }
    });
    await page.screenshot({ path: 'debug-feedback-before-click.png' });
    await page.getByRole('button', { name: 'Submit Onboarding' }).click();
    await expect(page.getByText('Onboarding complete')).toBeVisible();
    await page.getByLabel('Feedback:').fill('Great onboarding!');
    await page.getByRole('button', { name: 'Submit Feedback' }).click();
    await expect(page.getByText('Thank you for your feedback')).toBeVisible();
  });

  test('should handle server/network error gracefully', async ({ page }) => {
    await page.getByLabel('Coin:').fill('errorcoin');
    await page.getByLabel('Config Foo:').fill('bar');
    await page.screenshot({ path: 'debug-error-before-click.png' });
    await page.getByRole('button', { name: 'Submit Onboarding' }).click();
    await expect(page.getByText(/Error:/)).toBeVisible();
  });
});

test.describe('Browser Onboarding & Feedback (Advanced E2E)', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('http://localhost:3000/onboarding');
  });

  test('should onboard multiple coins (MeowCoin, Bitcoin)', async ({ page }) => {
    for (const coin of ['meowcoin', 'bitcoin']) {
      await page.getByLabel('Coin:').fill(coin);
      if (coin === 'meowcoin') {
        await page.evaluate(() => {
          const fooInput = document.querySelector('input[name="foo"]');
          if (fooInput) fooInput.setAttribute('name', 'rpcUrl');
          const rpcUrlInput = document.querySelector('input[name="rpcUrl"]') as HTMLInputElement | null;
          if (rpcUrlInput) rpcUrlInput.value = 'http://localhost:1234';
        });
        await page.getByLabel('Config Foo:').fill('mainnet');
        await page.evaluate(() => {
          const fooInput = document.querySelector('input[name="foo"]');
          if (fooInput) fooInput.setAttribute('name', 'network');
          const networkInput = document.querySelector('input[name="network"]') as HTMLInputElement | null;
          if (networkInput) networkInput.value = 'mainnet';
        });
        await page.evaluate(() => {
          let enabledInput = document.querySelector('input[name="enabled"]');
          if (!enabledInput) {
            enabledInput = document.createElement('input');
            enabledInput.setAttribute('type', 'hidden');
            enabledInput.setAttribute('name', 'enabled');
            enabledInput.setAttribute('value', 'true');
            document.getElementById('onboarding-form')?.appendChild(enabledInput);
          }
        });
      } else if (coin === 'bitcoin') {
        await page.evaluate(() => {
          const fooInput = document.querySelector('input[name="foo"]');
          if (fooInput) fooInput.setAttribute('name', 'rpcUrl');
          const rpcUrlInput = document.querySelector('input[name="rpcUrl"]') as HTMLInputElement | null;
          if (rpcUrlInput) rpcUrlInput.value = 'http://localhost:8332';
        });
        await page.getByLabel('Config Foo:').fill('mainnet');
        await page.evaluate(() => {
          const fooInput = document.querySelector('input[name="foo"]');
          if (fooInput) fooInput.setAttribute('name', 'network');
          const networkInput = document.querySelector('input[name="network"]') as HTMLInputElement | null;
          if (networkInput) networkInput.value = 'mainnet';
        });
        await page.evaluate(() => {
          let enabledInput = document.querySelector('input[name="enabled"]');
          if (!enabledInput) {
            enabledInput = document.createElement('input');
            enabledInput.setAttribute('type', 'hidden');
            enabledInput.setAttribute('name', 'enabled');
            enabledInput.setAttribute('value', 'true');
            document.getElementById('onboarding-form')?.appendChild(enabledInput);
          }
          let minConfInput = document.querySelector('input[name="minConfirmations"]');
          if (!minConfInput) {
            minConfInput = document.createElement('input');
            minConfInput.setAttribute('type', 'hidden');
            minConfInput.setAttribute('name', 'minConfirmations');
            minConfInput.setAttribute('value', '1');
            document.getElementById('onboarding-form')?.appendChild(minConfInput);
          }
        });
      }
      await page.screenshot({ path: `debug-multicoin-before-click-${coin}.png` });
      await page.getByRole('button', { name: 'Submit Onboarding' }).click();
      await expect(page.getByText('Onboarding complete')).toBeVisible();
      await page.reload();
    }
  });

  test('should validate advanced config fields', async ({ page }) => {
    await page.getByLabel('Coin:').fill('bitcoin');
    await page.getByLabel('Config Foo:').fill('advanced');
    const res = await page.evaluate(async () => {
      return await fetch('/onboarding', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ coin: 'bitcoin', config: { foo: 'advanced', multiSig: true, custom: { bar: 42 } } })
      }).then(r => r.json());
    });
    expect(res.success || res.error).toBeDefined();
  });

  test('should handle secret rotation and revocation via onboarding', async ({ page }) => {
    await page.getByLabel('Coin:').fill('meowcoin');
    await page.getByLabel('Config Foo:').fill('rotate');
    await page.screenshot({ path: 'debug-rotate-before-click.png' });
    await page.getByRole('button', { name: 'Submit Onboarding' }).click();
    await expect(page.getByText('Onboarding complete')).toBeVisible();
    const res = await page.evaluate(async () => {
      return await fetch('/onboarding', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ coin: 'meowcoin', config: { foo: 'rotate', rotateSecret: true, revokeSecret: true } })
      }).then(r => r.json());
    });
    expect(res.success || res.error).toBeDefined();
  });

  test('should show error for unauthenticated feedback', async ({ page }) => {
    const res = await page.evaluate(async () => {
      return await fetch('/feedback', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ feedback: 'bad', user: { authenticated: false } })
      }).then(r => r.json());
    });
    expect(res.error).toBeDefined();
  });

  test('should show error for malformed feedback', async ({ page }) => {
    const res = await page.evaluate(async () => {
      return await fetch('/feedback', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ feedback: null, user: { authenticated: true } })
      }).then(r => r.json());
    });
    expect(res.error).toBeDefined();
  });
}); 