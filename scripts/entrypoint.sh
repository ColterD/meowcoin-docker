#!/bin/bash
set -e

# Source helper functions
source /scripts/functions.sh

# Display banner
display_banner "🐱 Meowcoin Node"
echo "Version: $(get_version)"
echo "----------------------------------------"

# Create data directories
mkdir -p "${MEOWCOIN_DATA}"
mkdir -p "${MEOWCOIN_CONFIG}"
mkdir -p "${MEOWCOIN_DATA}/.meowcoin"

# Check if we're handling a command
if [ "$1" = "cli" ]; then
  shift
  exec gosu meowcoin /usr/local/bin/meowcoin-cli -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" "$@"
elif [ "$1" = "shell" ]; then
  exec /bin/bash
elif [ "$1" = "help" ]; then
  display_help
  exit 0
else
  # Auto-configure settings based on system resources
  /scripts/auto-configure.sh
  
  # Check for custom config and apply if exists
  apply_custom_config
  
  # Verify meowcoind exists and is executable
  if [ ! -f "/usr/local/bin/meowcoind" ]; then
    log_error "CRITICAL ERROR: Meowcoin daemon not found at /usr/local/bin/meowcoind"
    log_error "Available files in /usr/local/bin:"
    ls -la /usr/local/bin
    exit 1
  fi
  
  if [ ! -x "/usr/local/bin/meowcoind" ]; then
    log_error "CRITICAL ERROR: Meowcoin daemon is not executable"
    log_error "Trying to fix permissions..."
    chmod +x /usr/local/bin/meowcoind
    if [ ! -x "/usr/local/bin/meowcoind" ]; then
      log_error "Failed to make daemon executable. Exiting."
      exit 1
    fi
  fi
  
  # Ensure web files are present and accessible
  log_info "Checking web files..."
  if [ ! -f "/var/www/html/index.html" ]; then
    log_info "Web files missing, creating minimal dashboard..."
    mkdir -p /var/www/html/css /var/www/html/js /var/www/html/api
    
    # Create a minimal index.html
    cat > /var/www/html/index.html << 'EOFHTML'
<!DOCTYPE html>
<html lang="en" data-theme="auto">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Meowcoin Node Dashboard</title>
    <link rel="stylesheet" href="css/main.css">
</head>
<body>
    <div class="container">
        <header>
            <div class="logo">🐱</div>
            <h1>Meowcoin Node Dashboard</h1>
        </header>
        
        <main>
            <section class="status-card">
                <h2>Node Status</h2>
                <div class="status-indicator">
                    <span id="status-light" class="status-light"></span>
                    <span id="status-text">Loading...</span>
                </div>
                <div id="version-update-alert" class="version-update-alert">
                    <p>New version available!</p>
                    <button id="update-available-btn" class="btn btn-primary">Update</button>
                </div>
                <div class="info-grid">
                    <div class="info-item">
                        <h3>Version</h3>
                        <p><a id="version" href="#" target="_blank">-</a></p>
                    </div>
                    <div class="info-item">
                        <h3>Connections</h3>
                        <p id="connections">-</p>
                    </div>
                    <div class="info-item">
                        <h3>Blocks</h3>
                        <p id="blocks">-</p>
                    </div>
                    <div class="info-item">
                        <h3>Sync Progress</h3>
                        <p id="progress">-</p>
                    </div>
                </div>
                <div class="info-grid" style="margin-top: 20px;">
                    <div class="info-item">
                        <h3>Network Download</h3>
                        <p id="network-down">-</p>
                    </div>
                    <div class="info-item">
                        <h3>Network Upload</h3>
                        <p id="network-up">-</p>
                    </div>
                    <div class="info-item">
                        <h3>Total Downloaded</h3>
                        <p id="total-received">-</p>
                    </div>
                    <div class="info-item">
                        <h3>Total Uploaded</h3>
                        <p id="total-sent">-</p>
                    </div>
                </div>
                <div class="control-buttons">
                    <button id="restart-btn" class="btn btn-warning">Restart Node</button>
                    <button id="shutdown-btn" class="btn btn-danger">Shutdown Node</button>
                </div>
            </section>
            
            <section class="status-card">
                <h2>System Resources</h2>
                <div class="info-grid">
                    <div class="info-item">
                        <h3>Memory Usage</h3>
                        <div class="progress-bar">
                            <div id="memory-bar" class="progress" style="width: 0%"></div>
                        </div>
                        <p id="memory-text">-</p>
                    </div>
                    <div class="info-item">
                        <h3>Disk Usage</h3>
                        <div class="progress-bar">
                            <div id="disk-bar" class="progress" style="width: 0%"></div>
                        </div>
                        <p id="disk-text">-</p>
                    </div>
                </div>
            </section>
            
            <section class="status-card" id="disk-usage-section">
                <h2>Disk Usage Details</h2>
                <div id="disk-usage-details">Loading detailed disk usage...</div>
            </section>
            
            <section class="status-card" id="console-section">
                <div class="section-header">
                    <h2>Node Console</h2>
                    <button id="console-toggle" class="toggle-btn">
                        <span class="toggle-icon">▼</span>
                    </button>
                </div>
                <div class="console-container">
                    <div id="console-output" class="console-output"></div>
                </div>
            </section>
        </main>
        
        <footer>
            <div class="footer-content">
                <p>Last updated: <span id="last-updated">-</span></p>
                <div class="refresh-timer">
                    <div class="progress-bar">
                        <div id="refresh-timer-bar" class="progress" style="width: 100%"></div>
                    </div>
                    <span id="refresh-timer-text">30s</span>
                </div>
            </div>
        </footer>
    </div>
    
    <!-- Settings Panel -->
    <button class="settings-toggle" id="settings-toggle">⚙️</button>
    
    <div class="settings-panel" id="settings-panel">
        <div class="settings-header">
            <h2>Settings</h2>
            <button class="settings-close" id="settings-close">×</button>
        </div>
        
        <div class="settings-group">
            <h3>Display</h3>
            <div class="settings-item">
                <label for="theme-select">Theme</label>
                <select id="theme-select">
                    <option value="light">Light</option>
                    <option value="dark">Dark</option>
                    <option value="auto">Auto (System)</option>
                </select>
            </div>
            <div class="settings-item">
                <label for="refresh-interval">Refresh Interval (seconds)</label>
                <input type="number" id="refresh-interval" min="5" max="300" value="30">
            </div>
        </div>
        
        <div class="settings-group">
            <h3>Node Configuration</h3>
            <div class="settings-item">
                <label for="max-connections">Max Connections</label>
                <input type="number" id="max-connections" min="1" max="125">
            </div>
            <div class="settings-item">
                <label for="enable-txindex">Enable Transaction Index</label>
                <select id="enable-txindex">
                    <option value="1">Yes</option>
                    <option value="0">No</option>
                </select>
            </div>
        </div>
        
        <div class="settings-group">
            <button id="save-settings" class="btn btn-primary">Save Settings</button>
        </div>
    </div>
    
    <script src="js/dashboard.js"></script>
</body>
</html>
EOFHTML
    
    # Create CSS file
    cat > /var/www/html/css/main.css << 'EOFCSS'
:root {
    /* Light theme (default) */
    --primary-color: #4e54c8;
    --secondary-color: #8f94fb;
    --success-color: #4CAF50;
    --warning-color: #FF9800;
    --danger-color: #F44336;
    --text-color: #333;
    --bg-color: #f5f7fa;
    --card-bg: #fff;
    --border-color: #e0e0e0;
    --header-color: #4e54c8;
    --console-bg: #1e1e1e;
    --console-text: #f0f0f0;
}

[data-theme="dark"] {
    --primary-color: #6c71e0;
    --secondary-color: #9c9ff7;
    --success-color: #66BB6A;
    --warning-color: #FFA726;
    --danger-color: #EF5350;
    --text-color: #e0e0e0;
    --bg-color: #1a1a1a;
    --card-bg: #2d2d2d;
    --border-color: #444444;
    --header-color: #6c71e0;
    --console-bg: #1e1e1e;
    --console-text: #f0f0f0;
}

* {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
}

body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    line-height: 1.6;
    color: var(--text-color);
    background: var(--bg-color);
    padding: 20px;
    transition: background-color 0.3s ease, color 0.3s ease;
}

.container {
    max-width: 1000px;
    margin: 0 auto;
}

header {
    display: flex;
    align-items: center;
    margin-bottom: 30px;
    padding-bottom: 20px;
    border-bottom: 1px solid var(--border-color);
}

.logo {
    font-size: 40px;
    margin-right: 15px;
}

h1 {
    color: var(--header-color);
    font-size: 28px;
    font-weight: 500;
}

h2 {
    font-size: 20px;
    margin-bottom: 20px;
    color: var(--primary-color);
    font-weight: 500;
}

h3 {
    font-size: 16px;
    font-weight: 500;
    margin-bottom: 8px;
    color: var(--text-color);
}

.status-card {
    background: var(--card-bg);
    border-radius: 8px;
    padding: 20px;
    margin-bottom: 20px;
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.05);
    transition: background-color 0.3s ease, box-shadow 0.3s ease;
}

.section-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;
}

.toggle-btn {
    background: none;
    border: none;
    color: var(--primary-color);
    font-size: 16px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 5px;
    border-radius: 4px;
    transition: background-color 0.2s;
}

.toggle-btn:hover {
    background-color: rgba(0, 0, 0, 0.05);
}

[data-theme="dark"] .toggle-btn:hover {
    background-color: rgba(255, 255, 255, 0.05);
}

.toggle-icon {
    font-size: 12px;
    transition: transform 0.3s;
}

#console-section.collapsed .toggle-icon {
    transform: rotate(-90deg);
}

.console-container {
    transition: max-height 0.3s ease, opacity 0.3s;
    max-height: 400px;
    opacity: 1;
    overflow: hidden;
}

#console-section.collapsed .console-container {
    max-height: 0;
    opacity: 0;
    margin-top: 0;
}

.console-output {
    background-color: var(--console-bg);
    color: var(--console-text);
    font-family: monospace;
    padding: 15px;
    border-radius: 4px;
    height: 300px;
    overflow-y: auto;
    white-space: pre-wrap;
    font-size: 12px;
    line-height: 1.4;
}

.console-line {
    margin-bottom: 2px;
}

.status-indicator {
    display: flex;
    align-items: center;
    margin-bottom: 20px;
}

.status-light {
    width: 15px;
    height: 15px;
    border-radius: 50%;
    margin-right: 10px;
    background-color: #ccc;
}

.status-light.running {
    background-color: var(--success-color);
}

.status-light.syncing {
    background-color: var(--warning-color);
}

.status-light.error, .status-light.stopped {
    background-color: var(--danger-color);
}

.info-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 20px;
}

.info-item {
    background: rgba(0, 0, 0, 0.02);
    padding: 15px;
    border-radius: 5px;
    transition: background-color 0.3s ease;
}

[data-theme="dark"] .info-item {
    background: rgba(255, 255, 255, 0.05);
}

.progress-bar {
    height: 10px;
    background-color: #eee;
    border-radius: 5px;
    overflow: hidden;
    margin-bottom: 10px;
}

[data-theme="dark"] .progress-bar {
    background-color: #444;
}

.progress {
    height: 100%;
    background-color: var(--secondary-color);
    transition: width 0.3s ease;
}

footer {
    margin-top: 30px;
    color: #666;
    font-size: 14px;
}

.footer-content {
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.refresh-timer {
    display: flex;
    align-items: center;
    gap: 10px;
    width: 200px;
}

.refresh-timer .progress-bar {
    flex-grow: 1;
    margin-bottom: 0;
}

.refresh-timer-text {
    min-width: 30px;
    text-align: right;
}

[data-theme="dark"] footer {
    color: #999;
}

/* Version update alert */
.version-update-alert {
    display: none;
    background-color: var(--warning-color);
    color: white;
    padding: 10px 15px;
    border-radius: 5px;
    margin-bottom: 20px;
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.version-update-alert p {
    margin: 0;
    font-weight: 500;
}

.version-update-alert .btn {
    margin-left: 15px;
    background-color: white;
    color: var(--warning-color);
}

/* Settings panel */
.settings-panel {
    position: fixed;
    top: 0;
    right: -350px;
    width: 350px;
    height: 100%;
    background: var(--card-bg);
    box-shadow: -2px 0 10px rgba(0, 0, 0, 0.1);
    z-index: 1000;
    transition: right 0.3s ease;
    overflow-y: auto;
    padding: 20px;
}

.settings-panel.open {
    right: 0;
}

.settings-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;
    padding-bottom: 10px;
    border-bottom: 1px solid var(--border-color);
}

.settings-close {
    background: none;
    border: none;
    font-size: 24px;
    cursor: pointer;
    color: var(--text-color);
}

.settings-group {
    margin-bottom: 20px;
}

.settings-item {
    margin-bottom: 15px;
}

.settings-item label {
    display: block;
    margin-bottom: 5px;
    font-weight: 500;
}

.settings-item select,
.settings-item input {
    width: 100%;
    padding: 8px 10px;
    border: 1px solid var(--border-color);
    border-radius: 4px;
    background-color: var(--bg-color);
    color: var(--text-color);
}

.settings-toggle {
    position: fixed;
    bottom: 20px;
    right: 20px;
    width: 50px;
    height: 50px;
    border-radius: 50%;
    background-color: var(--primary-color);
    color: white;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 24px;
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.2);
    cursor: pointer;
    border: none;
    z-index: 999;
}

.settings-toggle:hover {
    transform: scale(1.05);
}

/* Control buttons */
.control-buttons {
    display: flex;
    gap: 10px;
    margin-top: 15px;
}

.btn {
    padding: 8px 15px;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-weight: 500;
    transition: background-color 0.2s;
}

.btn-primary {
    background-color: var(--primary-color);
    color: white;
}

.btn-warning {
    background-color: var(--warning-color);
    color: white;
}

.btn-danger {
    background-color: var(--danger-color);
    color: white;
}

.btn:hover {
    opacity: 0.9;
}

/* Disk usage details */
#disk-usage-details {
    font-family: monospace;
    white-space: pre-wrap;
    line-height: 1.5;
    font-size: 14px;
    max-height: 400px;
    overflow-y: auto;
}

.disk-usage-item {
    display: flex;
    justify-content: space-between;
    margin-bottom: 8px;
    padding-bottom: 8px;
    border-bottom: 1px solid var(--border-color);
}

.disk-usage-path {
    flex-grow: 1;
    padding-right: 10px;
    overflow: hidden;
    text-overflow: ellipsis;
}

.disk-usage-size {
    font-weight: bold;
    min-width: 90px;
    text-align: right;
}

@media (max-width: 600px) {
    .info-grid {
        grid-template-columns: 1fr;
    }
    
    header {
        flex-direction: column;
        text-align: center;
    }
    
    .logo {
        margin-right: 0;
        margin-bottom: 10px;
    }

    .settings-panel {
        width: 100%;
        right: -100%;
    }
    
    .footer-content {
        flex-direction: column;
        gap: 10px;
    }
    
    .refresh-timer {
        width: 100%;
    }
}
EOFCSS

    # Create JS file
    cat > /var/www/html/js/dashboard.js << 'EOFJS'
document.addEventListener('DOMContentLoaded', function() {
  // Elements
  const statusLight = document.getElementById('status-light');
  const statusText = document.getElementById('status-text');
  const versionEl = document.getElementById('version');
  const connectionsEl = document.getElementById('connections');
  const blocksEl = document.getElementById('blocks');
  const progressEl = document.getElementById('progress');
  const networkDownEl = document.getElementById('network-down');
  const networkUpEl = document.getElementById('network-up');
  const totalReceivedEl = document.getElementById('total-received');
  const totalSentEl = document.getElementById('total-sent');
  const memoryBarEl = document.getElementById('memory-bar');
  const memoryTextEl = document.getElementById('memory-text');
  const diskBarEl = document.getElementById('disk-bar');
  const diskTextEl = document.getElementById('disk-text');
  const lastUpdatedEl = document.getElementById('last-updated');
  const restartBtn = document.getElementById('restart-btn');
  const shutdownBtn = document.getElementById('shutdown-btn');
  const settingsToggle = document.getElementById('settings-toggle');
  const settingsPanel = document.getElementById('settings-panel');
  const settingsClose = document.getElementById('settings-close');
  const themeSelect = document.getElementById('theme-select');
  const refreshIntervalInput = document.getElementById('refresh-interval');
  const maxConnectionsInput = document.getElementById('max-connections');
  const enableTxindexSelect = document.getElementById('enable-txindex');
  const saveSettingsBtn = document.getElementById('save-settings');
  const refreshTimerBar = document.getElementById('refresh-timer-bar');
  const refreshTimerText = document.getElementById('refresh-timer-text');
  const versionUpdateAlert = document.getElementById('version-update-alert');
  const updateAvailableBtn = document.getElementById('update-available-btn');
  const consoleOutput = document.getElementById('console-output');
  const consoleToggle = document.getElementById('console-toggle');
  const consoleSection = document.getElementById('console-section');
  
  // Status mapping
  const statusMap = {
    'running': { text: 'Running', class: 'running' },
    'syncing': { text: 'Syncing', class: 'syncing' },
    'stopped': { text: 'Stopped', class: 'stopped' },
    'no_connections': { text: 'No Connections', class: 'error' },
    'starting': { text: 'Starting', class: '' }
  };
  
  // Track network stats for calculating speeds
  let lastBytesReceived = 0;
  let lastBytesSent = 0;
  let lastStatsTime = Date.now();
  
  // Settings and theme handling
  let settings = {
    theme: 'auto', // Default to auto theme
    refreshInterval: 30, // Default to 30 seconds
    maxConnections: 50,
    enableTxindex: 1,
    settingsPanelOpen: false, // Track if settings panel is open
    consoleExpanded: true, // Track if console is expanded
    lastLogTimestamp: 0 // Track last fetched log timestamp
  };

  // Refresh timer variables
  let refreshTimerInterval;
  let refreshCountdown = 0;
  let refreshTimeout;
  
  // Initialize settings
  function initSettings() {
    // Load settings from localStorage
    const savedSettings = localStorage.getItem('meowcoin-settings');
    if (savedSettings) {
      settings = { ...settings, ...JSON.parse(savedSettings) };
    }
    
    // Apply settings to form elements
    themeSelect.value = settings.theme;
    refreshIntervalInput.value = settings.refreshInterval;
    maxConnectionsInput.value = settings.maxConnections;
    enableTxindexSelect.value = settings.enableTxindex;
    
    // Apply theme
    applyTheme(settings.theme);
    
    // Set refresh timer
    startRefreshTimer(settings.refreshInterval);
    
    // If settings panel was open before, reopen it
    if (settings.settingsPanelOpen) {
      settingsPanel.classList.add('open');
    }
    
    // Set console expanded state
    if (!settings.consoleExpanded) {
      consoleSection.classList.add('collapsed');
    }
  }
  
  // Apply theme based on setting
  function applyTheme(theme) {
    if (theme === 'auto') {
      // Check system preference
      if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
        document.documentElement.setAttribute('data-theme', 'dark');
      } else {
        document.documentElement.setAttribute('data-theme', 'light');
      }
      
      // Listen for changes
      window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', e => {
        if (settings.theme === 'auto') {
          document.documentElement.setAttribute('data-theme', e.matches ? 'dark' : 'light');
        }
      });
    } else {
      document.documentElement.setAttribute('data-theme', theme);
    }
  }
  
  // Start the refresh timer display
  function startRefreshTimer(seconds) {
    // Clear any existing interval and timeout
    if (refreshTimerInterval) {
      clearInterval(refreshTimerInterval);
    }
    if (refreshTimeout) {
      clearTimeout(refreshTimeout);
    }
    
    refreshCountdown = seconds;
    updateRefreshTimerDisplay();
    
    refreshTimerInterval = setInterval(() => {
      refreshCountdown--;
      
      if (refreshCountdown <= 0) {
        clearInterval(refreshTimerInterval);
        refreshCountdown = seconds;
      }
      
      updateRefreshTimerDisplay();
    }, 1000);
    
    // Set timeout for next data refresh
    refreshTimeout = setTimeout(() => {
      updateDashboard();
    }, seconds * 1000);
  }
  
  // Update the refresh timer display
  function updateRefreshTimerDisplay() {
    if (!refreshTimerBar || !refreshTimerText) return;
    
    const percentage = (refreshCountdown / settings.refreshInterval) * 100;
    refreshTimerBar.style.width = `${percentage}%`;
    refreshTimerText.textContent = `${refreshCountdown}s`;
  }
  
  // Format version properly for Meowcoin format (e.g., "Meow-2.0.5")
  function formatVersion(version) {
    if (!version) return 'Unknown';
    
    // If already in correct format like "Meow-v2.0.5", return it
    if (version.includes('Meow-')) {
      return version;
    }
    
    // If it's a numeric format like 200500
    if (/^\d+$/.test(version)) {
      const major = parseInt(version.slice(0, -4)) || 0;
      const minor = parseInt(version.slice(-4, -2)) || 0;
      const patch = parseInt(version.slice(-2)) || 0;
      return `Meow-${major}.${minor}.${patch}`;
    }
    
    // If it's already in semver format like "v2.0.5.0"
    if (version.startsWith('v')) {
      const parts = version.substring(1).split('.');
      return `Meow-${parts[0]}.${parts[1]}.${parts[2]}`;
    }
    
    return version;
  }
  
  // Check for version updates
  async function checkForVersionUpdate(currentVersion) {
    try {
      // Extract version without any extra text (e.g., Meow-2.0.5 to 2.0.5)
      const cleanVersion = currentVersion.replace(/^Meow-/, '').split('.').slice(0, 3).join('.');
      
      // Fetch the latest release from GitHub
      const response = await fetch('https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/tags');
      if (!response.ok) {
        throw new Error('Failed to fetch latest version');
      }
      
      const tags = await response.json();
      if (!tags || !tags.length) {
        throw new Error('No tags found');
      }
      
      // Sort tags by name to find the latest (assuming semantic versioning)
      const sortedTags = tags.sort((a, b) => {
        const aVersion = a.name.replace(/^Meow-/, '').split('.').map(n => parseInt(n));
        const bVersion = b.name.replace(/^Meow-/, '').split('.').map(n => parseInt(n));
        
        for (let i = 0; i < Math.max(aVersion.length, bVersion.length); i++) {
          const aNum = aVersion[i] || 0;
          const bNum = bVersion[i] || 0;
          if (aNum !== bNum) {
            return bNum - aNum; // Descending order for latest first
          }
        }
        return 0;
      });
      
      const latestTag = sortedTags[0];
      const latestVersion = latestTag.name.replace(/^Meow-/, '').split('.').slice(0, 3).join('.');
      
      // Compare versions
      if (compareVersions(latestVersion, cleanVersion) > 0) {
        // Update available
        versionUpdateAlert.style.display = 'block';
        updateAvailableBtn.setAttribute('data-version', latestTag.name);
        updateAvailableBtn.textContent = `Update to ${latestTag.name}`;
        
        // Store in localStorage to persist across refreshes
        localStorage.setItem('meowcoin-latest-version', latestTag.name);
      } else {
        versionUpdateAlert.style.display = 'none';
        localStorage.removeItem('meowcoin-latest-version');
      }
    } catch (error) {
      console.error('Error checking for updates:', error);
    }
  }
  
  // Compare semver versions
  function compareVersions(a, b) {
    const aParts = a.split('.').map(Number);
    const bParts = b.split('.').map(Number);
    
    for (let i = 0; i < Math.max(aParts.length, bParts.length); i++) {
      const aVal = aParts[i] || 0;
      const bVal = bParts[i] || 0;
      
      if (aVal > bVal) return 1;
      if (aVal < bVal) return -1;
    }
    
    return 0;
  }
  
  // Save settings
  function saveSettings() {
    settings.theme = themeSelect.value;
    settings.refreshInterval = parseInt(refreshIntervalInput.value);
    settings.maxConnections = parseInt(maxConnectionsInput.value);
    settings.enableTxindex = parseInt(enableTxindexSelect.value);
    settings.settingsPanelOpen = settingsPanel.classList.contains('open');
    
    // Save to localStorage
    localStorage.setItem('meowcoin-settings', JSON.stringify(settings));
    
    // Apply settings
    applyTheme(settings.theme);
    
    // Restart refresh timer with new interval
    startRefreshTimer(settings.refreshInterval);
    
    // Save to server
    saveSettingsToServer();
    
    // Notify user
    alert('Settings saved successfully!');
  }
  
  // Save settings to server
  function saveSettingsToServer() {
    fetch('/api/save-settings', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        maxConnections: settings.maxConnections,
        enableTxindex: settings.enableTxindex
      })
    })
    .then(response => response.json())
    .then(data => {
      console.log('Settings saved to server:', data);
    })
    .catch(error => {
      console.error('Error saving settings:', error);
    });
  }
  
  // Format bytes to human readable format
  function formatBytes(bytes, decimals = 2) {
    if (bytes === 0) return '0 B';
    
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
    
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
  }
  
  // Format bytes/second to human readable format
  function formatBytesPerSecond(bytesPerSecond) {
    return formatBytes(bytesPerSecond) + '/s';
  }
  
  // Function to update the dashboard
  function updateDashboard() {
    fetch('/api/status.json?_=' + new Date().getTime())
      .then(response => response.json())
      .then(data => {
        // Update status
        const status = data.status || 'starting';
        const statusInfo = statusMap[status] || { text: 'Unknown', class: '' };
        
        statusLight.className = 'status-light ' + statusInfo.class;
        statusText.textContent = statusInfo.text;
        
        // Update blockchain info
        if (data.blockchain) {
          blocksEl.textContent = data.blockchain.blocks;
          progressEl.textContent = data.blockchain.progress + '%';
        }
        
        // Update node info
        if (data.node) {
          // Version with link to GitHub
          const rawVersion = data.node.version || 'Unknown';
          const formattedVersion = formatVersion(rawVersion);
          versionEl.textContent = formattedVersion;
          versionEl.href = `https://github.com/Meowcoin-Foundation/Meowcoin/tags`;
          
          // Check for updates
          checkForVersionUpdate(formattedVersion);
          
          connectionsEl.textContent = data.node.connections;
          
          // Update total network stats
          if (data.node.bytesReceived !== undefined && data.node.bytesSent !== undefined) {
            // Update total received/sent
            totalReceivedEl.textContent = formatBytes(data.node.bytesReceived);
            totalSentEl.textContent = formatBytes(data.node.bytesSent);
            
            // Calculate network speeds
            const now = Date.now();
            const timeDiffInSeconds = (now - lastStatsTime) / 1000;
            
            if (lastBytesReceived > 0 && lastBytesSent > 0 && timeDiffInSeconds > 0) {
              const receivedDiff = data.node.bytesReceived - lastBytesReceived;
              const sentDiff = data.node.bytesSent - lastBytesSent;
              
              const downloadSpeed = receivedDiff / timeDiffInSeconds;
              const uploadSpeed = sentDiff / timeDiffInSeconds;
              
              networkDownEl.textContent = formatBytesPerSecond(downloadSpeed);
              networkUpEl.textContent = formatBytesPerSecond(uploadSpeed);
            }
            
            lastBytesReceived = data.node.bytesReceived;
            lastBytesSent = data.node.bytesSent;
            lastStatsTime = now;
          }
        }
        
        // Update system info
        if (data.system) {
          // Memory
          const memPercent = parseFloat(data.system.memory.percent);
          memoryBarEl.style.width = memPercent + '%';
          memoryTextEl.textContent = `${data.system.memory.used}MB / ${data.system.memory.total}MB (${memPercent}%)`;
          
          // Disk
          const diskPercent = parseFloat(data.system.disk.percent);
          diskBarEl.style.width = diskPercent + '%';
          diskTextEl.textContent = `${data.system.disk.used} / ${data.system.disk.size} (${diskPercent}%)`;
          
          // Set warning colors
          if (memPercent > 90) {
            memoryBarEl.style.backgroundColor = 'var(--danger-color)';
          } else if (memPercent > 70) {
            memoryBarEl.style.backgroundColor = 'var(--warning-color)';
          } else {
            memoryBarEl.style.backgroundColor = 'var(--secondary-color)';
          }
          
          if (diskPercent > 90) {
            diskBarEl.style.backgroundColor = 'var(--danger-color)';
          } else if (diskPercent > 70) {
            diskBarEl.style.backgroundColor = 'var(--warning-color)';
          } else {
            diskBarEl.style.backgroundColor = 'var(--secondary-color)';
          }
        }
        
        // Update timestamp
        if (data.updated) {
          lastUpdatedEl.textContent = data.updated;
        } else {
          lastUpdatedEl.textContent = new Date().toLocaleString();
        }
        
        // Update settings if available
        if (data.settings) {
          maxConnectionsInput.value = data.settings.maxConnections || 50;
          enableTxindexSelect.value = data.settings.enableTxindex || 1;
        }
        
        // Reset refresh timer
        startRefreshTimer(settings.refreshInterval);
        
        // Fetch disk usage details
        fetchDiskUsageDetails();
        
        // Fetch console logs
        fetchConsoleLogs();
      })
      .catch(error => {
        console.error('Error fetching status:', error);
        statusText.textContent = 'Error';
        statusLight.className = 'status-light error';
        
        // Retry after interval
        startRefreshTimer(settings.refreshInterval);
      });
  }
  
  // Function to fetch console logs
  function fetchConsoleLogs() {
    fetch('/api/logs?since=' + settings.lastLogTimestamp)
      .then(response => response.json())
      .then(data => {
        if (data.success && data.logs) {
          // Update console output
          if (data.logs.length > 0) {
            // Update timestamp for next fetch
            settings.lastLogTimestamp = data.timestamp || Date.now();
            
            // Append logs to console
            appendConsoleLogs(data.logs);
            
            // Save to localStorage
            localStorage.setItem('meowcoin-settings', JSON.stringify(settings));
          }
        }
      })
      .catch(error => {
        console.error('Error fetching console logs:', error);
      });
  }
  
  // Function to append console logs
  function appendConsoleLogs(logs) {
    if (!consoleOutput) return;
    
    // Get current scroll position
    const isScrolledToBottom = consoleOutput.scrollHeight - consoleOutput.clientHeight <= consoleOutput.scrollTop + 1;
    
    // Append logs
    logs.forEach(log => {
      const logElement = document.createElement('div');
      logElement.className = 'console-line';
      logElement.textContent = log;
      consoleOutput.appendChild(logElement);
    });
    
    // Limit number of lines (keep the most recent 500)
    while (consoleOutput.childElementCount > 500) {
      consoleOutput.removeChild(consoleOutput.firstChild);
    }
    
    // Auto-scroll if was at bottom before adding lines
    if (isScrolledToBottom) {
      consoleOutput.scrollTop = consoleOutput.scrollHeight;
    }
  }
  
  // Function to fetch detailed disk usage
  function fetchDiskUsageDetails() {
    fetch('/api/disk-usage?_=' + new Date().getTime())
      .then(response => response.json())
      .then(data => {
        updateDiskUsageDetails(data);
      })
      .catch(error => {
        console.error('Error fetching disk usage details:', error);
        const diskUsageDetails = document.getElementById('disk-usage-details');
        if (diskUsageDetails) {
          diskUsageDetails.textContent = 'Error loading disk usage details. Please try again later.';
        }
      });
  }
  
  // Function to update disk usage details display
  function updateDiskUsageDetails(data) {
    const diskUsageDetails = document.getElementById('disk-usage-details');
    if (!diskUsageDetails) return;
    
    if (!data || !data.paths) {
      diskUsageDetails.textContent = 'No disk usage details available.';
      return;
    }
    
    let html = '<div class="disk-usage-list">';
    
    // Sort paths by size (largest first)
    const sortedPaths = [...data.paths].sort((a, b) => b.sizeBytes - a.sizeBytes);
    
    for (const item of sortedPaths) {
      html += `
        <div class="disk-usage-item">
          <div class="disk-usage-path">${item.path}</div>
          <div class="disk-usage-size">${formatBytes(item.sizeBytes)}</div>
        </div>
      `;
    }
    
    html += '</div>';
    diskUsageDetails.innerHTML = html;
  }
  
  // Function to update node
  function updateNode() {
    const version = updateAvailableBtn.getAttribute('data-version');
    if (!version) return;
    
    if (confirm(`Are you sure you want to update to ${version}?`)) {
      fetch('/api/update', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ version: version })
      })
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          alert('Update initiated. The node will restart when the update is complete.');
        } else {
          alert('Failed to update: ' + data.message);
        }
      })
      .catch(error => {
        console.error('Error updating node:', error);
        alert('Error updating node. Check the console for details.');
      });
    }
  }
  
  // Function to toggle console section
  function toggleConsoleSection() {
    if (consoleSection.classList.contains('collapsed')) {
      consoleSection.classList.remove('collapsed');
      settings.consoleExpanded = true;
    } else {
      consoleSection.classList.add('collapsed');
      settings.consoleExpanded = false;
    }
    
    // Save state to localStorage
    localStorage.setItem('meowcoin-settings', JSON.stringify(settings));
  }
  
  // Control functions
  function restartNode() {
    if (confirm('Are you sure you want to restart the Meowcoin node?')) {
      fetch('/api/control', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ action: 'restart' })
      })
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          alert('Node restart initiated. The dashboard will reconnect when the node is back online.');
        } else {
          alert('Failed to restart node: ' + data.message);
        }
      })
      .catch(error => {
        console.error('Error restarting node:', error);
        alert('Error restarting node. Check the console for details.');
      });
    }
  }
  
  function shutdownNode() {
    if (confirm('Are you sure you want to shutdown the Meowcoin node?')) {
      fetch('/api/control', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ action: 'shutdown' })
      })
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          alert('Node shutdown initiated. You will need to restart the container manually.');
        } else {
          alert('Failed to shutdown node: ' + data.message);
        }
      })
      .catch(error => {
        console.error('Error shutting down node:', error);
        alert('Error shutting down node. Check the console for details.');
      });
    }
  }
  
  // Event Listeners
  if (settingsToggle) {
    settingsToggle.addEventListener('click', function() {
      settingsPanel.classList.add('open');
      // Save panel state
      settings.settingsPanelOpen = true;
      localStorage.setItem('meowcoin-settings', JSON.stringify(settings));
    });
  }
  
  if (settingsClose) {
    settingsClose.addEventListener('click', function() {
      settingsPanel.classList.remove('open');
      // Save panel state
      settings.settingsPanelOpen = false;
      localStorage.setItem('meowcoin-settings', JSON.stringify(settings));
    });
  }
  
  if (themeSelect) {
    themeSelect.addEventListener('change', function() {
      applyTheme(this.value);
    });
  }
  
  if (refreshIntervalInput) {
    refreshIntervalInput.addEventListener('change', function() {
      const value = parseInt(this.value);
      if (value < 5) this.value = 5;
      if (value > 300) this.value = 300; // Max 5 minutes
    });
  }
  
  if (saveSettingsBtn) {
    saveSettingsBtn.addEventListener('click', saveSettings);
  }
  
  if (restartBtn) {
    restartBtn.addEventListener('click', restartNode);
  }
  
  if (shutdownBtn) {
    shutdownBtn.addEventListener('click', shutdownNode);
  }
  
  if (updateAvailableBtn) {
    updateAvailableBtn.addEventListener('click', updateNode);
  }
  
  if (consoleToggle) {
    consoleToggle.addEventListener('click', toggleConsoleSection);
  }
  
  // Store settings panel state when page is about to unload
  window.addEventListener('beforeunload', function() {
    settings.settingsPanelOpen = settingsPanel.classList.contains('open');
    localStorage.setItem('meowcoin-settings', JSON.stringify(settings));
  });
  
  // Initialize settings
  initSettings();
  
  // Initial update
  updateDashboard();
  
  // Check for stored update notice
  const storedLatestVersion = localStorage.getItem('meowcoin-latest-version');
  if (storedLatestVersion) {
    versionUpdateAlert.style.display = 'block';
    updateAvailableBtn.setAttribute('data-version', storedLatestVersion);
    updateAvailableBtn.textContent = `Update to ${storedLatestVersion}`;
  }
});
EOFJS
  }
  
  # Make sure files have proper permissions
  chmod -R 755 /var/www/html
  chown -R meowcoin:meowcoin /var/www/html
  
  # Create empty API status file
  mkdir -p /var/www/html/api
  echo '{"status":"starting"}' > /var/www/html/api/status.json
  chmod 644 /var/www/html/api/status.json
  chown meowcoin:meowcoin /var/www/html/api/status.json
  
  log_info "Web files created and verified"
  
  # Start the monitoring processes
  /scripts/node-monitor.sh &
  MONITOR_PID=$!
  
  # Start the web API service
  /scripts/web-api.sh &
  WEB_API_PID=$!
  
  # Start backup manager if enabled
  if [ "$BACKUP_ENABLED" = "true" ]; then
    /scripts/backup-manager.sh &
    BACKUP_PID=$!
  fi
  
  # Start the web server
  setup_web_server
  nginx &
  NGINX_PID=$!
  
  # Display access information
  display_access_info
  
  # Handle signals
  trap handle_shutdown SIGTERM SIGINT
  
  # Start Meowcoin daemon
  echo "Starting Meowcoin daemon..."
  gosu meowcoin /usr/local/bin/meowcoind -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" || {
    log_error "Failed to start Meowcoin daemon. Exit code: $?"
    log_error "Daemon output:"
    gosu meowcoin /usr/local/bin/meowcoind --version
    exit 1
  }
  
  # If we get here, the daemon exited, so clean up
  kill $MONITOR_PID 2>/dev/null || true
  kill $WEB_API_PID 2>/dev/null || true
  kill $NGINX_PID 2>/dev/null || true
  if [ -n "$BACKUP_PID" ]; then
    kill $BACKUP_PID 2>/dev/null || true
  fi
fi