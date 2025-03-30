import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import path from 'path';
import axios from 'axios';
import crypto from 'crypto';
import { environment } from '../config/environment';
import { 
  BlockchainInfo, 
  NetworkInfo, 
  NetTotals,
  NodeStatus
} from '../types';

const execAsync = promisify(exec);

// Configuration
const MEOWCOIN_CONFIG = environment.meowcoinConfig;
const MEOWCOIN_DATA = environment.meowcoinData;
const RPC_CONF_PATH = path.join(MEOWCOIN_CONFIG, 'meowcoin.conf');

// Helper to sanitize command parameters - improved with stricter whitelist
function sanitizeParam(param: string): string {
  // Only allow alphanumeric characters, periods, hyphens, and underscores
  const sanitized = param.replace(/[^a-zA-Z0-9\.\-\_]/g, '');
  
  // Additional check to ensure the sanitized string isn't empty
  if (!sanitized) {
    throw new Error('Invalid parameter: sanitization resulted in empty string');
  }
  
  return sanitized;
}

// Validate path to prevent directory traversal and other issues
function validatePath(inputPath: string): string {
  const normalized = path.normalize(inputPath);
  
  // Ensure the path doesn't contain any suspicious sequences
  if (
    normalized.includes('..') || 
    normalized.includes('/') && !normalized.startsWith('/') ||
    /\s/.test(normalized) // No whitespace allowed
  ) {
    throw new Error(`Invalid path: ${inputPath}`);
  }
  
  return normalized;
}

// Helper to read RPC credentials safely
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

// Execute RPC commands with secure credential handling
async function executeRpcCommand<T>(command: string, params: any[] = []): Promise<T> {
  try {
    // Validate command
    if (!/^[a-zA-Z0-9]+$/.test(command)) {
      throw new Error(`Invalid RPC command format: ${command}`);
    }
    
    const credentials = await getRpcCredentials();
    const { user, password } = credentials;
    
    // Generate a secure random request ID
    const requestId = `meowcoin-dashboard-${Date.now()}-${crypto.randomBytes(8).toString('hex')}`;
    
    const response = await axios.post<{ result: T; error: any }>('http://localhost:9766', {
      jsonrpc: '1.0',
      id: requestId,
      method: command,
      params
    }, {
      auth: {
        username: user,
        password
      },
      timeout: 10000 // Add timeout to prevent hanging requests
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

// Alternative using CLI when RPC is not available - with enhanced security
async function executeCli(command: string): Promise<string> {
  try {
    // Sanitize the command to prevent injection
    const sanitizedCommand = sanitizeParam(command);
    
    // Additional validation
    if (!sanitizedCommand || sanitizedCommand !== command) {
      throw new Error(`Invalid CLI command: ${command}`);
    }
    
    // Use path.resolve for proper path resolution
    const configPath = path.resolve(RPC_CONF_PATH);
    
    const { stdout } = await execAsync(`gosu meowcoin meowcoin-cli -conf="${configPath}" ${sanitizedCommand}`);
    return stdout.trim();
  } catch (error) {
    console.error(`Error executing CLI command ${command}:`, error);
    throw error;
  }
}

// Check if daemon is running
export async function isDaemonRunning(): Promise<boolean> {
  try {
    // Use a safer version that doesn't rely on shell command parsing
    const { stdout } = await execAsync('pgrep -x meowcoind');
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

// Check for version updates - safe from injection
export async function checkForVersionUpdate(currentVersion: string): Promise<{ available: boolean; version: string }> {
  try {
    // Validate currentVersion format
    if (!/^Meow-[\d.]+$/.test(currentVersion)) {
      console.warn(`Unexpected version format: ${currentVersion}`);
      return { available: false, version: '' };
    }
    
    // Extract clean version (e.g., Meow-2.0.5 to 2.0.5)
    const cleanVersion = currentVersion.replace(/^Meow-/, '').split('.').slice(0, 3).join('.');
    
    const response = await axios.get('https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/tags', {
      timeout: 10000, // Add timeout
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'Meowcoin-Dashboard'
      }
    });
    
    if (!response.data || !Array.isArray(response.data) || !response.data.length) {
      throw new Error('No tags found or invalid response format');
    }
    
    // Sort tags to find latest
    const sortedTags = [...response.data].sort((a, b) => {
        const aVersion = a.name.replace(/^Meow-/, '').split('.').map((n: string) => parseInt(n) || 0);
        const bVersion = b.name.replace(/^Meow-/, '').split('.').map((n: string) => parseInt(n) || 0);
      
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

// Get node status with improved error handling
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
    
    try {
      // Get node stats - wrapped in try/catch to handle potential RPC failures
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
      console.error('Error getting node data via RPC:', error);
      
      // Return partial status if RPC fails but daemon is running
      return {
        status: 'starting',
        blockchain: { blocks: 0, headers: 0, progress: '0' },
        node: { 
          version: 'Unknown', 
          subversion: 'Unknown', 
          connections: 0,
          bytesReceived: 0,
          bytesSent: 0
        },
        system: {
          memory: memInfo,
          disk: diskInfo
        },
        settings: await getNodeSettings(),
        updated: new Date().toISOString()
      };
    }
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

// Get memory info with improved error handling
async function getMemoryInfo(): Promise<NodeStatus['system']['memory']> {
  try {
    const { stdout } = await execAsync("free -m | grep 'Mem'");
    const parts = stdout.split(/\s+/);
    
    // Validate parts before accessing
    if (parts.length < 3) {
      throw new Error('Invalid memory info format');
    }
    
    const total = parseInt(parts[1], 10) || 0;
    const used = parseInt(parts[2], 10) || 0;
    const percent = ((used / total) * 100).toFixed(2);
    
    return { total, used, percent };
  } catch (error) {
    console.error('Error getting memory info:', error);
    return { total: 0, used: 0, percent: '0' };
  }
}

// Get disk info with improved error handling
async function getDiskInfo(): Promise<NodeStatus['system']['disk']> {
  try {
    // Use path.resolve to get canonical path
    const dataPath = path.resolve(MEOWCOIN_DATA);
    
    // Validate the path
    validatePath(dataPath);
    
    const { stdout } = await execAsync(`df -h "${dataPath}" | tail -n 1`);
    const parts = stdout.split(/\s+/);
    
    // Validate parts before accessing
    if (parts.length < 5) {
      throw new Error('Invalid disk info format');
    }
    
    const size = parts[1] || '0';
    const used = parts[2] || '0';
    const percentStr = parts[4] || '0%';
    const percent = parseInt(percentStr.replace('%', ''), 10) || 0;
    
    return { size, used, percent };
  } catch (error) {
    console.error('Error getting disk info:', error);
    return { size: '0', used: '0', percent: 0 };
  }
}

// Get node settings with improved error handling
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
    
    return { 
      maxConnections: isNaN(maxConnections) ? 50 : maxConnections, 
      enableTxindex: isNaN(enableTxindex) ? 1 : enableTxindex 
    };
  } catch (error) {
    console.error('Error getting node settings:', error);
    return { maxConnections: 50, enableTxindex: 1 };
  }
}

// Save node settings with improved security
export async function saveNodeSettings(settings: { maxConnections: number; enableTxindex: number }): Promise<boolean> {
  try {
    if (!fs.existsSync(RPC_CONF_PATH)) {
      throw new Error('Configuration file not found');
    }
    
    let confContent = fs.readFileSync(RPC_CONF_PATH, 'utf8');
    
    // Validate settings again for security
    const maxConnections = typeof settings.maxConnections === 'number' &&
                           Number.isInteger(settings.maxConnections) &&
                           settings.maxConnections >= 1 && 
                           settings.maxConnections <= 125 ? 
                           settings.maxConnections : 50;
                           
    const enableTxindex = settings.enableTxindex === 0 || settings.enableTxindex === 1 ?
                          settings.enableTxindex : 1;
    
    // Update maxconnections
    if (confContent.match(/maxconnections=\d+/)) {
      confContent = confContent.replace(
        /maxconnections=\d+/, 
        `maxconnections=${maxConnections}`
      );
    } else {
      confContent += `\nmaxconnections=${maxConnections}`;
    }
    
    // Update txindex
    if (confContent.match(/txindex=\d+/)) {
      confContent = confContent.replace(
        /txindex=\d+/, 
        `txindex=${enableTxindex}`
      );
    } else {
      confContent += `\ntxindex=${enableTxindex}`;
    }
    
    // Write back to file with atomic write
    const tempFile = `${RPC_CONF_PATH}.tmp`;
    fs.writeFileSync(tempFile, confContent);
    fs.renameSync(tempFile, RPC_CONF_PATH);
    
    // Create a flag file to signal config update
    fs.writeFileSync(`${MEOWCOIN_DATA}/.meowcoin/config_updated.flag`, '');
    
    return true;
  } catch (error) {
    console.error('Error saving node settings:', error);
    return false;
  }
}

// Restart the node safely
export async function restartNode(): Promise<boolean> {
  try {
    await execAsync('docker restart meowcoin-node');
    return true;
  } catch (error) {
    console.error('Error restarting node:', error);
    return false;
  }
}

// Shutdown the node safely
export async function shutdownNode(): Promise<boolean> {
  try {
    await execAsync('docker stop meowcoin-node');
    return true;
  } catch (error) {
    console.error('Error stopping node:', error);
    return false;
  }
}

// Update the node with version validation
export async function updateNode(version: string): Promise<boolean> {
  try {
    // Validate version format
    const versionPattern = /^Meow-v\d+\.\d+\.\d+$/;
    if (!versionPattern.test(version)) {
      console.error(`Invalid version format: ${version}`);
      return false;
    }
    
    // Create update flag file with version
    fs.writeFileSync(`${MEOWCOIN_DATA}/.meowcoin/update.flag`, version);
    return true;
  } catch (error) {
    console.error('Error updating node:', error);
    return false;
  }
}