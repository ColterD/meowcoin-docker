import { NodeInfo, NodeStatus, NodeType, NodeAction, AppError, ErrorCode } from '@meowcoin/shared';
import { getConfig } from '../config';
import { getLogger } from '../utils/logger';
import { setupRedis } from '../utils/redis';
import { setupPrisma } from '../utils/prisma';
import { MeowCoinRPC } from './meowcoinRPC';
import { EventEmitter } from 'events';
import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs/promises';
import path from 'path';
import os from 'os';

const execAsync = promisify(exec);

// Dependency factory for config, logger, redis, prisma
function getNodeManagerDeps() {
  const config = getConfig();
  const logger = getLogger(config);
  const redis = setupRedis(config, logger);
  const prisma = setupPrisma(logger);
  return { config, logger, redis, prisma };
}

const { config, logger, redis, prisma } = getNodeManagerDeps();

// Create event emitter for node events
export const nodeEvents = new EventEmitter();

// Initialize MeowCoin RPC client
const rpcClient = new MeowCoinRPC({
  host: config.meowcoin.rpcHost,
  port: config.meowcoin.rpcPort,
  user: config.meowcoin.rpcUser,
  password: config.meowcoin.rpcPassword,
}, logger);

// Initialize node manager
export async function initializeNodeManager() {
  try {
    logger.info('Initializing node manager');
    
    // Check if MeowCoin node is running
    const isRunning = await checkNodeRunning();
    
    if (!isRunning) {
      logger.info('MeowCoin node is not running, starting it');
      await startNode();
    } else {
      logger.info('MeowCoin node is already running');
    }
    
    // Start monitoring
    startMonitoring();
    
    // Schedule backups if enabled
    if (config.backup.enabled) {
      scheduleBackups();
    }
    
    logger.info('Node manager initialized successfully');
  } catch (error) {
    logger.error(error, 'Failed to initialize node manager');
    throw error;
  }
}

// Check if MeowCoin node is running
async function checkNodeRunning(): Promise<boolean> {
  try {
    // Try to get blockchain info to check if node is running
    await rpcClient.getBlockchainInfo();
    return true;
  } catch (error) {
    return false;
  }
}

// Start MeowCoin node
async function startNode(): Promise<void> {
  try {
    // Start MeowCoin daemon
    await execAsync(`${config.meowcoin.dataDir}/bin/meowcoind -daemon -datadir=${config.meowcoin.dataDir}`);
    
    // Wait for node to start
    let attempts = 0;
    const maxAttempts = 30;
    
    while (attempts < maxAttempts) {
      try {
        await rpcClient.getBlockchainInfo();
        logger.info('MeowCoin node started successfully');
        return;
      } catch (error) {
        attempts++;
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }
    
    throw new Error('Failed to start MeowCoin node after multiple attempts');
  } catch (error) {
    logger.error(error, 'Failed to start MeowCoin node');
    throw error;
  }
}

// Stop MeowCoin node
async function stopNode(): Promise<void> {
  try {
    await rpcClient.stop();
    logger.info('MeowCoin node stopped successfully');
  } catch (error) {
    logger.error(error, 'Failed to stop MeowCoin node');
    throw error;
  }
}

// Restart MeowCoin node
async function restartNode(): Promise<void> {
  try {
    await stopNode();
    // Wait for node to fully stop
    await new Promise(resolve => setTimeout(resolve, 5000));
    await startNode();
    logger.info('MeowCoin node restarted successfully');
  } catch (error) {
    logger.error(error, 'Failed to restart MeowCoin node');
    throw error;
  }
}

// Start monitoring MeowCoin node
function startMonitoring(): void {
  // Monitor node status every 30 seconds
  setInterval(async () => {
    try {
      const nodeInfo = await getNodeInfo();
      
      // Publish node info to Redis for real-time updates
      await redis.publish('node:update', JSON.stringify(nodeInfo));
      
      // Emit node update event
      nodeEvents.emit('update', nodeInfo);
      
      // Store node metrics in database for historical data
      await prisma.nodeMetric.create({
        data: {
          nodeId: nodeInfo.id,
          cpuUsage: nodeInfo.resources.cpuUsage,
          memoryUsage: nodeInfo.resources.memoryUsage,
          diskUsage: nodeInfo.resources.diskUsage,
          networkInbound: nodeInfo.resources.networkInbound,
          networkOutbound: nodeInfo.resources.networkOutbound,
          connections: nodeInfo.resources.connections,
          blockHeight: nodeInfo.blockHeight,
          timestamp: new Date(),
        },
      });
    } catch (error) {
      logger.error(error, 'Error monitoring node');
    }
  }, 30000);
}

// Schedule regular backups
function scheduleBackups(): void {
  // Schedule backup every interval
  setInterval(async () => {
    try {
      await createBackup();
    } catch (error) {
      logger.error(error, 'Error creating scheduled backup');
    }
  }, config.backup.interval * 1000);
}

// Create a backup of the blockchain data
async function createBackup(): Promise<string> {
  try {
    logger.info('Creating blockchain backup');
    
    // Get current block height
    const blockchainInfo = await rpcClient.getBlockchainInfo();
    const blockHeight = blockchainInfo.blocks;
    
    // Create backup directory if it doesn't exist
    await fs.mkdir(config.backup.storageDir, { recursive: true });
    
    // Create backup filename with timestamp and block height
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupFilename = `meowcoin-backup-${timestamp}-block-${blockHeight}.tar.gz`;
    const backupPath = path.join(config.backup.storageDir, backupFilename);
    
    // Create backup using tar
    await execAsync(`tar -czf ${backupPath} -C ${config.meowcoin.dataDir} .`);
    
    // Calculate backup size
    const stats = await fs.stat(backupPath);
    const backupSize = stats.size;
    
    // Store backup info in database
    const backup = await prisma.nodeBackup.create({
      data: {
        nodeId: 'main', // Assuming a single node for now
        blockHeight,
        size: backupSize,
        location: backupPath,
        status: 'completed',
        note: `Scheduled backup at block ${blockHeight}`,
      },
    });
    
    // Clean up old backups
    await cleanupOldBackups();
    
    logger.info({ backupId: backup.id }, 'Backup created successfully');
    
    return backup.id;
  } catch (error) {
    logger.error(error, 'Failed to create backup');
    throw error;
  }
}

// Clean up old backups to save space
async function cleanupOldBackups(): Promise<void> {
  try {
    // Get all backups ordered by creation date
    const backups = await prisma.nodeBackup.findMany({
      orderBy: { createdAt: 'desc' },
    });
    
    // Keep only the most recent backups based on maxBackups config
    if (backups.length > config.backup.maxBackups) {
      const backupsToDelete = backups.slice(config.backup.maxBackups);
      
      for (const backup of backupsToDelete) {
        // Delete backup file
        await fs.unlink(backup.location);
        
        // Update backup status in database
        await prisma.nodeBackup.update({
          where: { id: backup.id },
          data: { status: 'deleted' },
        });
        
        logger.info({ backupId: backup.id }, 'Deleted old backup');
      }
    }
  } catch (error) {
    logger.error(error, 'Failed to clean up old backups');
  }
}

// Get node information
export async function getNodeInfo(): Promise<NodeInfo> {
  try {
    // Get blockchain info
    const blockchainInfo = await rpcClient.getBlockchainInfo();
    
    // Get network info
    const networkInfo = await rpcClient.getNetworkInfo();
    
    // Get system resource usage
    const resourceUsage = await getSystemResourceUsage();
    
    // Calculate sync progress
    const syncProgress = blockchainInfo.initialblockdownload
      ? (blockchainInfo.blocks / blockchainInfo.headers) * 100
      : 100;
    
    // Get last block time
    const lastBlockHash = blockchainInfo.bestblockhash;
    const lastBlock = await rpcClient.getBlock(lastBlockHash);
    const lastBlockTime = new Date(lastBlock.time * 1000).toISOString();
    
    // Determine node status
    let status = NodeStatus.RUNNING;
    if (blockchainInfo.initialblockdownload) {
      status = NodeStatus.SYNCING;
    }
    
    // Create node info object
    const nodeInfo: NodeInfo = {
      id: 'main', // Assuming a single node for now
      name: 'MeowCoin Main Node',
      type: NodeType.FULL_NODE,
      status,
      version: networkInfo.subversion,
      protocolVersion: networkInfo.protocolversion,
      resources: {
        cpuUsage: resourceUsage.cpuUsage,
        memoryUsage: resourceUsage.memoryUsage,
        diskUsage: resourceUsage.diskUsage,
        networkInbound: 0, // Not available
        networkOutbound: 0, // Not available
        connections: networkInfo.connections,
        lastUpdated: new Date().toISOString(),
      },
      network: blockchainInfo.chain === 'main' ? 'mainnet' : blockchainInfo.chain === 'test' ? 'testnet' : 'regtest',
      syncProgress,
      blockHeight: blockchainInfo.blocks,
      lastBlockTime,
      peerCount: networkInfo.connections,
      uptime: process.uptime(),
      createdAt: new Date(Date.now() - process.uptime() * 1000).toISOString(),
      updatedAt: new Date().toISOString(),
    };
    
    return nodeInfo;
  } catch (error) {
    logger.error(error, 'Failed to get node info');
    throw new AppError(
      ErrorCode.NODE_ERROR,
      'Failed to get node information',
      500,
      { error }
    );
  }
}

// Get system resource usage
async function getSystemResourceUsage(): Promise<{
  cpuUsage: number;
  memoryUsage: number;
  diskUsage: number;
}> {
  try {
    // Use Node.js os module for CPU and memory stats
    // CPU usage: average over 1 second
    const cpus1 = os.cpus();
    const idle1 = cpus1.reduce((acc, cpu) => acc + cpu.times.idle, 0);
    const total1 = cpus1.reduce((acc, cpu) => acc + Object.values(cpu.times).reduce((a, b) => a + b, 0), 0);
    await new Promise((resolve) => setTimeout(resolve, 1000));
    const cpus2 = os.cpus();
    const idle2 = cpus2.reduce((acc, cpu) => acc + cpu.times.idle, 0);
    const total2 = cpus2.reduce((acc, cpu) => acc + Object.values(cpu.times).reduce((a, b) => a + b, 0), 0);
    const idle = idle2 - idle1;
    const total = total2 - total1;
    const cpuUsage = total > 0 ? (100 - (100 * idle / total)) : 0;

    // Memory usage
    const totalMem = os.totalmem();
    const freeMem = os.freemem();
    const usedMem = totalMem - freeMem;
    const memoryUsage = totalMem > 0 ? (usedMem * 100) / totalMem : 0;

    // Disk usage: fallback to shell command (platform-specific)
    let diskUsage = 0;
    try {
      const { stdout: diskOutput } = await execAsync(`df -h ${config.meowcoin.dataDir} | awk 'NR==2{print $5}' | sed 's/%//'`);
      diskUsage = parseFloat(diskOutput);
    } catch (diskErr) {
      // TODO: Add Windows/Mac support for disk usage if needed
      diskUsage = 0;
    }

    return {
      cpuUsage: isNaN(cpuUsage) ? 0 : cpuUsage,
      memoryUsage: isNaN(memoryUsage) ? 0 : memoryUsage,
      diskUsage: isNaN(diskUsage) ? 0 : diskUsage,
    };
  } catch (error) {
    logger.error(error, 'Failed to get system resource usage');
    return {
      cpuUsage: 0,
      memoryUsage: 0,
      diskUsage: 0,
    };
  }
}

// Perform action on node
export async function performNodeAction(action: NodeAction): Promise<NodeInfo> {
  try {
    logger.info({ action }, 'Performing node action');
    
    switch (action) {
      case NodeAction.START:
        await startNode();
        break;
      case NodeAction.STOP:
        await stopNode();
        break;
      case NodeAction.RESTART:
        await restartNode();
        break;
      case NodeAction.BACKUP:
        await createBackup();
        break;
      default:
        throw new AppError(
          ErrorCode.VALIDATION_ERROR,
          `Unsupported action: ${action}`,
          400
        );
    }
    
    // Get updated node info
    const nodeInfo = await getNodeInfo();
    
    // Publish node action event
    await redis.publish('node:action', JSON.stringify({
      action,
      nodeId: nodeInfo.id,
      timestamp: new Date().toISOString(),
    }));
    
    // Emit node action event
    nodeEvents.emit('action', {
      action,
      nodeInfo,
    });
    
    return nodeInfo;
  } catch (error) {
    logger.error({ error, action }, 'Failed to perform node action');
    throw new AppError(
      ErrorCode.NODE_ERROR,
      `Failed to perform action: ${action}`,
      500,
      { error }
    );
  }
}