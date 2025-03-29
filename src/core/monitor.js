const fs = require('fs');
const path = require('path');
const { execSync, spawn } = require('child_process');
const logger = require('./logging');
const config = require('./config');

/**
 * Monitoring system for Meowcoin Docker
 */
class Monitor {
  /**
   * Create a new monitoring manager
   * @param {Object} options - Configuration options
   */
  constructor(options = {}) {
    this.options = options;
    this.dataDir = options.dataDir || '/home/meowcoin/.meowcoin';
    this.metricsDir = '/var/lib/meowcoin/metrics';
    this.statusFile = '/tmp/meowcoin_health_status.json';
    this.alertHistoryFile = '/var/lib/meowcoin/alert_history.json';
    this.metrics = {};
    this.blockchainInfo = {};
    this.networkInfo = {};
    this.mempoolInfo = {};
    this.systemInfo = {};
  }

  /**
   * Initialize the monitoring system
   */
  async initialize() {
    logger.info('Initializing monitoring system', { module: 'monitor' });
    
    // Create necessary directories
    if (!fs.existsSync(this.metricsDir)) {
      fs.mkdirSync(this.metricsDir, { recursive: true, mode: 0o750 });
    }
    
    if (!fs.existsSync(path.dirname(this.alertHistoryFile))) {
      fs.mkdirSync(path.dirname(this.alertHistoryFile), { recursive: true, mode: 0o750 });
    }
    
    // Initialize alert history if it doesn't exist
    if (!fs.existsSync(this.alertHistoryFile)) {
      fs.writeFileSync(this.alertHistoryFile, JSON.stringify({}, null, 2));
    }
    
    // Setup metrics exporter if enabled
    if (config.get('enableMetrics')) {
      await this.setupMetricsExporter();
    }
    
    logger.info('Monitoring system initialized', { module: 'monitor' });
  }

  /**
   * Setup metrics exporter
   */
  async setupMetricsExporter() {
    logger.info('Setting up metrics exporter', { module: 'monitor' });
    
    // Start exporter process
    const exporterScript = '/usr/local/bin/meowcoin-exporter.js';
    
    // Check if script exists
    if (!fs.existsSync(exporterScript)) {
      logger.error('Metrics exporter script not found', { module: 'monitor' });
      return;
    }
    
    // Start exporter process
    const exporter = spawn('node', [exporterScript], {
      detached: true,
      stdio: 'ignore'
    });
    
    exporter.unref();
    
    logger.info('Metrics exporter started', { module: 'monitor' });
  }

  /**
   * Run a health check
   * @returns {Object} Health check results
   */
  async runHealthCheck() {
    logger.info('Running health check', { module: 'monitor' });
    
    const results = {
      timestamp: new Date().toISOString(),
      status: 'unhealthy',
      issues: []
    };
    
    // Check if node is running
    if (!await this.isNodeRunning()) {
      results.issues.push({
        type: 'node_offline',
        message: 'Meowcoin node is not running'
      });
      this.updateStatus(results);
      return results;
    }
    
    // Collect blockchain info
    await this.collectBlockchainInfo();
    
    // Collect network info
    await this.collectNetworkInfo();
    
    // Collect mempool info
    await this.collectMempoolInfo();
    
    // Collect system info
    await this.collectSystemInfo();
    
    // Check for issues
    await this.checkBlockchainIssues(results);
    await this.checkNetworkIssues(results);
    await this.checkDiskIssues(results);
    await this.checkMemoryIssues(results);
    
    // Set status based on issues
    if (results.issues.length === 0) {
      results.status = 'healthy';
    }
    
    // Update status file
    this.updateStatus(results);
    
    logger.info(`Health check completed: ${results.status}`, { module: 'monitor' });
    return results;
  }

  /**
   * Check if node is running
   * @returns {boolean} Is node running
   */
  async isNodeRunning() {
    try {
      execSync('pgrep -x meowcoind', { stdio: 'pipe' });
      return true;
    } catch (error) {
      logger.error('Meowcoin node is not running', { module: 'monitor' });
      this.sendAlert('node_offline', 'Meowcoin node is not running', 'critical');
      return false;
    }
  }

  /**
   * Collect blockchain info
   */
  async collectBlockchainInfo() {
    try {
      const output = execSync('meowcoin-cli getblockchaininfo', { encoding: 'utf8' });
      this.blockchainInfo = JSON.parse(output);
      
      // Record metrics
      this.recordMetric('blocks', this.blockchainInfo.blocks);
      this.recordMetric('headers', this.blockchainInfo.headers);
      this.recordMetric('difficulty', this.blockchainInfo.difficulty);
      this.recordMetric('verification_progress', this.blockchainInfo.verificationprogress);
      
      logger.debug('Collected blockchain info', { module: 'monitor' });
    } catch (error) {
      logger.error(`Failed to collect blockchain info: ${error.message}`, { module: 'monitor', error });
      this.sendAlert('rpc_error', 'Failed to collect blockchain info', 'warning');
    }
  }

  /**
   * Collect network info
   */
  async collectNetworkInfo() {
    try {
      const output = execSync('meowcoin-cli getnetworkinfo', { encoding: 'utf8' });
      this.networkInfo = JSON.parse(output);
      
      // Collect peer info
      const peerOutput = execSync('meowcoin-cli getpeerinfo', { encoding: 'utf8' });
      const peerInfo = JSON.parse(peerOutput);
      
      this.networkInfo.connections = peerInfo.length;
      
      // Record metrics
      this.recordMetric('connections', this.networkInfo.connections);
      this.recordMetric('version', this.networkInfo.version);
      
      logger.debug('Collected network info', { module: 'monitor' });
    } catch (error) {
      logger.error(`Failed to collect network info: ${error.message}`, { module: 'monitor', error });
      this.sendAlert('rpc_error', 'Failed to collect network info', 'warning');
    }
  }

  /**
   * Collect mempool info
   */
  async collectMempoolInfo() {
    try {
      const output = execSync('meowcoin-cli getmempoolinfo', { encoding: 'utf8' });
      this.mempoolInfo = JSON.parse(output);
      
      // Record metrics
      this.recordMetric('mempool_size', this.mempoolInfo.size);
      this.recordMetric('mempool_bytes', this.mempoolInfo.bytes);
      this.recordMetric('mempool_usage', this.mempoolInfo.usage);
      
      logger.debug('Collected mempool info', { module: 'monitor' });
    } catch (error) {
      logger.error(`Failed to collect mempool info: ${error.message}`, { module: 'monitor', error });
      this.sendAlert('rpc_error', 'Failed to collect mempool info', 'warning');
    }
  }

  /**
   * Collect system info
   */
  async collectSystemInfo() {
    try {
      // Collect disk usage
      const diskOutput = execSync('df -k ' + this.dataDir, { encoding: 'utf8' });
      const diskInfo = diskOutput.split('\n')[1].split(/\s+/);
      
      this.systemInfo.totalSpace = parseInt(diskInfo[1]) * 1024;
      this.systemInfo.usedSpace = parseInt(diskInfo[2]) * 1024;
      this.systemInfo.availableSpace = parseInt(diskInfo[3]) * 1024;
      this.systemInfo.diskUsage = parseInt(diskInfo[4].replace('%', ''));
      
      // Collect memory usage
      const memoryOutput = execSync('free -b', { encoding: 'utf8' });
      const memoryInfo = memoryOutput.split('\n')[1].split(/\s+/);
      
      this.systemInfo.totalMemory = parseInt(memoryInfo[1]);
      this.systemInfo.usedMemory = parseInt(memoryInfo[2]);
      this.systemInfo.freeMemory = parseInt(memoryInfo[3]);
      this.systemInfo.memoryUsage = Math.round((this.systemInfo.usedMemory / this.systemInfo.totalMemory) * 100);
      
      // Collect CPU usage
      const loadAvg = fs.readFileSync('/proc/loadavg', 'utf8').split(' ');
      this.systemInfo.loadAvg1 = parseFloat(loadAvg[0]);
      this.systemInfo.loadAvg5 = parseFloat(loadAvg[1]);
      this.systemInfo.loadAvg15 = parseFloat(loadAvg[2]);
      
      // Get CPU info
      const cpuInfo = fs.readFileSync('/proc/cpuinfo', 'utf8');
      this.systemInfo.cpuCount = cpuInfo.match(/^processor/gm).length;
      
      // Calculate CPU usage percentage
      this.systemInfo.cpuUsage = Math.round((this.systemInfo.loadAvg1 / this.systemInfo.cpuCount) * 100);
      
      // Record metrics
      this.recordMetric('disk_usage', this.systemInfo.diskUsage);
      this.recordMetric('memory_usage', this.systemInfo.memoryUsage);
      this.recordMetric('cpu_usage', this.systemInfo.cpuUsage);
      
      logger.debug('Collected system info', { module: 'monitor' });
    } catch (error) {
      logger.error(`Failed to collect system info: ${error.message}`, { module: 'monitor', error });
    }
  }

  /**
   * Check for blockchain issues
   * @param {Object} results - Health check results
   */
  async checkBlockchainIssues(results) {
    // Check if node is synced
    if (this.blockchainInfo.blocks < this.blockchainInfo.headers) {
      const blocksBehind = this.blockchainInfo.headers - this.blockchainInfo.blocks;
      
      if (blocksBehind > 6) {
        results.issues.push({
          type: 'node_behind',
          message: `Node is ${blocksBehind} blocks behind`,
          value: blocksBehind
        });
        
        this.sendAlert('node_behind', `Node is ${blocksBehind} blocks behind`, 'warning');
      }
    }
    
    // Check verification progress
    if (this.blockchainInfo.verificationprogress < 0.9999) {
      const progress = Math.round(this.blockchainInfo.verificationprogress * 10000) / 100;
      
      results.issues.push({
        type: 'node_syncing',
        message: `Node is syncing (${progress}%)`,
        value: progress
      });
    }
  }

  /**
   * Check for network issues
   * @param {Object} results - Health check results
   */
  async checkNetworkIssues(results) {
    // Check connection count
    if (this.networkInfo.connections < 3) {
      results.issues.push({
        type: 'low_connections',
        message: `Node has only ${this.networkInfo.connections} connections`,
        value: this.networkInfo.connections
      });
      
      this.sendAlert('low_connections', `Node has only ${this.networkInfo.connections} connections`, 'warning');
    }
  }

  /**
   * Check for disk issues
   * @param {Object} results - Health check results
   */
  async checkDiskIssues(results) {
    // Check disk usage
    if (this.systemInfo.diskUsage > 90) {
      results.issues.push({
        type: 'high_disk_usage',
        message: `Disk usage is ${this.systemInfo.diskUsage}%`,
        value: this.systemInfo.diskUsage
      });
      
      this.sendAlert('high_disk_usage', `Disk usage is ${this.systemInfo.diskUsage}%`, 'warning');
    }
    
    // Check available space
    const availableGB = Math.round((this.systemInfo.availableSpace / 1024 / 1024 / 1024) * 100) / 100;
    if (availableGB < 5) {
      results.issues.push({
        type: 'low_disk_space',
        message: `Only ${availableGB}GB of disk space available`,
        value: availableGB
      });
      
      this.sendAlert('low_disk_space', `Only ${availableGB}GB of disk space available`, 'critical');
    }
  }

  /**
   * Check for memory issues
   * @param {Object} results - Health check results
   */
  async checkMemoryIssues(results) {
    // Check memory usage
    if (this.systemInfo.memoryUsage > 95) {
      results.issues.push({
        type: 'high_memory_usage',
        message: `Memory usage is ${this.systemInfo.memoryUsage}%`,
        value: this.systemInfo.memoryUsage
      });
      
      this.sendAlert('high_memory_usage', `Memory usage is ${this.systemInfo.memoryUsage}%`, 'critical');
    }
    
    // Check CPU usage
    if (this.systemInfo.cpuUsage > 90) {
      results.issues.push({
        type: 'high_cpu_usage',
        message: `CPU usage is ${this.systemInfo.cpuUsage}%`,
        value: this.systemInfo.cpuUsage
      });
      
      this.sendAlert('high_cpu_usage', `CPU usage is ${this.systemInfo.cpuUsage}%`, 'warning');
    }
  }

  /**
   * Update status file
   * @param {Object} status - Status data
   */
  updateStatus(status) {
    try {
      fs.writeFileSync(this.statusFile, JSON.stringify(status, null, 2));
      logger.debug('Updated status file', { module: 'monitor' });
    } catch (error) {
      logger.error(`Failed to update status file: ${error.message}`, { module: 'monitor', error });
    }
  }

  /**
   * Record a metric
   * @param {string} name - Metric name
   * @param {number} value - Metric value
   * @param {string} type - Metric type
   */
  recordMetric(name, value, type = 'gauge') {
    try {
      // Create metrics directory if it doesn't exist
      if (!fs.existsSync(this.metricsDir)) {
        fs.mkdirSync(this.metricsDir, { recursive: true, mode: 0o750 });
      }
      
      // Update metric file
      const metricFile = path.join(this.metricsDir, name);
      
      // Store current value
      fs.writeFileSync(metricFile, value.toString());
      
      // Also store in metrics object
      this.metrics[name] = value;
      
      // Store history for gauges
      if (type === 'gauge') {
        const historyFile = path.join(this.metricsDir, `${name}.history`);
        const timestamp = Math.floor(Date.now() / 1000);
        
        let history = [];
        if (fs.existsSync(historyFile)) {
          history = JSON.parse(fs.readFileSync(historyFile, 'utf8'));
        }
        
        // Add new data point
        history.push({
          timestamp,
          value
        });
        
        // Keep only last 1000 data points
        if (history.length > 1000) {
          history = history.slice(history.length - 1000);
        }
        
        fs.writeFileSync(historyFile, JSON.stringify(history));
      }
      
      // For counters, store increment
      if (type === 'counter') {
        const counterFile = path.join(this.metricsDir, `${name}.counter`);
        let counter = 0;
        
        if (fs.existsSync(counterFile)) {
          counter = parseInt(fs.readFileSync(counterFile, 'utf8'));
        }
        
        counter += value;
        fs.writeFileSync(counterFile, counter.toString());
      }
    } catch (error) {
      logger.error(`Failed to record metric ${name}: ${error.message}`, { module: 'monitor', error });
    }
  }

  /**
   * Send an alert
   * @param {string} type - Alert type
   * @param {string} message - Alert message
   * @param {string} severity - Alert severity
   */
  sendAlert(type, message, severity = 'warning') {
    logger.warn(`ALERT [${severity}]: ${message}`, { module: 'monitor', type });
    
    try {
      // Update alert history
      let alertHistory = {};
      if (fs.existsSync(this.alertHistoryFile)) {
        alertHistory = JSON.parse(fs.readFileSync(this.alertHistoryFile, 'utf8'));
      }
      
      alertHistory[type] = {
        timestamp: Math.floor(Date.now() / 1000),
        message,
        severity
      };
      
      fs.writeFileSync(this.alertHistoryFile, JSON.stringify(alertHistory, null, 2));
      
      // Record alert metric
      this.recordMetric('alerts_total', 1, 'counter');
      this.recordMetric(`alert_${severity}_total`, 1, 'counter');
      this.recordMetric(`alert_${type}_total`, 1, 'counter');
      
      // Send actual alert notification based on configured method
      this.notifyAlert(type, message, severity);
    } catch (error) {
      logger.error(`Failed to send alert: ${error.message}`, { module: 'monitor', error });
    }
  }

  /**
   * Send alert notification
   * @param {string} type - Alert type
   * @param {string} message - Alert message
   * @param {string} severity - Alert severity
   */
  notifyAlert(type, message, severity) {
    const alertMethod = config.get('alertMethod', 'log');
    
    switch (alertMethod) {
      case 'webhook':
        this.sendWebhookAlert(type, message, severity);
        break;
      case 'email':
        this.sendEmailAlert(type, message, severity);
        break;
      case 'log':
      default:
        // Already logged in sendAlert
        break;
    }
  }

  /**
   * Send webhook alert
   * @param {string} type - Alert type
   * @param {string} message - Alert message
   * @param {string} severity - Alert severity
   */
  sendWebhookAlert(type, message, severity) {
    const webhookUrl = config.get('webhookUrl');
    
    if (!webhookUrl) {
      logger.error('Webhook URL not configured', { module: 'monitor' });
      return;
    }
    
    try {
      const payload = {
        type,
        message,
        severity,
        timestamp: new Date().toISOString(),
        node: {
          version: this.networkInfo.version || 'unknown',
          blocks: this.blockchainInfo.blocks || 0,
          connections: this.networkInfo.connections || 0
        },
        system: {
          diskUsage: this.systemInfo.diskUsage || 0,
          memoryUsage: this.systemInfo.memoryUsage || 0,
          cpuUsage: this.systemInfo.cpuUsage || 0
        }
      };
      
      // Send webhook
      execSync(`curl -s -X POST -H "Content-Type: application/json" -d '${JSON.stringify(payload)}' ${webhookUrl}`, { stdio: 'pipe' });
      
      logger.debug('Sent webhook alert', { module: 'monitor', type });
    } catch (error) {
      logger.error(`Failed to send webhook alert: ${error.message}`, { module: 'monitor', error });
    }
  }

  /**
   * Send email alert
   * @param {string} type - Alert type
   * @param {string} message - Alert message
   * @param {string} severity - Alert severity
   */
  sendEmailAlert(type, message, severity) {
    const emailTo = config.get('emailTo');
    const emailFrom = config.get('emailFrom', 'meowcoin-node@localhost');
    const smtpServer = config.get('smtpServer', 'localhost');
    
    if (!emailTo) {
      logger.error('Email recipient not configured', { module: 'monitor' });
      return;
    }
    
    try {
      const subject = `[${severity.toUpperCase()}] Meowcoin Node Alert: ${type}`;
      const body = `
Alert Type: ${type}
Severity: ${severity}
Time: ${new Date().toISOString()}
Message: ${message}

Node Status:
- Version: ${this.networkInfo.version || 'unknown'}
- Blocks: ${this.blockchainInfo.blocks || 0}
- Connections: ${this.networkInfo.connections || 0}

System Status:
- Disk Usage: ${this.systemInfo.diskUsage || 0}%
- Memory Usage: ${this.systemInfo.memoryUsage || 0}%
- CPU Usage: ${this.systemInfo.cpuUsage || 0}%
`;
      
      // Create temporary email file
      const emailFile = `/tmp/alert-${Date.now()}.eml`;
      fs.writeFileSync(emailFile, body);
      
      // Send email
      execSync(`mail -s "${subject}" -r "${emailFrom}" ${emailTo} < ${emailFile}`, { stdio: 'pipe' });
      
      // Clean up
      fs.unlinkSync(emailFile);
      
      logger.debug('Sent email alert', { module: 'monitor', type });
    } catch (error) {
      logger.error(`Failed to send email alert: ${error.message}`, { module: 'monitor', error });
    }
  }
}

module.exports = new Monitor();