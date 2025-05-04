console.log('Starting server...');
// Minimal Express server for browser onboarding E2E automation
import express from 'express';
import bodyParser from 'body-parser';
import { simulateOnboarding } from '../wizards/browser/index';
import { submitFeedbackBrowser } from '../wizards/browser/onboarding';

console.log('Imports complete.');

const app: any = express();
const PORT = process.env.PORT || 3000;

console.log('Express app created.');

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

console.log('Middleware registered.');

// Serve static HTML onboarding form
app.get('/onboarding', (_req: any, res: any) => {
  res.send(`
    <html>
      <head><title>Onboarding</title></head>
      <body>
        <h1>Onboarding</h1>
        <form method="POST" action="/onboarding" id="onboarding-form">
          <label>Coin: <input name="coin" id="coin-input" required /></label><br/>
          <label>rpcUrl: <input name="rpcUrl" required /></label><br/>
          <label>network: <input name="network" required /></label><br/>
          <label>enabled: <input name="enabled" type="checkbox" checked /></label><br/>
          <div id="btc-fields" style="display:none">
            <label>minConfirmations: <input name="minConfirmations" type="number" min="0" value="1" /></label><br/>
          </div>
          <button type="submit">Submit Onboarding</button>
        </form>
        <form method="POST" action="/feedback" id="feedback-form">
          <label>Feedback: <input name="feedback" required /></label><br/>
          <button type="submit">Submit Feedback</button>
        </form>
        <div id="result"></div>
        <script>
          // Show/hide Bitcoin fields based on coin
          document.getElementById('coin-input').addEventListener('input', function() {
            const coin = this.value.toLowerCase();
            document.getElementById('btc-fields').style.display = (coin === 'bitcoin' || coin === 'btc') ? '' : 'none';
          });
          document.getElementById('onboarding-form').onsubmit = async function(e) {
            e.preventDefault();
            const coin = this.coin.value;
            const rpcUrl = this.rpcUrl.value;
            const network = this.network.value;
            const enabled = this.enabled.checked;
            let config = { rpcUrl, network, enabled };
            if (coin.toLowerCase() === 'bitcoin' || coin.toLowerCase() === 'btc') {
              const minConfirmations = Number(this.minConfirmations.value);
              config.minConfirmations = minConfirmations;
            }
            const res = await fetch('/onboarding', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ coin, config })
            });
            const data = await res.json();
            document.getElementById('result').innerText = data.success ? 'Onboarding complete' : 'Error: ' + (data.error || 'Unknown');
          };
          document.getElementById('feedback-form').onsubmit = async function(e) {
            e.preventDefault();
            const feedback = this.feedback.value;
            const res = await fetch('/feedback', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ feedback, user: { authenticated: true, id: 'e2e-user' } })
            });
            const data = await res.json();
            document.getElementById('result').innerText = data.success ? 'Thank you for your feedback' : 'Error: ' + (data.error || 'Unknown');
          };
        </script>
      </body>
    </html>
  `);
});

// Handle onboarding POST
app.post('/onboarding', (req: any, res: any) => {
  try {
    const { coin, config } = req.body;
    // Coerce types for config fields
    let coercedConfig = { ...config };
    if (typeof coercedConfig.enabled === 'string') {
      coercedConfig.enabled = coercedConfig.enabled === 'true' || coercedConfig.enabled === true;
    }
    if (typeof coercedConfig.minConfirmations === 'string') {
      coercedConfig.minConfirmations = Number(coercedConfig.minConfirmations);
    }
    // Debug output
    console.log('[POST /onboarding] coin:', coin);
    console.log('[POST /onboarding] config:', JSON.stringify(coercedConfig));
    const result = simulateOnboarding(coin, coercedConfig);
    console.log('[POST /onboarding] validation result:', JSON.stringify(result));
    if (result.success) return res.json({ success: true });
    return res.json({ error: result.error || 'Invalid config', details: result.details });
  } catch (e: any) {
    console.error('[POST /onboarding] error:', e);
    return res.json({ error: e.message });
  }
});

// Handle feedback POST
app.post('/feedback', (req: any, res: any) => {
  try {
    const { feedback, user } = req.body;
    submitFeedbackBrowser(feedback, user);
    return res.json({ success: true });
  } catch (e: any) {
    return res.json({ error: e.message });
  }
});

console.log('About to call app.listen...');
app.listen(PORT, () => {
  console.log('Inside app.listen callback.');
  console.log(`Browser onboarding server running at http://localhost:${PORT}/onboarding`);
}); 