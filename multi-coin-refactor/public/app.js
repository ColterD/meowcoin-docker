/**
 * Multi-Coin Blockchain Platform - Frontend Application
 * May 2025 Best Practices
 */

// DOM Elements
const themeToggle = document.getElementById('theme-toggle');
const coinSelect = document.getElementById('coin');
const onboardingForm = document.getElementById('onboarding-form');
const feedbackForm = document.getElementById('feedback-form');
const onboardingResult = document.getElementById('onboarding-result');
const feedbackResult = document.getElementById('feedback-result');
const advancedToggle = document.getElementById('advanced-toggle');
const advancedFields = document.getElementById('advanced-fields');

// Theme Management
function initTheme() {
  // Check for saved theme preference
  const savedTheme = localStorage.getItem('theme');
  if (savedTheme) {
    document.documentElement.setAttribute('data-theme', savedTheme);
    if (themeToggle) {
      themeToggle.checked = savedTheme === 'dark';
    }
  } else {
    // Check for system preference
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    if (prefersDark) {
      document.documentElement.setAttribute('data-theme', 'dark');
      if (themeToggle) {
        themeToggle.checked = true;
      }
    }
  }
}

function toggleTheme() {
  const currentTheme = document.documentElement.getAttribute('data-theme') || 'light';
  const newTheme = currentTheme === 'light' ? 'dark' : 'light';
  
  document.documentElement.setAttribute('data-theme', newTheme);
  localStorage.setItem('theme', newTheme);
  
  // Announce theme change for screen readers
  const themeAnnouncement = document.getElementById('theme-announcement');
  if (themeAnnouncement) {
    themeAnnouncement.textContent = `Theme changed to ${newTheme} mode`;
  }
}

// Tab Management
function switchTab(tabName) {
  // Remove active class from all tabs and tab contents
  document.querySelectorAll('.tab').forEach(tab => tab.classList.remove('active'));
  document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
  
  // Add active class to selected tab and content
  if (tabName === 'onboarding') {
    document.querySelector('.tab[data-tab="onboarding"]').classList.add('active');
    document.getElementById('onboarding-tab').classList.add('active');
  } else if (tabName === 'feedback') {
    document.querySelector('.tab[data-tab="feedback"]').classList.add('active');
    document.getElementById('feedback-tab').classList.add('active');
  }
  
  // Update URL hash
  window.location.hash = tabName;
  
  // Announce tab change for screen readers
  const tabAnnouncement = document.getElementById('tab-announcement');
  if (tabAnnouncement) {
    tabAnnouncement.textContent = `Switched to ${tabName} tab`;
  }
}

// Toggle Advanced Options
function toggleAdvanced() {
  const isVisible = advancedFields.classList.contains('show');
  
  if (isVisible) {
    advancedFields.classList.remove('show');
    advancedToggle.innerHTML = '▶ Advanced Options';
    advancedToggle.setAttribute('aria-expanded', 'false');
  } else {
    advancedFields.classList.add('show');
    advancedToggle.innerHTML = '▼ Advanced Options';
    advancedToggle.setAttribute('aria-expanded', 'true');
  }
}

// Form Validation
function validateOnboardingForm() {
  const coin = coinSelect.value;
  const rpcUrl = document.getElementById('rpcUrl').value;
  const network = document.getElementById('network').value;
  
  let isValid = true;
  let errorMessage = '';
  
  // Clear previous errors
  document.querySelectorAll('.form-error').forEach(el => el.remove());
  
  if (!coin) {
    isValid = false;
    errorMessage = 'Please select a coin';
    addErrorTo('coin', errorMessage);
  }
  
  if (!rpcUrl) {
    isValid = false;
    errorMessage = 'RPC URL is required';
    addErrorTo('rpcUrl', errorMessage);
  } else if (!isValidUrl(rpcUrl)) {
    isValid = false;
    errorMessage = 'Please enter a valid URL';
    addErrorTo('rpcUrl', errorMessage);
  }
  
  if (!network) {
    isValid = false;
    errorMessage = 'Please select a network';
    addErrorTo('network', errorMessage);
  }
  
  return isValid;
}

function validateFeedbackForm() {
  const feedback = document.getElementById('feedback').value;
  
  let isValid = true;
  let errorMessage = '';
  
  // Clear previous errors
  document.querySelectorAll('.form-error').forEach(el => el.remove());
  
  if (!feedback) {
    isValid = false;
    errorMessage = 'Please enter your feedback';
    addErrorTo('feedback', errorMessage);
  }
  
  return isValid;
}

function addErrorTo(fieldId, message) {
  const field = document.getElementById(fieldId);
  const errorElement = document.createElement('span');
  errorElement.className = 'form-error';
  errorElement.textContent = message;
  field.parentNode.appendChild(errorElement);
  field.setAttribute('aria-invalid', 'true');
  field.focus();
}

function isValidUrl(string) {
  try {
    new URL(string);
    return true;
  } catch (_) {
    return false;
  }
}

// LocalStorage Management
function saveToLocalStorage(key, data) {
  try {
    localStorage.setItem(key, JSON.stringify(data));
    return true;
  } catch (error) {
    console.error('Error saving to localStorage:', error);
    return false;
  }
}

function loadFromLocalStorage(key) {
  try {
    const data = localStorage.getItem(key);
    return data ? JSON.parse(data) : null;
  } catch (error) {
    console.error('Error loading from localStorage:', error);
    return null;
  }
}

// API Calls
async function submitOnboardingConfig(config) {
  try {
    const response = await fetch('/onboarding', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      },
      body: JSON.stringify(config)
    });
    
    if (!response.ok) {
      throw new Error(`Server responded with ${response.status}: ${response.statusText}`);
    }
    
    return await response.json();
  } catch (error) {
    console.error('Error submitting onboarding config:', error);
    throw error;
  }
}

async function submitFeedback(feedback) {
  try {
    const response = await fetch('/feedback', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      },
      body: JSON.stringify(feedback)
    });
    
    if (!response.ok) {
      throw new Error(`Server responded with ${response.status}: ${response.statusText}`);
    }
    
    return await response.json();
  } catch (error) {
    console.error('Error submitting feedback:', error);
    throw error;
  }
}

// Form Submission Handlers
async function handleOnboardingSubmit(event) {
  event.preventDefault();
  
  if (!validateOnboardingForm()) {
    return;
  }
  
  // Show loading state
  const submitButton = onboardingForm.querySelector('button[type="submit"]');
  const originalButtonText = submitButton.textContent;
  submitButton.disabled = true;
  submitButton.textContent = 'Saving...';
  onboardingResult.className = 'result';
  onboardingResult.textContent = 'Processing your configuration...';
  
  try {
    // Gather form data
    const coin = coinSelect.value;
    const rpcUrl = document.getElementById('rpcUrl').value;
    const network = document.getElementById('network').value;
    const enabled = document.getElementById('enabled').checked;
    const minConfirmations = parseInt(document.getElementById('minConfirmations').value) || 1;
    const timeout = parseInt(document.getElementById('timeout').value) || 30000;
    
    const config = {
      coin,
      config: {
        rpcUrl,
        network,
        enabled,
        minConfirmations,
        timeout
      },
      createdAt: new Date().toISOString()
    };
    
    // Save to localStorage
    saveToLocalStorage('onboardingConfig', config);
    
    // Submit to server
    const result = await submitOnboardingConfig(config);
    
    if (result.success) {
      onboardingResult.className = 'result alert alert-success animate-fade-in';
      onboardingResult.innerHTML = `
        <strong>Success!</strong> Your ${coin} configuration has been saved.
        <p class="mt-2 mb-0">You can now use your wallet with the following settings:</p>
        <ul class="mt-1 mb-0">
          <li>Network: ${network}</li>
          <li>RPC URL: ${rpcUrl}</li>
          <li>Minimum Confirmations: ${minConfirmations}</li>
        </ul>
      `;
    } else {
      onboardingResult.className = 'result alert alert-error animate-fade-in';
      onboardingResult.innerHTML = `
        <strong>Error:</strong> ${result.error || 'Unknown error occurred'}
        ${result.details ? `<pre class="mt-2 mb-0">${JSON.stringify(result.details, null, 2)}</pre>` : ''}
      `;
    }
  } catch (error) {
    onboardingResult.className = 'result alert alert-error animate-fade-in';
    onboardingResult.innerHTML = `<strong>Error:</strong> ${error.message || 'Failed to save configuration'}`;
  } finally {
    // Restore button state
    submitButton.disabled = false;
    submitButton.textContent = originalButtonText;
    
    // Scroll to result
    onboardingResult.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }
}

async function handleFeedbackSubmit(event) {
  event.preventDefault();
  
  if (!validateFeedbackForm()) {
    return;
  }
  
  // Show loading state
  const submitButton = feedbackForm.querySelector('button[type="submit"]');
  const originalButtonText = submitButton.textContent;
  submitButton.disabled = true;
  submitButton.textContent = 'Submitting...';
  feedbackResult.className = 'result';
  feedbackResult.textContent = 'Submitting your feedback...';
  
  try {
    // Gather form data
    const feedbackText = document.getElementById('feedback').value;
    
    const feedbackData = {
      feedback: feedbackText,
      user: { 
        authenticated: true, 
        id: 'user-' + Math.random().toString(36).substring(2, 10) 
      }
    };
    
    // Submit to server
    const result = await submitFeedback(feedbackData);
    
    if (result.success) {
      feedbackResult.className = 'result alert alert-success animate-fade-in';
      feedbackResult.innerHTML = `<strong>Thank you!</strong> Your feedback has been submitted.`;
      
      // Clear form
      document.getElementById('feedback').value = '';
    } else {
      feedbackResult.className = 'result alert alert-error animate-fade-in';
      feedbackResult.innerHTML = `<strong>Error:</strong> ${result.error || 'Unknown error occurred'}`;
    }
  } catch (error) {
    feedbackResult.className = 'result alert alert-error animate-fade-in';
    feedbackResult.innerHTML = `<strong>Error:</strong> ${error.message || 'Failed to submit feedback'}`;
  } finally {
    // Restore button state
    submitButton.disabled = false;
    submitButton.textContent = originalButtonText;
    
    // Scroll to result
    feedbackResult.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }
}

// Load Saved Configuration
function loadSavedConfig() {
  const savedConfig = loadFromLocalStorage('onboardingConfig');
  if (savedConfig && savedConfig.config) {
    const config = savedConfig.config;
    
    // Populate form fields
    if (coinSelect) {
      coinSelect.value = savedConfig.coin || '';
    }
    
    const rpcUrlField = document.getElementById('rpcUrl');
    if (rpcUrlField) {
      rpcUrlField.value = config.rpcUrl || '';
    }
    
    const networkField = document.getElementById('network');
    if (networkField) {
      networkField.value = config.network || 'mainnet';
    }
    
    const enabledField = document.getElementById('enabled');
    if (enabledField) {
      enabledField.checked = config.enabled !== false;
    }
    
    const minConfirmationsField = document.getElementById('minConfirmations');
    if (minConfirmationsField) {
      minConfirmationsField.value = config.minConfirmations || 1;
    }
    
    const timeoutField = document.getElementById('timeout');
    if (timeoutField) {
      timeoutField.value = config.timeout || 30000;
    }
  }
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', function() {
  // Initialize theme
  initTheme();
  
  // Set up event listeners
  if (themeToggle) {
    themeToggle.addEventListener('change', toggleTheme);
  }
  
  // Tab navigation
  document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', () => {
      switchTab(tab.getAttribute('data-tab'));
    });
    
    // Keyboard navigation
    tab.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        switchTab(tab.getAttribute('data-tab'));
      }
    });
  });
  
  // Advanced options toggle
  if (advancedToggle && advancedFields) {
    advancedToggle.addEventListener('click', toggleAdvanced);
    advancedToggle.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        toggleAdvanced();
      }
    });
  }
  
  // Form submissions
  if (onboardingForm) {
    onboardingForm.addEventListener('submit', handleOnboardingSubmit);
  }
  
  if (feedbackForm) {
    feedbackForm.addEventListener('submit', handleFeedbackSubmit);
  }
  
  // Load saved configuration
  loadSavedConfig();
  
  // Check URL hash for tab
  const hash = window.location.hash.substring(1);
  if (hash === 'feedback') {
    switchTab('feedback');
  } else {
    switchTab('onboarding');
  }
});

// Service Worker Registration for offline support
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/service-worker.js')
      .then(registration => {
        console.log('ServiceWorker registration successful with scope: ', registration.scope);
      })
      .catch(error => {
        console.log('ServiceWorker registration failed: ', error);
      });
  });
}