// backend/src/services/nodeService.ts
import { exec } from 'child_process';
import { promises as fs } from 'fs';
import path from 'path';
import { promisify } from 'util';
import { environment } from '../config/environment';
import { NodeStatus, SettingsRequest } from '../types';

const execAsync = promisify(exec);
const MEOWCOIN_CONFIG = environment.meowcoinConfig;
const MEOWCOIN_DATA = environment.meowcoinData;

// Get blockchain information
async function getBlockchainInfo() {
  try {
    const { stdout } = await execAsync(`meowcoin-cli -conf=${MEOWCOIN_CONFIG}/meowcoin.conf getblockchaininfo`);
    return JSON.parse(stdout);
  } catch (error) {
    console.error('Error getting blockchain info:', error);
    return null;
  }
}

// Get network information
async function getNetworkInfo() {
  try {
    const { stdout } = await execAsync(`meowcoin-cli -conf=${MEOWCOIN_CONFIG}/meowcoin.conf getnetworkinfo`);
    return JSON.parse(stdout);
  } catch (error) {
    console.error('Error getting network info:', error);
    return null;
  }
}

// Get network traffic information
async function getNetworkTraffic() {
  try {
    const { stdout } = await execAsync(`meowcoin-cli -conf=${MEOWCOIN_CONFIG}/meowcoin.conf getnettotals`);
    return JSON.parse(stdout);
  } catch (error) {
    console.error('Error getting network traffic:', error);
    return null;
  }
}

// Get system resource usage
async function getSystemInfo() {
  try {
    // Get memory info
    const { stdout: memInfo } = await execAsync('free -m');
    const memLines = memInfo.split('\n');
    const memValues = memLines[1].trim().split(/\s+/);
    const totalMem = parseInt(memValues[1], 10);
    const usedMem = parseInt(memValues[2], 10);
    const memPercent = ((usedMem / totalMem) * 100).toFixed(1);

    // Get disk info for data directory
    const { stdout: diskInfo } = await execAsync(`df -h ${MEOWCOIN_DATA}`);
    const diskLines = diskInfo.split('\n');
    const diskValues = diskLines[1].trim().split(/\s+/);
    const diskSize = diskValues[1];
    const diskUsed = diskValues[2];
    const diskPercent = parseInt(diskValues[4].replace('%', ''), 10);

    return {
      memory: {
        total: totalMem,
        used: usedMem,
        percent: memPercent
      },
      disk: {
        size: diskSize,
        used: diskUsed,
        percent: diskPercent
      }
    };
  } catch (error) {
    console.error('Error getting system info:', error);
    return null;
  }
}

// Read current node settings
async function getNodeSettings() {
  try {
    // Default settings
    const defaultSettings = {
      maxConnections: 50,
      enableTxindex: 1
    };

    // Try to read from configuration file
    const configPath = path.join(MEOWCOIN_CONFIG, 'meowcoin.conf');
    
    try {
      const configContent = await fs.readFile(configPath, 'utf8');
      const lines = configContent.split('\n');
      
      // Extract settings
      let maxConnections = defaultSettings.maxConnections;
      let enableTxindex = defaultSettings.enableTxindex;
      
      for (const line of lines) {
        const trimmedLine = line.trim();
        
        // Skip comments and empty lines
        if (trimmedLine.startsWith('#') || trimmedLine === '') {
          continue;
        }
        
        // Parse key-value pairs
        const [key, value] = trimmedLine.split('=').map(part => part.trim());
        
        if (key === 'maxconnections' && !isNaN(parseInt(value, 10))) {
          maxConnections = parseInt(value, 10);
        } else if (key === 'txindex' && !isNaN(parseInt(value, 10))) {
          enableTxindex = parseInt(value, 10);
        }
      }
      
      return {
        maxConnections,
        enableTxindex
      };
    } catch (error) {
      console.warn('Error reading config file, using default settings:', error);
      return defaultSettings;
    }
  } catch (error) {
    console.error('Error getting node settings:', error);
    return null;
  }
}

// Check for available updates
async function checkForUpdates(currentVersion: string) {
  try {
    // Extract version number (assuming format like "Meow-v2.0.5")
    const versionMatch = currentVersion.match(/v(\d+\.\d+\.\d+)/);
    if (!versionMatch) {
      return { available: false };
    }
    
    const currentVersionNum = versionMatch[1];
    
    // Query GitHub API for releases
    const { stdout } = await execAsync(
      'curl -s https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/latest'
    );
    
    const releaseInfo = JSON.parse(stdout);
    const latestVersion = releaseInfo.tag_name;
    
    // Compare versions
    const currentParts = currentVersionNum.split('.').map(Number);
    const latestParts = latestVersion.replace(/^Meow-v/, '').split('.').map(Number);
    
    // Check if newer version is available
    let updateAvailable = false;
    for (let i = 0; i < Math.max(currentParts.length, latestParts.length); i++) {
      const currentPart = currentParts[i] || 0;
      const latestPart = latestParts[i] || 0;
      
      if (latestPart > currentPart) {
        updateAvailable = true;
        break;
      } else if (latestPart < currentPart) {
        break;
      }
    }
    
    return {
      available: updateAvailable,
      latestVersion
    };
  } catch (error) {
    console.error('Error checking for updates:', error);
    return { available: false };
  }
}

// Get comprehensive node status
export async function getNodeStatus(): Promise<NodeStatus | null> {
  try {
    // Get blockchain information
    const blockchainInfo = await getBlockchainInfo();
    const networkInfo = await getNetworkInfo();
    const networkTraffic = await getNetworkTraffic();
    const systemInfo = await getSystemInfo();
    const settings = await getNodeSettings();
    
    // Determine node status
    let status: NodeStatus['status'] = 'stopped';
    
    if (blockchainInfo && networkInfo) {
      if (blockchainInfo.initialblockdownload) {
        status = 'syncing';
      } else if (networkInfo.connections === 0) {
        status = 'no_connections';
      } else {
        status = 'running';
      }
    }
    
    // Build response object
    const response: NodeStatus = {
      status,
      blockchain: {
        blocks: blockchainInfo?.blocks || 0,
        headers: blockchainInfo?.headers || 0,
        progress: blockchainInfo ? (blockchainInfo.verificationprogress * 100).toFixed(2) : '0.00'
      },
      node: {
        version: networkInfo?.version?.toString() || 'Unknown',
        subversion: networkInfo?.subversion || 'Unknown',
        connections: networkInfo?.connections || 0,
        bytesReceived: networkTraffic?.totalbytesrecv || 0,
        bytesSent: networkTraffic?.totalbytessent || 0
      },
      system: systemInfo || {
        memory: { used: 0, total: 0, percent: '0.0' },
        disk: { size: '0G', used: '0G', percent: 0 }
      },
      settings: settings || {
        maxConnections: 50,
        enableTxindex: 1
      },
      updated: new Date().toISOString()
    };
    
    // Check for updates
    if (networkInfo && networkInfo.subversion) {
      const updateCheck = await checkForUpdates(networkInfo.subversion);
      if (updateCheck.available) {
        response.updateAvailable = true;
        response.latestVersion = updateCheck.latestVersion;
      }
    }
    
    return response;
  } catch (error) {
    console.error('Error getting node status:', error);
    return null;
  }
}

// Save node settings
export async function saveNodeSettings(settings: SettingsRequest): Promise<boolean> {
  try {
    const configPath = path.join(MEOWCOIN_CONFIG, 'meowcoin.conf');
    
    // Read current config
    let configContent = await fs.readFile(configPath, 'utf8');
    const lines = configContent.split('\n');
    const updatedLines = [];
    
    let maxConnectionsUpdated = false;
    let txindexUpdated = false;
    
    // Update existing settings
    for (const line of lines) {
      const trimmedLine = line.trim();
      
      // Skip comments and empty lines
      if (trimmedLine.startsWith('#') || trimmedLine === '') {
        updatedLines.push(line);
        continue;
      }
      
      // Check and update settings
      if (trimmedLine.startsWith('maxconnections=')) {
        updatedLines.push(`maxconnections=${settings.maxConnections}`);
        maxConnectionsUpdated = true;
      } else if (trimmedLine.startsWith('txindex=')) {
        updatedLines.push(`txindex=${settings.enableTxindex}`);
        txindexUpdated = true;
      } else {
        updatedLines.push(line);
      }
    }
    
    // Add settings if not present
    if (!maxConnectionsUpdated) {
      updatedLines.push(`maxconnections=${settings.maxConnections}`);
    }
    
    if (!txindexUpdated) {
      updatedLines.push(`txindex=${settings.enableTxindex}`);
    }
    
    // Write updated config
    await fs.writeFile(configPath, updatedLines.join('\n'));
    
    return true;
  } catch (error) {
    console.error('Error saving node settings:', error);
    return false;
  }
}

// Restart the node service
export async function restartNode(): Promise<boolean> {
  try {
    // Stop the node
    try {
      await execAsync('meowcoin-cli -conf=${MEOWCOIN_CONFIG}/meowcoin.conf stop');
      // Wait for node to stop
      await new Promise(resolve => setTimeout(resolve, 10000));
    } catch (error) {
      console.warn('Error stopping node, may already be stopped:', error);
    }
    
    // Start the node
    try {
      await execAsync('meowcoind -conf=${MEOWCOIN_CONFIG}/meowcoin.conf -daemon');
    } catch (error) {
      console.error('Error starting node:', error);
      return false;
    }
    
    return true;
  } catch (error) {
    console.error('Error restarting node:', error);
    return false;
  }
}

// Shutdown the node service
export async function shutdownNode(): Promise<boolean> {
  try {
    await execAsync('meowcoin-cli -conf=${MEOWCOIN_CONFIG}/meowcoin.conf stop');
    return true;
  } catch (error) {
    console.error('Error shutting down node:', error);
    return false;
  }
}

// Update the node software
export async function updateNode(version: string): Promise<boolean> {
  try {
    // Validate version format
    if (!/^Meow-v\d+\.\d+\.\d+$/.test(version)) {
      console.error('Invalid version format:', version);
      return false;
    }
    
    // Execute update script
    await execAsync(`/scripts/update-node.sh ${version}`);
    
    return true;
  } catch (error) {
    console.error('Error updating node:', error);
    return false;
  }
}

// Create backup of blockchain data with better error handling and logging
export async function createBackup(): Promise<boolean> {
  try {
    const backup_dir = `${MEOWCOIN_DATA}/backups`;
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backup_file = `${backup_dir}/meowcoin_backup_${timestamp}.tar.gz`;
    
    // Ensure backup directory exists
    try {
      await fs.mkdir(backup_dir, { recursive: true });
    } catch (error) {
      console.error(`Failed to create backup directory: ${error instanceof Error ? error.message : 'Unknown error'}`);
      return false;
    }
    
    console.log(`Creating backup: ${backup_file}`);
    
    // Create compressed backup - with timeout to prevent hanging
    try {
      const { stdout, stderr } = await execAsync(
        `tar -czf "${backup_file}" -C "${MEOWCOIN_DATA}" .meowcoin`,
        { timeout: 3600000 } // 1 hour timeout
      );
      
      if (stderr && stderr.length > 0) {
        console.warn(`Backup generated warnings: ${stderr}`);
      }
      
      console.log(`Backup completed successfully: ${backup_file}`);
      
      // Clean up old backups (keep last 5) - with error handling
      try {
        const backupFiles = await fs.readdir(backup_dir);
        const backupPaths = backupFiles
          .filter(file => /^meowcoin_backup_.*\.tar\.gz$/.test(file))
          .map(file => path.join(backup_dir, file));
        
        // Sort by modification time (oldest first)
        const sortedBackups = await Promise.all(
          backupPaths.map(async file => {
            const stats = await fs.stat(file);
            return { path: file, mtime: stats.mtime.getTime() };
          })
        );
        
        sortedBackups.sort((a, b) => a.mtime - b.mtime);
        
        // Delete all but the newest 5 backups
        const backupsToDelete = sortedBackups.slice(0, Math.max(0, sortedBackups.length - 5));
        
        for (const backup of backupsToDelete) {
          await fs.unlink(backup.path);
          console.log(`Deleted old backup: ${backup.path}`);
        }
      } catch (error) {
        console.error(`Error cleaning up old backups: ${error instanceof Error ? error.message : 'Unknown error'}`);
        // Don't fail the backup operation if cleanup fails
      }
      
      return true;
    } catch (error) {
      console.error(`Backup command failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
      return false;
    }
  } catch (error) {
    console.error(`Unexpected error in createBackup: ${error instanceof Error ? error.message : 'Unknown error'}`);
    return false;
  }
}