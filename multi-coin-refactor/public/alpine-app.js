/**
 * Multi-Coin Blockchain Platform - Alpine.js Application
 * May 2025 Best Practices
 */

document.addEventListener('alpine:init', () => {
  // Define global Alpine store for application state
  Alpine.store('app', {
    // Theme state
    theme: localStorage.getItem('theme') || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'),
    
    // Initialize theme
    initTheme() {
      document.documentElement.setAttribute('data-theme', this.theme);
      this.announceThemeChange();
    },
    
    // Toggle theme between light and dark
    toggleTheme() {
      this.theme = this.theme === 'light' ? 'dark' : 'light';
      document.documentElement.setAttribute('data-theme', this.theme);
      localStorage.setItem('theme', this.theme);
      this.announceThemeChange();
    },
    
    // Announce theme change for screen readers
    announceThemeChange() {
      const themeAnnouncement = document.getElementById('theme-announcement');
      if (themeAnnouncement) {
        themeAnnouncement.textContent = `Theme changed to ${this.theme} mode`;
      }
    }
  });
  
  // Onboarding component
  Alpine.data('onboarding', () => ({
    // Form state
    coin: '',
    rpcUrl: '',
    network: 'mainnet',
    enabled: true,
    minConfirmations: 1,
    timeout: 30000,
    
    // UI state
    advancedOpen: false,
    isSubmitting: false,
    result: { show: false, success: false, message: '', details: null },
    
    // Validation state
    errors: {},
    
    // Initialize component
    init() {
      this.loadSavedConfig();
    },
    
    // Toggle advanced options
    toggleAdvanced() {
      this.advancedOpen = !this.advancedOpen;
    },
    
    // Load saved configuration from localStorage
    loadSavedConfig() {
      try {
        const savedConfig = localStorage.getItem('onboardingConfig');
        if (savedConfig) {
          const config = JSON.parse(savedConfig);
          if (config && config.config) {
            this.coin = config.coin || '';
            this.rpcUrl = config.config.rpcUrl || '';
            this.network = config.config.network || 'mainnet';
            this.enabled = config.config.enabled !== false;
            this.minConfirmations = config.config.minConfirmations || 1;
            this.timeout = config.config.timeout || 30000;
          }
        }
      } catch (error) {
        console.error('Error loading config from localStorage:', error);
      }
    },
    
    // Validate form fields
    validate() {
      this.errors = {};
      
      if (!this.coin) {
        this.errors.coin = 'Please select a coin';
      }
      
      if (!this.rpcUrl) {
        this.errors.rpcUrl = 'RPC URL is required';
      } else if (!this.isValidUrl(this.rpcUrl)) {
        this.errors.rpcUrl = 'Please enter a valid URL';
      }
      
      if (!this.network) {
        this.errors.network = 'Please select a network';
      }
      
      if (this.minConfirmations < 0) {
        this.errors.minConfirmations = 'Minimum confirmations must be a positive number';
      }
      
      if (this.timeout < 1000) {
        this.errors.timeout = 'Timeout must be at least 1000ms';
      }
      
      return Object.keys(this.errors).length === 0;
    },
    
    // Check if string is a valid URL
    isValidUrl(string) {
      try {
        new URL(string);
        return true;
      } catch (_) {
        return false;
      }
    },
    
    // Submit form
    async submitForm() {
      if (!this.validate()) {
        // Focus the first field with an error
        const firstErrorField = Object.keys(this.errors)[0];
        if (firstErrorField) {
          document.getElementById(firstErrorField)?.focus();
        }
        return;
      }
      
      this.isSubmitting = true;
      this.result = { show: true, success: false, message: 'Processing your configuration...', details: null };
      
      try {
        // Prepare config object
        const config = {
          coin: this.coin,
          config: {
            rpcUrl: this.rpcUrl,
            network: this.network,
            enabled: this.enabled,
            minConfirmations: this.minConfirmations,
            timeout: this.timeout
          },
          createdAt: new Date().toISOString()
        };
        
        // Save to localStorage
        localStorage.setItem('onboardingConfig', JSON.stringify(config));
        
        // Submit to server
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
        
        const data = await response.json();
        
        if (data.success) {
          this.result = {
            show: true,
            success: true,
            message: `
              <strong>Success!</strong> Your ${this.coin} configuration has been saved.
              <p class="mt-2 mb-0">You can now use your wallet with the following settings:</p>
              <ul class="mt-1 mb-0">
                <li>Network: ${this.network}</li>
                <li>RPC URL: ${this.rpcUrl}</li>
                <li>Minimum Confirmations: ${this.minConfirmations}</li>
              </ul>
            `,
            details: null
          };
        } else {
          this.result = {
            show: true,
            success: false,
            message: `<strong>Error:</strong> ${data.error || 'Unknown error occurred'}`,
            details: data.details || null
          };
        }
      } catch (error) {
        this.result = {
          show: true,
          success: false,
          message: `<strong>Error:</strong> ${error.message || 'Failed to save configuration'}`,
          details: null
        };
      } finally {
        this.isSubmitting = false;
        
        // Scroll to result
        this.$nextTick(() => {
          document.getElementById('onboarding-result')?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        });
      }
    }
  }));
  
  // Feedback component
  Alpine.data('feedback', () => ({
    // Form state
    feedbackText: '',
    
    // UI state
    isSubmitting: false,
    result: { show: false, success: false, message: '' },
    
    // Validation state
    errors: {},
    
    // Validate form fields
    validate() {
      this.errors = {};
      
      if (!this.feedbackText.trim()) {
        this.errors.feedback = 'Please enter your feedback';
      }
      
      return Object.keys(this.errors).length === 0;
    },
    
    // Submit form
    async submitForm() {
      if (!this.validate()) {
        // Focus the feedback field if there's an error
        if (this.errors.feedback) {
          document.getElementById('feedback')?.focus();
        }
        return;
      }
      
      this.isSubmitting = true;
      this.result = { show: true, success: false, message: 'Submitting your feedback...' };
      
      try {
        // Prepare feedback data
        const feedbackData = {
          feedback: this.feedbackText,
          user: { 
            authenticated: true, 
            id: 'user-' + Math.random().toString(36).substring(2, 10) 
          }
        };
        
        // Submit to server
        const response = await fetch('/feedback', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Requested-With': 'XMLHttpRequest'
          },
          body: JSON.stringify(feedbackData)
        });
        
        if (!response.ok) {
          throw new Error(`Server responded with ${response.status}: ${response.statusText}`);
        }
        
        const data = await response.json();
        
        if (data.success) {
          this.result = {
            show: true,
            success: true,
            message: '<strong>Thank you!</strong> Your feedback has been submitted.'
          };
          
          // Clear form
          this.feedbackText = '';
        } else {
          this.result = {
            show: true,
            success: false,
            message: `<strong>Error:</strong> ${data.error || 'Unknown error occurred'}`
          };
        }
      } catch (error) {
        this.result = {
          show: true,
          success: false,
          message: `<strong>Error:</strong> ${error.message || 'Failed to submit feedback'}`
        };
      } finally {
        this.isSubmitting = false;
        
        // Scroll to result
        this.$nextTick(() => {
          document.getElementById('feedback-result')?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        });
      }
    }
  }));
  
  // Tab navigation component
  Alpine.data('tabs', () => ({
    // Current active tab
    activeTab: window.location.hash.substring(1) || 'onboarding',
    
    // Initialize component
    init() {
      // Listen for hash changes
      window.addEventListener('hashchange', () => {
        const hash = window.location.hash.substring(1);
        if (hash === 'onboarding' || hash === 'feedback') {
          this.switchTab(hash);
        }
      });
      
      // Announce initial tab for screen readers
      this.announceTabChange();
    },
    
    // Switch to a different tab
    switchTab(tabName) {
      if (tabName === 'onboarding' || tabName === 'feedback') {
        this.activeTab = tabName;
        window.location.hash = tabName;
        this.announceTabChange();
      }
    },
    
    // Announce tab change for screen readers
    announceTabChange() {
      const tabAnnouncement = document.getElementById('tab-announcement');
      if (tabAnnouncement) {
        tabAnnouncement.textContent = `Switched to ${this.activeTab} tab`;
      }
    }
  }));
});