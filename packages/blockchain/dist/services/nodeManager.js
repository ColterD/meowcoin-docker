"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.nodeEvents = void 0;
exports.initializeNodeManager = initializeNodeManager;
exports.getNodeInfo = getNodeInfo;
exports.performNodeAction = performNodeAction;
const shared_1 = require("@meowcoin/shared");
const config_1 = require("../config");
const logger_1 = require("../utils/logger");
const meowcoinRPC_1 = require("./meowcoinRPC");
const prisma_1 = require("../utils/prisma");
const redis_1 = require("../utils/redis");
const events_1 = require("events");
const child_process_1 = require("child_process");
const util_1 = require("util");
const promises_1 = __importDefault(require("fs/promises"));
const path_1 = __importDefault(require("path"));
const os_1 = __importDefault(require("os"));
const execAsync = (0, util_1.promisify)(child_process_1.exec);
// Create event emitter for node events
exports.nodeEvents = new events_1.EventEmitter();
// Initialize MeowCoin RPC client
const rpcClient = new meowcoinRPC_1.MeowCoinRPC({
    host: config_1.config.meowcoin.rpcHost,
    port: config_1.config.meowcoin.rpcPort,
    user: config_1.config.meowcoin.rpcUser,
    password: config_1.config.meowcoin.rpcPassword,
});
// Initialize node manager
async function initializeNodeManager() {
    try {
        logger_1.logger.info('Initializing node manager');
        // Check if MeowCoin node is running
        const isRunning = await checkNodeRunning();
        if (!isRunning) {
            logger_1.logger.info('MeowCoin node is not running, starting it');
            await startNode();
        }
        else {
            logger_1.logger.info('MeowCoin node is already running');
        }
        // Start monitoring
        startMonitoring();
        // Schedule backups if enabled
        if (config_1.config.backup.enabled) {
            scheduleBackups();
        }
        logger_1.logger.info('Node manager initialized successfully');
    }
    catch (error) {
        logger_1.logger.error(error, 'Failed to initialize node manager');
        throw error;
    }
}
// Check if MeowCoin node is running
async function checkNodeRunning() {
    try {
        // Try to get blockchain info to check if node is running
        await rpcClient.getBlockchainInfo();
        return true;
    }
    catch (error) {
        return false;
    }
}
// Start MeowCoin node
async function startNode() {
    try {
        // Start MeowCoin daemon
        await execAsync(`${config_1.config.meowcoin.dataDir}/bin/meowcoind -daemon -datadir=${config_1.config.meowcoin.dataDir}`);
        // Wait for node to start
        let attempts = 0;
        const maxAttempts = 30;
        while (attempts < maxAttempts) {
            try {
                await rpcClient.getBlockchainInfo();
                logger_1.logger.info('MeowCoin node started successfully');
                return;
            }
            catch (error) {
                attempts++;
                await new Promise(resolve => setTimeout(resolve, 1000));
            }
        }
        throw new Error('Failed to start MeowCoin node after multiple attempts');
    }
    catch (error) {
        logger_1.logger.error(error, 'Failed to start MeowCoin node');
        throw error;
    }
}
// Stop MeowCoin node
async function stopNode() {
    try {
        await rpcClient.stop();
        logger_1.logger.info('MeowCoin node stopped successfully');
    }
    catch (error) {
        logger_1.logger.error(error, 'Failed to stop MeowCoin node');
        throw error;
    }
}
// Restart MeowCoin node
async function restartNode() {
    try {
        await stopNode();
        // Wait for node to fully stop
        await new Promise(resolve => setTimeout(resolve, 5000));
        await startNode();
        logger_1.logger.info('MeowCoin node restarted successfully');
    }
    catch (error) {
        logger_1.logger.error(error, 'Failed to restart MeowCoin node');
        throw error;
    }
}
// Start monitoring MeowCoin node
function startMonitoring() {
    // Monitor node status every 30 seconds
    setInterval(async () => {
        try {
            const nodeInfo = await getNodeInfo();
            // Publish node info to Redis for real-time updates
            await redis_1.redis.publish('node:update', JSON.stringify(nodeInfo));
            // Emit node update event
            exports.nodeEvents.emit('update', nodeInfo);
            // Store node metrics in database for historical data
            await prisma_1.prisma.nodeMetric.create({
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
        }
        catch (error) {
            logger_1.logger.error(error, 'Error monitoring node');
        }
    }, 30000);
}
// Schedule regular backups
function scheduleBackups() {
    // Schedule backup every interval
    setInterval(async () => {
        try {
            await createBackup();
        }
        catch (error) {
            logger_1.logger.error(error, 'Error creating scheduled backup');
        }
    }, config_1.config.backup.interval * 1000);
}
// Create a backup of the blockchain data
async function createBackup() {
    try {
        logger_1.logger.info('Creating blockchain backup');
        // Get current block height
        const blockchainInfo = await rpcClient.getBlockchainInfo();
        const blockHeight = blockchainInfo.blocks;
        // Create backup directory if it doesn't exist
        await promises_1.default.mkdir(config_1.config.backup.storageDir, { recursive: true });
        // Create backup filename with timestamp and block height
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const backupFilename = `meowcoin-backup-${timestamp}-block-${blockHeight}.tar.gz`;
        const backupPath = path_1.default.join(config_1.config.backup.storageDir, backupFilename);
        // Create backup using tar
        await execAsync(`tar -czf ${backupPath} -C ${config_1.config.meowcoin.dataDir} .`);
        // Calculate backup size
        const stats = await promises_1.default.stat(backupPath);
        const backupSize = stats.size;
        // Store backup info in database
        const backup = await prisma_1.prisma.nodeBackup.create({
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
        logger_1.logger.info({ backupId: backup.id }, 'Backup created successfully');
        return backup.id;
    }
    catch (error) {
        logger_1.logger.error(error, 'Failed to create backup');
        throw error;
    }
}
// Clean up old backups to save space
async function cleanupOldBackups() {
    try {
        // Get all backups ordered by creation date
        const backups = await prisma_1.prisma.nodeBackup.findMany({
            orderBy: { createdAt: 'desc' },
        });
        // Keep only the most recent backups based on maxBackups config
        if (backups.length > config_1.config.backup.maxBackups) {
            const backupsToDelete = backups.slice(config_1.config.backup.maxBackups);
            for (const backup of backupsToDelete) {
                // Delete backup file
                await promises_1.default.unlink(backup.location);
                // Update backup status in database
                await prisma_1.prisma.nodeBackup.update({
                    where: { id: backup.id },
                    data: { status: 'deleted' },
                });
                logger_1.logger.info({ backupId: backup.id }, 'Deleted old backup');
            }
        }
    }
    catch (error) {
        logger_1.logger.error(error, 'Failed to clean up old backups');
    }
}
// Get node information
async function getNodeInfo() {
    try {
        // Get blockchain info
        const blockchainInfo = await rpcClient.getBlockchainInfo();
        // Get network info
        const networkInfo = await rpcClient.getNetworkInfo();
        // Get memory info
        const memInfo = await rpcClient.getMemoryInfo();
        // Get mining info
        const miningInfo = await rpcClient.getMiningInfo();
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
        let status = shared_1.NodeStatus.RUNNING;
        if (blockchainInfo.initialblockdownload) {
            status = shared_1.NodeStatus.SYNCING;
        }
        // Create node info object
        const nodeInfo = {
            id: 'main', // Assuming a single node for now
            name: 'MeowCoin Main Node',
            type: shared_1.NodeType.FULL_NODE,
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
    }
    catch (error) {
        logger_1.logger.error(error, 'Failed to get node info');
        throw new shared_1.AppError(shared_1.ErrorCode.NODE_ERROR, 'Failed to get node information', 500, { error });
    }
}
// Get system resource usage
async function getSystemResourceUsage() {
    try {
        // Use Node.js os module for CPU and memory stats
        // CPU usage: average over 1 second
        const cpus1 = os_1.default.cpus();
        const idle1 = cpus1.reduce((acc, cpu) => acc + cpu.times.idle, 0);
        const total1 = cpus1.reduce((acc, cpu) => acc + Object.values(cpu.times).reduce((a, b) => a + b, 0), 0);
        await new Promise((resolve) => setTimeout(resolve, 1000));
        const cpus2 = os_1.default.cpus();
        const idle2 = cpus2.reduce((acc, cpu) => acc + cpu.times.idle, 0);
        const total2 = cpus2.reduce((acc, cpu) => acc + Object.values(cpu.times).reduce((a, b) => a + b, 0), 0);
        const idle = idle2 - idle1;
        const total = total2 - total1;
        const cpuUsage = total > 0 ? (100 - (100 * idle / total)) : 0;
        // Memory usage
        const totalMem = os_1.default.totalmem();
        const freeMem = os_1.default.freemem();
        const usedMem = totalMem - freeMem;
        const memoryUsage = totalMem > 0 ? (usedMem * 100) / totalMem : 0;
        // Disk usage: fallback to shell command (platform-specific)
        let diskUsage = 0;
        try {
            const { stdout: diskOutput } = await execAsync(`df -h ${config_1.config.meowcoin.dataDir} | awk 'NR==2{print $5}' | sed 's/%//'`);
            diskUsage = parseFloat(diskOutput);
        }
        catch (diskErr) {
            // TODO: Add Windows/Mac support for disk usage if needed
            diskUsage = 0;
        }
        return {
            cpuUsage: isNaN(cpuUsage) ? 0 : cpuUsage,
            memoryUsage: isNaN(memoryUsage) ? 0 : memoryUsage,
            diskUsage: isNaN(diskUsage) ? 0 : diskUsage,
        };
    }
    catch (error) {
        logger_1.logger.error(error, 'Failed to get system resource usage');
        return {
            cpuUsage: 0,
            memoryUsage: 0,
            diskUsage: 0,
        };
    }
}
// Perform action on node
async function performNodeAction(action) {
    try {
        logger_1.logger.info({ action }, 'Performing node action');
        switch (action) {
            case shared_1.NodeAction.START:
                await startNode();
                break;
            case shared_1.NodeAction.STOP:
                await stopNode();
                break;
            case shared_1.NodeAction.RESTART:
                await restartNode();
                break;
            case shared_1.NodeAction.BACKUP:
                await createBackup();
                break;
            default:
                throw new shared_1.AppError(shared_1.ErrorCode.VALIDATION_ERROR, `Unsupported action: ${action}`, 400);
        }
        // Get updated node info
        const nodeInfo = await getNodeInfo();
        // Publish node action event
        await redis_1.redis.publish('node:action', JSON.stringify({
            action,
            nodeId: nodeInfo.id,
            timestamp: new Date().toISOString(),
        }));
        // Emit node action event
        exports.nodeEvents.emit('action', {
            action,
            nodeInfo,
        });
        return nodeInfo;
    }
    catch (error) {
        logger_1.logger.error({ error, action }, 'Failed to perform node action');
        throw new shared_1.AppError(shared_1.ErrorCode.NODE_ERROR, `Failed to perform action: ${action}`, 500, { error });
    }
}
