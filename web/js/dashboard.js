document.addEventListener('DOMContentLoaded', function() {
    // Elements
    const statusLight = document.getElementById('status-light');
    const statusText = document.getElementById('status-text');
    const versionEl = document.getElementById('version');
    const connectionsEl = document.getElementById('connections');
    const blocksEl = document.getElementById('blocks');
    const progressEl = document.getElementById('progress');
    const memoryBarEl = document.getElementById('memory-bar');
    const memoryTextEl = document.getElementById('memory-text');
    const diskBarEl = document.getElementById('disk-bar');
    const diskTextEl = document.getElementById('disk-text');
    const lastUpdatedEl = document.getElementById('last-updated');
    
    // Status mapping
    const statusMap = {
      'running': { text: 'Running', class: 'running' },
      'syncing': { text: 'Syncing', class: 'syncing' },
      'stopped': { text: 'Stopped', class: 'stopped' },
      'no_connections': { text: 'No Connections', class: 'error' },
      'starting': { text: 'Starting', class: '' }
    };
    
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
            versionEl.textContent = data.node.version;
            connectionsEl.textContent = data.node.connections;
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
            }
            
            if (diskPercent > 90) {
              diskBarEl.style.backgroundColor = 'var(--danger-color)';
            } else if (diskPercent > 70) {
              diskBarEl.style.backgroundColor = 'var(--warning-color)';
            }
          }
          
          // Update timestamp
          if (data.updated) {
            lastUpdatedEl.textContent = data.updated;
          } else {
            lastUpdatedEl.textContent = new Date().toLocaleString();
          }
        })
        .catch(error => {
          console.error('Error fetching status:', error);
          statusText.textContent = 'Error';
          statusLight.className = 'status-light error';
        });
    }
    
    // Initial update
    updateDashboard();
    
    // Refresh every 10 seconds
    setInterval(updateDashboard, 10000);
  });