import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import path from 'path';
import axios from 'axios';
import { 
  BlockchainInfo, 
  NetworkInfo, 
  NetTotals,
  NodeStatus
} from '../types';

const execAsync = promisify(exec);

// Configuration
const MEOWCOIN_CONFIG = process.env.MEOWCOIN_CONFIG || '/config';
const MEOWCOIN_DATA = process.env.MEOWCOIN_DATA || '/data';
const RPC_CONF_PATH = path.join(MEOWCOIN_CONFIG, 'meowcoin.conf');

// Helper to read RPC credentials
async function getRpcCredentials(): Promise<{ user: string; password: string }> {
  try {
    // First, try to read from the password file
    const rpcPassPath = path.join(MEOWCOIN_DATA, '.meowcoin', 'rpc.pass');
    if (fs.existsSync(rpcPassPath)) {
      const password = fs.readFileSync(rpcPassPath, 'utf8').trim();
      return { user: 'meowcoin', password };
    }
    
    // Otherwise, try to parse from config file
    if (fs.existsSync(RPC_CONF_PATH)) {
      const confContent = fs.readFileSync(RPC_CONF_PATH, 'utf8');
      const userMatch = confContent.match(/rpcuser=(.+)/);
      const passMatch = confContent.match(/rpcpassword=(.+)/);
      
      if (userMatch && passMatch) {
        return { 
          user: userMatch[1].trim(), 
          password: passMatch[1].trim() 
        };
      }
    }
    
    throw new Error('RPC credentials not found');
  } catch (error) {
    console.error('Error reading RPC credentials:', error);
    throw error;
  }
}

// Execute RPC commands
async function executeRpcCommand<T>(command: string, params: any[] = []): Promise<T> {
  try {
    const credentials = await getRpcCredentials();
    const { user, password } = credentials;
    
    const response = await axios.post<{ result: T; error: any }>('http://localhost:9766', {
      jsonrpc: '1.0',
      id: 'meowcoin-dashboard',
      method: command,
      params
    }, {
      auth: {
        username: user,
        password
      }
    });
    
    if (response.data.error) {
      throw new Error(`RPC Error: ${JSON.stringify(response.data.error)}`);
    }
    
    return response.data.result;
  } catch (error) {
    console.error(`Error executing RPC command ${command}:`, error);
    throw error;
  }
}

// Alternative using CLI when RPC is not available
async function executeCli(command: string): Promise<string> {
  try {
    const { stdout } = await execAsync(`gosu meowcoin meowcoin-cli -conf="${RPC_CONF_PATH}" ${command}`);
    return stdout.trim();
  } catch (error) {
    console.error(`Error executing CLI command ${command}:`, error);
    throw error;
  }
}

// Check if daemon is running
export async function isDaemonRunning(): Promise<boolean> {
  try {
    const { stdout } = await execAsync('pgrep -x "meowcoind"');
    return !!stdout.trim();
  } catch (error) {
    return false;
  }
}

// Get blockchain info
export async function getBlockchainInfo(): Promise<BlockchainInfo> {
  return executeRpcCommand<BlockchainInfo>('getblockchaininfo');
}

// Get network info
export async function getNetworkInfo(): Promise<NetworkInfo> {
  return executeRpcCommand<NetworkInfo>('getnetworkinfo');
}

// Get network transfer totals
export async function getNetTotals(): Promise<NetTotals> {
  return executeRpcCommand<NetTotals>('getnettotals');
}

// Get node version
export async function getNodeVersion(): Promise<string> {
  try {
    const info = await getNetworkInfo();
    return info.subversion.replace(/[/]/g, '');
  } catch (error) {
    console.error('Error getting node version:', error);
    return 'Unknown';
  }
}

// Check for version updates
export async function checkForVersionUpdate(currentVersion: string): Promise<{ available: boolean; version: string }> {
  try {
    // Extract clean version (e.g., Meow-2.0.5 to 2.0.5)
    const cleanVersion = currentVersion.replace(/^Meow-/, '').split('.').slice(0, 3).join('.');
    
    const response = await axios.get('https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/tags');
    if (!response.data || !response.data.length) {
      throw new Error('No tags found');
    }
    
    // Sort tags to find latest
    const sortedTags = [...response.data].sort((a, b) => {
      const aVersion = a.name.replace(/^Meow-/, '').split('.').map(n => parseInt(n));
      const bVersion = b.name.replace(/^Meow-/, '').split('.').map(n => parseInt(n));
      
      for (let i = 0; i < Math.max(aVersion.length, bVersion.length); i++) {
        const aNum = aVersion[i] || 0;
        const bNum = bVersion[i] || 0;
        if (aNum !== bNum) {
          return bNum - aNum; // Descending order
        }
      }
      return 0;
    });
    
    const latestTag = sortedTags[0];
    const latestVersion = latestTag.name.replace(/^Meow-/, '').split('.').slice(0, 3).join('.');
    
    // Compare versions
    const isNewer = compareVersions(latestVersion, cleanVersion) > 0;
    
    return {
      available: isNewer,
      version: isNewer ? latestTag.name : ''
    };
  } catch (error) {
    console.error('Error checking for updates:', error);
    return { available: false, version: '' };
  }
}

// Version comparison helper
function compareVersions(a: string, b: string): number {
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

// Get node status
export async function getNodeStatus(): Promise<NodeStatus | null> {
  try {
    const isRunning = await isDaemonRunning();
    
    if (!isRunning) {
      return {
        status: 'stopped',
        blockchain: { blocks: 0, headers: 0, progress: '0' },
        node: { 
          version: 'Unknown', 
          subversion: 'Unknown', 
          connections: 0,
          bytesReceived: 0,
          bytesSent: 0
        },
        system: {
          memory: { used: 0, total: 0, percent: '0' },
          disk: { size: '0', used: '0', percent: 0 }
        },
        settings: { maxConnections: 0, enableTxindex: 0 },
        updated: new Date().toISOString()
      };
    }
    
    // Get system stats
    const memInfo = await getMemoryInfo();
    const diskInfo = await getDiskInfo();
    
    // Get node stats
    const blockchainInfo = await getBlockchainInfo();
    const networkInfo = await getNetworkInfo();
    const netTotals = await getNetTotals();
    
    // Get settings
    const settings = await getNodeSettings();
    
    // Check for updates
    const versionCheck = await checkForVersionUpdate(formatVersion(networkInfo.version.toString()));
    
    // Determine status
    let status: NodeStatus['status'] = 'running';
    if (blockchainInfo.initialblockdownload || blockchainInfo.blocks < blockchainInfo.headers) {
      status = 'syncing';
    } else if (networkInfo.connections === 0) {
      status = 'no_connections';
    }
    
    return {
      status,
      blockchain: {
        blocks: blockchainInfo.blocks,
        headers: blockchainInfo.headers,
        progress: (blockchainInfo.verificationprogress * 100).toFixed(2)
      },
      node: {
        version: formatVersion(networkInfo.version.toString()),
        subversion: networkInfo.subversion,
        connections: networkInfo.connections,
        bytesReceived: netTotals.totalbytesrecv,
        bytesSent: netTotals.totalbytessent
      },
      system: {
        memory: memInfo,
        disk: diskInfo
      },
      settings,
      updateAvailable: versionCheck.available,
      latestVersion: versionCheck.version,
      updated: new Date().toISOString()
    };
  } catch (error) {
    console.error('Error getting node status:', error);
    return null;
  }
}

// Format version to Meowcoin format
function formatVersion(version: string): string {
  if (!version) return 'Unknown';
  
  // If already in correct format
  if (version.includes('Meow-')) {
    return version;
  }
  
  // If it's a numeric format
  if (/^\d+$/.test(version)) {
    const major = parseInt(version.slice(0, -4)) || 0;
    const minor = parseInt(version.slice(-4, -2)) || 0;
    const patch = parseInt(version.slice(-2)) || 0;
    return `Meow-${major}.${minor}.${patch}`;
  }
  
  // If it's in semver format
  if (version.startsWith('v')) {
    const parts = version.substring(1).split('.');
    return `Meow-${parts[0]}.${parts[1]}.${parts[2]}`;
  }
  
  return version;
}

// Get memory info
async function getMemoryInfo(): Promise<NodeStatus['system']['memory']> {
  try {
    const { stdout } = await execAsync("free -m | grep 'Mem'");
    const parts = stdout.split(/\s+/);
    const total = parseInt(parts[1], 10);
    const used = parseInt(parts[2], 10);
    const percent = ((used / total) * 100).toFixed(2);
    
    return { total, used, percent };
  } catch (error) {
    console.error('Error getting memory info:', error);
    return { total: 0, used: 0, percent: '0' };
  }
}

// Get disk info
async function getDiskInfo(): Promise<NodeStatus['system']['disk']> {
  try {
    const { stdout } = await execAsync(`df -h "${MEOWCOIN_DATA}" | tail -n 1`);
    const parts = stdout.split(/\s+/);
    const size = parts[1];
    const used = parts[2];
    const percent = parseInt(parts[4].replace('%', ''), 10);
    
    return { size, used, percent };
  } catch (error) {
    console.error('Error getting disk info:', error);
    return { size: '0', used: '0', percent: 0 };
  }
}

// Get node settings
export async function getNodeSettings(): Promise<NodeStatus['settings']> {
  try {
    if (!fs.existsSync(RPC_CONF_PATH)) {
      return { maxConnections: 50, enableTxindex: 1 };
    }
    
    const confContent = fs.readFileSync(RPC_CONF_PATH, 'utf8');
    
    const maxConnectionsMatch = confContent.match(/maxconnections=(\d+)/);
    const enableTxindexMatch = confContent.match(/txindex=(\d+)/);
    
    const maxConnections = maxConnectionsMatch ? parseInt(maxConnectionsMatch[1], 10) : 50;
    const enableTxindex = enableTxindexMatch ? parseInt(enableTxindexMatch[1], 10) : 1;
    
    return { maxConnections, enableTxindex };
  } catch (error) {
    console.error('Error getting node settings:', error);
    return { maxConnections: 50, enableTxindex: 1 };
  }
}

// Save node settings
export async function saveNodeSettings(settings: { maxConnections: number; enableTxindex: number }): Promise<boolean> {
  try {
    if (!fs.existsSync(RPC_CONF_PATH)) {
      throw new Error('Configuration file not found');
    }
    
    let confContent = fs.readFileSync(RPC_CONF_PATH, 'utf8');
    
    // Update maxconnections
    if (confContent.match(/maxconnections=\d+/)) {
      confContent = confContent.replace(
        /maxconnections=\d+/, 
        `maxconnections=${settings.maxConnections}`
      );
    } else {
      confContent += `\nmaxconnections=${settings.maxConnections}`;
    }
    
    // Update txindex
    if (confContent.match(/txindex=\d+/)) {
      confContent = confContent.replace(
        /txindex=\d+/, 
        `txindex=${settings.enableTxindex}`
      );
    } else {
      confContent += `\ntxindex=${settings.enableTxindex}`;
    }
    
    // Write back to file
    fs.writeFileSync(RPC_CONF_PATH, confContent);
    
    // Create a flag file to signal config update
    fs.writeFileSync(`${MEOWCOIN_DATA}/.meowcoin/config_updated.flag`, '');
    
    return true;
  } catch (error) {
    console.error('Error saving node settings:', error);
    return false;
  }
}

// Restart the node
export async function restartNode(): Promise<boolean> {
  try {
    const { stdout } = await execAsync('docker restart meowcoin-node');
    return true;
  } catch (error) {
    console.error('Error restarting node:', error);
    return false;
  }
}

// Shutdown the node
export async function shutdownNode(): Promise<boolean> {
  try {
    const { stdout } = await execAsync('docker stop meowcoin-node');
    return true;
  } catch (error) {
    console.error('Error stopping node:', error);
    return false;
  }
}

// Update the node
export async function updateNode(version: string): Promise<boolean> {
  try {
    // Create update flag file with version
    fs.writeFileSync(`${MEOWCOIN_DATA}/.meowcoin/update.flag`, version);
    return true;
  } catch (error) {
    console.error('Error updating node:', error);
    return false;
  }
}