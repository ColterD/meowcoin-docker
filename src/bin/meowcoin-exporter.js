#!/usr/bin/env node

/**
 * Meowcoin metrics exporter
 * Exports metrics for Prometheus monitoring
 */

const express = require('express');
const { execSync } = require('child_process');
const fs = require('fs');
const core = require('../core');

// Constants
const PORT = process.env.METRICS_PORT || 9449;
const UPDATE_INTERVAL = process.env.METRICS_UPDATE_INTERVAL || 15000; // 15 seconds

// Initialize
async function init() {
  await core.logging.initialize();
  await core.config.initialize();
  await core.monitor.initialize();
  
  core.logging.info('Metrics exporter initialized', { module: 'exporter' });
}

// Collect metrics
async function collectMetrics() {
  const metrics = {
    // Node info
    'meowcoin_version': 0,
    'meowcoin_protocol_version': 0,
    
    // Blockchain metrics
    'meowcoin_blocks': 0,
    'meowcoin_headers': 0,
    'meowcoin_difficulty': 0,
    'meowcoin_verification_progress': 0,
    'meowcoin_blockchain_size_bytes': 0,
    
    // Network metrics
    'meowcoin_connections': 0,
    'meowcoin_network_hashps': 0,
    
    // Mempool metrics
    'meowcoin_mempool_size': 0,
    'meowcoin_mempool_bytes': 0,
    'meowcoin_mempool_usage': 0,
    'meowcoin_mempool_max': 0,
    
    // System metrics
    'meowcoin_system_cpu_usage': 0,
    'meowcoin_system_memory_usage': 0,
    'meowcoin_system_disk_usage': 0,
    'meowcoin_system_disk_free_bytes': 0,
    
    // Uptime
    'meowcoin_uptime_seconds': 0
  };
  
  try {
    // Node info
    try {
      const networkInfo = JSON.parse(execSync('meowcoin-cli getnetworkinfo', { encoding: 'utf8' }));
      metrics.meowcoin_version = networkInfo.version || 0;
      metrics.meowcoin_protocol_version = networkInfo.protocolversion || 0;
    } catch (error) {
      core.logging.error(`Failed to collect network info: ${error.message}`, { module: 'exporter' });
    }
    
    // Blockchain metrics
    try {
      const blockchainInfo = JSON.parse(execSync('meowcoin-cli getblockchaininfo', { encoding: 'utf8' }));
      metrics.meowcoin_blocks = blockchainInfo.blocks || 0;
      metrics.meowcoin_headers = blockchainInfo.headers || 0;
      metrics.meowcoin_difficulty = blockchainInfo.difficulty || 0;
      metrics.meowcoin_verification_progress = blockchainInfo.verificationprogress || 0;
      metrics.meowcoin_blockchain_size_bytes = blockchainInfo.size_on_disk || 0;
    } catch (error) {
      core.logging.error(`Failed to collect blockchain info: ${error.message}`, { module: 'exporter' });
    }
    
    // Network metrics
    try {
      const connectionCount = parseInt(execSync('meowcoin-cli getconnectioncount', { encoding: 'utf8' })) || 0;
      metrics.meowcoin_connections = connectionCount;
      
      const networkHashPs = parseFloat(execSync('meowcoin-cli getnetworkhashps', { encoding: 'utf8' })) || 0;
      metrics.meowcoin_network_hashps = networkHashPs;
    } catch (error) {
      core.logging.error(`Failed to collect network metrics: ${error.message}`, { module: 'exporter' });
    }
    
    // Mempool metrics
    try {
      const mempoolInfo = JSON.parse(execSync('meowcoin-cli getmempoolinfo', { encoding: 'utf8' }));
      metrics.meowcoin_mempool_size = mempoolInfo.size || 0;
      metrics.meowcoin_mempool_bytes = mempoolInfo.bytes || 0;
      metrics.meowcoin_mempool_usage = mempoolInfo.usage || 0;
      metrics.meowcoin_mempool_max = mempoolInfo.maxmempool || 0;
    } catch (error) {
      core.logging.error(`Failed to collect mempool info: ${error.message}`, { module: 'exporter' });
    }
    
    // System metrics
    try {
      // CPU usage
      const loadAvg = fs.readFileSync('/proc/loadavg', 'utf8').split(' ');
      const cpuInfo = fs.readFileSync('/proc/cpuinfo', 'utf8');
      const cpuCount = cpuInfo.match(/^processor/gm).length;
      const cpuUsage = Math.round((parseFloat(loadAvg[0]) / cpuCount) * 100);
      metrics.meowcoin_system_cpu_usage = cpuUsage;
      
      // Memory usage
      const memoryInfo = fs.readFileSync('/proc/meminfo', 'utf8');
      const totalMemory = parseInt(memoryInfo.match(/MemTotal:\s+(\d+)/)[1]) * 1024;
      const freeMemory = parseInt(memoryInfo.match(/MemAvailable:\s+(\d+)/)[1]) * 1024;
      const memoryUsage = Math.round(((totalMemory - freeMemory) / totalMemory) * 100);
      metrics.meowcoin_system_memory_usage = memoryUsage;
      
      // Disk usage
      const diskInfo = execSync('df -B1 /home/meowcoin/.meowcoin', { encoding: 'utf8' });
      const diskParts = diskInfo.split('\n')[1].split(/\s+/);
      const totalSpace = parseInt(diskParts[1]);
      const usedSpace = parseInt(diskParts[2]);
      const freeSpace = parseInt(diskParts[3]);
      const diskUsage = Math.round((usedSpace / totalSpace) * 100);
      metrics.meowcoin_system_disk_usage = diskUsage;
      metrics.meowcoin_system_disk_free_bytes = freeSpace;
    } catch (error) {
      core.logging.error(`Failed to collect system metrics: ${error.message}`, { module: 'exporter' });
    }
    
    // Uptime
    try {
      const uptimeInfo = JSON.parse(execSync('meowcoin-cli uptime', { encoding: 'utf8' }));
      metrics.meowcoin_uptime_seconds = uptimeInfo || 0;
    } catch (error) {
      core.logging.error(`Failed to collect uptime: ${error.message}`, { module: 'exporter' });
    }
  } catch (error) {
    core.logging.error(`Failed to collect metrics: ${error.message}`, { module: 'exporter' });
  }
  
  return metrics;
}

// Format metrics for Prometheus
function formatMetrics(metrics) {
  let output = '';
  
  // Add metric lines
  for (const [name, value] of Object.entries(metrics)) {
    output += `# HELP ${name} Meowcoin node metric\n`;
    output += `# TYPE ${name} gauge\n`;
    output += `${name} ${value}\n`;
  }
  
  return output;
}

// Start server
async function startServer() {
  const app = express();
  
  // Metrics endpoint
  app.get('/metrics', async (req, res) => {
    try {
      const metrics = await collectMetrics();
      const formattedMetrics = formatMetrics(metrics);
      res.set('Content-Type', 'text/plain');
      res.send(formattedMetrics);
    } catch (error) {
      core.logging.error(`Failed to serve metrics: ${error.message}`, { module: 'exporter' });
      res.status(500).send('Error collecting metrics');
    }
  });
  
  // Start server
  app.listen(PORT, () => {
    core.logging.info(`Metrics exporter listening on port ${PORT}`, { module: 'exporter' });
  });
}

// Run exporter
init()
  .then(startServer)
  .catch(error => {
    console.error(`Failed to start metrics exporter: ${error.message}`);
    process.exit(1);
  });