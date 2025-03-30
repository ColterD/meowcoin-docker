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