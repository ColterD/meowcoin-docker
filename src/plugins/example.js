/**
 * Example plugin for Meowcoin Docker
 * Demonstrates plugin API usage and capabilities
 */

// Plugin metadata
const metadata = {
    name: 'example',
    version: '1.0.0',
    description: 'Example plugin for Meowcoin Docker',
    author: 'MeowcoinDev'
  };
  
  // Plugin state
  let state = {
    startupTime: null,
    lastRunTime: null,
    runCount: 0
  };
  
  /**
   * Initialize plugin
   * @param {Object} context - Plugin context
   */
  function initialize(context) {
    // Store context for later use
    this.context = context;
    
    // Load previous state if available
    const savedRunCount = context.state.get('runCount', 0);
    state.runCount = parseInt(savedRunCount);
    
    context.logger.info(`Example plugin initialized (previous runs: ${state.runCount})`);
  }
  
  /**
   * Startup hook
   * Called when the container starts
   */
  function startup() {
    state.startupTime = new Date();
    state.runCount++;
    
    this.context.logger.info(`Container started at ${state.startupTime.toISOString()}`);
    this.context.state.set('runCount', state.runCount.toString());
  }
  
  /**
   * Shutdown hook
   * Called when the container stops
   */
  function shutdown() {
    const uptime = new Date() - state.startupTime;
    this.context.logger.info(`Container uptime: ${formatUptime(uptime)}`);
  }
  
  /**
   * Health check hook
   * Called during health checks
   * @param {string} status - Health status
   */
  function health_check(status) {
    state.lastRunTime = new Date();
    
    this.context.logger.info(`Health check status: ${status}`);
    this.context.state.set('lastHealthCheck', state.lastRunTime.toISOString());
  }
  
  /**
   * Pre-backup hook
   * Called before backup creation
   */
  function backup_pre() {
    this.context.logger.info('Preparing for backup...');
  }
  
  /**
   * Post-backup hook
   * Called after backup completion
   * @param {string} backupFile - Backup file path
   * @param {string} backupSize - Backup file size
   */
  function backup_post(backupFile, backupSize) {
    this.context.logger.info(`Backup completed: ${backupFile} (${backupSize})`);
  }
  
  /**
   * Format uptime in human-readable format
   * @param {number} ms - Uptime in milliseconds
   * @returns {string} Formatted uptime
   */
  function formatUptime(ms) {
    const seconds = Math.floor(ms / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);
    
    return `${days}d ${hours % 24}h ${minutes % 60}m ${seconds % 60}s`;
  }
  
  // Export plugin
  module.exports = {
    metadata,
    initialize,
    startup,
    shutdown,
    health_check,
    backup_pre,
    backup_post
  };