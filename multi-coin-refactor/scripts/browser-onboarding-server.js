// Minimal Express server for browser onboarding E2E automation
const express = require('express');
const path = require('path');
const bodyParser = require('body-parser');
const { simulateOnboarding } = require('../wizards/browser/index');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Serve static HTML onboarding form
app.get('/onboarding', (req, res) => {
  res.send(`
    <html>
      <head><title>Onboarding</title></head>
      <body>
        <h1>Onboarding</h1>
        <form method="POST" action="/onboarding" id="onboarding-form">
          <label>Coin: <input name="coin" required /></label><br/>
          <label>Config Foo: <input name="foo" required /></label><br/>
          <button type="submit">Submit</button>
        </form>
        <form method="POST" action="/feedback" id="feedback-form">
          <label>Feedback: <input name="feedback" required /></label><br/>
          <button type="submit">Submit Feedback</button>
        </form>
        <div id="result"></div>
        <script>
          document.getElementById('onboarding-form').onsubmit = async function(e) {
            e.preventDefault();
            const coin = this.coin.value;
            const foo = this.foo.value;
            const res = await fetch('/onboarding', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ coin, config: { foo } })
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
app.post('/onboarding', (req, res) => {
  try {
    const { coin, config } = req.body;
    const result = simulateOnboarding(coin, config);
    if (result.success) return res.json({ success: true });
    return res.json({ error: result.error || 'Invalid config', details: result.details });
  } catch (e) {
    return res.json({ error: e.message });
  }
});

// Handle feedback POST
app.post('/feedback', (req, res) => {
  try {
    const { feedback, user } = req.body;
    // Use the submitFeedbackBrowser function from onboarding module
    const { submitFeedbackBrowser } = require('../wizards/browser/onboarding');
    submitFeedbackBrowser(feedback, user);
    return res.json({ success: true });
  } catch (e) {
    return res.json({ error: e.message });
  }
});

app.listen(PORT, () => {
  console.log(`Browser onboarding server running at http://localhost:${PORT}/onboarding`);
}); 