const fs = require('fs');
const path = require('path');
const { execSync, spawn } = require('child_process');
const crypto = require('crypto');
const logger = require('./logging');
const config = require('./config');

/**
 * Plugin system for Meowcoin Docker
 */
class PluginSystem {
  /**
   * Create a new plugin manager
   * @param {Object} options - Configuration options
   */
  constructor(options = {}) {
    this.options = options;
    this.pluginDir = options.pluginDir || '/etc/meowcoin/plugins';
    this.pluginDataDir = '/var/lib/meowcoin/plugin-data';
    this.pluginStateDir = '/var/lib/meowcoin/plugin-state';
    this.enabledPluginsDir = path.join(this.pluginDir, 'enabled');
    this.isolation = config.get('pluginsIsolation', true);
    this.plugins = {};
    this.hooks = ['startup', 'shutdown', 'health_check', 'backup_pre', 'backup_post', 'backup_error', 'post_sync', 'periodic'];
  }

  /**
   * Initialize the plugin system
   */
  async initialize() {
    logger.info('Initializing plugin system', { module: 'plugins' });
    
    // Check if plugins are enabled
    if (!config.get('enablePlugins')) {
      logger.info('Plugin system is disabled', { module: 'plugins' });
      return;
    }
    
    // Create necessary directories
    this.createDirectories();
    
    // Load plugins
    await this.loadPlugins();
    
    logger.info('Plugin system initialized', { module: 'plugins' });
  }

  /**
   * Create necessary directories
   */
  createDirectories() {
    const dirs = [
      this.pluginDir,
      this.pluginDataDir,
      this.pluginStateDir,
      this.enabledPluginsDir
    ];
    
    dirs.forEach(dir => {
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true, mode: 0o750 });
        logger.debug(`Created directory: ${dir}`, { module: 'plugins' });
      }
    });
  }

  /**
   * Load plugins
   */
  async loadPlugins() {
    logger.info('Loading plugins', { module: 'plugins' });
    
    try {
      // Get list of plugin files
      const files = fs.readdirSync(this.pluginDir).filter(file => file.endsWith('.js') && file !== 'index.js');
      
      // Load each plugin
      for (const file of files) {
        await this.loadPlugin(file);
      }
      
      logger.info(`Loaded ${Object.keys(this.plugins).length} plugins`, { module: 'plugins' });
    } catch (error) {
      logger.error(`Failed to load plugins: ${error.message}`, { module: 'plugins', error });
    }
  }

  /**
   * Load a specific plugin
   * @param {string} file - Plugin file name
   */
  async loadPlugin(file) {
    const pluginName = path.basename(file, '.js');
    const pluginPath = path.join(this.pluginDir, file);
    
    logger.info(`Loading plugin: ${pluginName}`, { module: 'plugins' });
    
    try {
      // Check if plugin is enabled
      const enabledPath = path.join(this.enabledPluginsDir, file);
      const isEnabled = fs.existsSync(enabledPath) || fs.existsSync(path.join(this.enabledPluginsDir, `${pluginName}.json`));
      
      if (!isEnabled && config.get('enableAllPlugins') !== true) {
        logger.info(`Plugin ${pluginName} is not enabled, skipping`, { module: 'plugins' });
        return;
      }
      
      // Validate plugin before loading
      if (!await this.validatePlugin(pluginPath)) {
        logger.error(`Plugin ${pluginName} validation failed, skipping`, { module: 'plugins' });
        return;
      }
      
      // Create plugin data directory
      const pluginDataDir = path.join(this.pluginDataDir, pluginName);
      if (!fs.existsSync(pluginDataDir)) {
        fs.mkdirSync(pluginDataDir, { recursive: true, mode: 0o750 });
      }
      
      // Create plugin state directory
      const pluginStateDir = path.join(this.pluginStateDir, pluginName);
      if (!fs.existsSync(pluginStateDir)) {
        fs.mkdirSync(pluginStateDir, { recursive: true, mode: 0o750 });
      }
      
      // Load plugin
      const plugin = require(pluginPath);
      
      // Initialize plugin
      if (typeof plugin.initialize === 'function') {
        await plugin.initialize({
          dataDir: pluginDataDir,
          stateDir: pluginStateDir,
          logger: {
            info: (msg) => logger.info(msg, { module: `plugin:${pluginName}` }),
            error: (msg) => logger.error(msg, { module: `plugin:${pluginName}` }),
            warn: (msg) => logger.warn(msg, { module: `plugin:${pluginName}` }),
            debug: (msg) => logger.debug(msg, { module: `plugin:${pluginName}` })
          },
          config: {
            get: (key, defaultValue) => this.getPluginConfig(pluginName, key, defaultValue),
            set: (key, value) => this.setPluginConfig(pluginName, key, value)
          },
          state: {
            get: (key, defaultValue) => this.getPluginState(pluginName, key, defaultValue),
            set: (key, value) => this.setPluginState(pluginName, key, value)
          }
        });
      }
      
      // Store plugin
      this.plugins[pluginName] = {
        name: pluginName,
        path: pluginPath,
        hooks: {}
      };
      
      // Register hooks
      for (const hook of this.hooks) {
        if (typeof plugin[hook] === 'function') {
          this.plugins[pluginName].hooks[hook] = plugin[hook];
        }
      }
      
      logger.info(`Plugin ${pluginName} loaded successfully`, { module: 'plugins' });
    } catch (error) {
      logger.error(`Failed to load plugin ${pluginName}: ${error.message}`, { module: 'plugins', error });
    }
  }

  /**
   * Validate a plugin
   * @param {string} pluginPath - Plugin file path
   * @returns {boolean} Validation result
   */
  async validatePlugin(pluginPath) {
    try {
      // Read plugin file
      const content = fs.readFileSync(pluginPath, 'utf8');
      
      // Check for dangerous patterns
      const dangerousPatterns = [
        /eval\s*\(/,
        /Function\s*\(/,
        /execSync\s*\(/,
        /spawnSync\s*\(/,
        /childProcess\.exec/,
        /child_process\.exec/,
        /require\s*\(\s*['"]child_process/,
        /require\s*\(\s*['"]fs/,
        /process\.env/,
        /process\.exit/,
        /process\.kill/
      ];
      
      for (const pattern of dangerousPatterns) {
        if (pattern.test(content)) {
          logger.error(`Plugin contains potentially dangerous code: ${pattern}`, { module: 'plugins' });
          return false;
        }
      }
      
      // Basic syntax check
      try {
        require(pluginPath);
      } catch (error) {
        logger.error(`Plugin syntax error: ${error.message}`, { module: 'plugins' });
        return false;
      }
      
      return true;
    } catch (error) {
      logger.error(`Plugin validation error: ${error.message}`, { module: 'plugins', error });
      return false;
    }
  }

  /**
   * Execute hooks for all plugins
   * @param {string} hook - Hook name
   * @param {...any} args - Hook arguments
   */
  async executeHooks(hook, ...args) {
    logger.info(`Executing ${hook} hooks`, { module: 'plugins' });
    
    if (!config.get('enablePlugins')) {
      logger.debug(`Plugin system is disabled, skipping ${hook} hooks`, { module: 'plugins' });
      return;
    }
    
    const pluginsWithHook = Object.values(this.plugins).filter(plugin => plugin.hooks[hook]);
    
    if (pluginsWithHook.length === 0) {
      logger.debug(`No plugins have ${hook} hook registered`, { module: 'plugins' });
      return;
    }
    
    logger.debug(`Found ${pluginsWithHook.length} plugins with ${hook} hook registered`, { module: 'plugins' });
    
    // Execute hooks for each plugin
    for (const plugin of pluginsWithHook) {
      try {
        if (this.isolation) {
          await this.executeHookIsolated(plugin.name, hook, ...args);
        } else {
          await plugin.hooks[hook](...args);
        }
      } catch (error) {
        logger.error(`Failed to execute ${hook} hook for plugin ${plugin.name}: ${error.message}`, { module: 'plugins', error });
      }
    }
    
    logger.info(`Finished executing ${hook} hooks`, { module: 'plugins' });
  }

  /**
   * Execute a hook in isolation
   * @param {string} pluginName - Plugin name
   * @param {string} hook - Hook name
   * @param {...any} args - Hook arguments
   */
  async executeHookIsolated(pluginName, hook, ...args) {
    logger.debug(`Executing ${hook} hook for ${pluginName} in isolation`, { module: 'plugins' });
    
    const plugin = this.plugins[pluginName];
    if (!plugin) {
      throw new Error(`Plugin ${pluginName} not found`);
    }
    
    // Create temporary script file
    const scriptId = crypto.randomBytes(8).toString('hex');
    const scriptFile = `/tmp/plugin-${pluginName}-${hook}-${scriptId}.js`;
    
    try {
      // Create plugin execution script
      const pluginDataDir = path.join(this.pluginDataDir, pluginName);
      const pluginStateDir = path.join(this.pluginStateDir, pluginName);
      
      const scriptContent = `
const plugin = require('${plugin.path}');
const fs = require('fs');
const path = require('path');

// Setup plugin context
const context = {
  dataDir: '${pluginDataDir}',
  stateDir: '${pluginStateDir}',
  logger: {
    info: (msg) => console.log(JSON.stringify({ level: 'info', message: msg })),
    error: (msg) => console.log(JSON.stringify({ level: 'error', message: msg })),
    warn: (msg) => console.log(JSON.stringify({ level: 'warn', message: msg })),
    debug: (msg) => console.log(JSON.stringify({ level: 'debug', message: msg }))
  },
  config: {
    get: (key, defaultValue) => {
      try {
        const configFile = path.join('${pluginDataDir}', 'config.json');
        if (fs.existsSync(configFile)) {
          const config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
          return key in config ? config[key] : defaultValue;
        }
        return defaultValue;
      } catch (error) {
        return defaultValue;
      }
    },
    set: () => { /* Not available in isolation */ }
  },
  state: {
    get: (key, defaultValue) => {
      try {
        const stateFile = path.join('${pluginStateDir}', key);
        if (fs.existsSync(stateFile)) {
          return fs.readFileSync(stateFile, 'utf8');
        }
        return defaultValue;
      } catch (error) {
        return defaultValue;
      }
    },
    set: () => { /* Not available in isolation */ }
  }
};

// Execute hook
async function run() {
  try {
    const args = JSON.parse('${JSON.stringify(args)}');
    await plugin['${hook}'](...args);
    process.exit(0);
  } catch (error) {
    console.log(JSON.stringify({ level: 'error', message: error.message }));
    process.exit(1);
  }
}

run();
`;
      
      fs.writeFileSync(scriptFile, scriptContent, { mode: 0o700 });
      
      // Execute script with resource limits
      const child = spawn('node', ['--max-old-space-size=50', scriptFile], {
        timeout: 30000, // 30 seconds timeout
        stdio: 'pipe'
      });
      
      let output = '';
      
      child.stdout.on('data', (data) => {
        output += data.toString();
      });
      
      child.stderr.on('data', (data) => {
        logger.error(`Plugin ${pluginName} ${hook} hook error: ${data.toString()}`, { module: 'plugins' });
      });
      
      return new Promise((resolve, reject) => {
        child.on('close', (code) => {
          if (code !== 0) {
            logger.error(`Plugin ${pluginName} ${hook} hook exited with code ${code}`, { module: 'plugins' });
            reject(new Error(`Plugin ${pluginName} ${hook} hook exited with code ${code}`));
          } else {
            // Process output
            try {
              const logs = output.split('\n').filter(Boolean).map(line => JSON.parse(line));
              logs.forEach(log => {
                switch (log.level) {
                  case 'info':
                    logger.info(log.message, { module: `plugin:${pluginName}` });
                    break;
                  case 'error':
                    logger.error(log.message, { module: `plugin:${pluginName}` });
                    break;
                  case 'warn':
                    logger.warn(log.message, { module: `plugin:${pluginName}` });
                    break;
                  case 'debug':
                    logger.debug(log.message, { module: `plugin:${pluginName}` });
                    break;
                }
              });
              resolve();
            } catch (error) {
              logger.error(`Failed to process plugin output: ${error.message}`, { module: 'plugins', error });
              resolve();
            }
          }
          
          // Clean up
          fs.unlinkSync(scriptFile);
        });
      });
    } catch (error) {
      logger.error(`Failed to execute ${hook} hook for plugin ${pluginName} in isolation: ${error.message}`, { module: 'plugins', error });
      
      // Clean up
      if (fs.existsSync(scriptFile)) {
        fs.unlinkSync(scriptFile);
      }
      
      throw error;
    }
  }

  /**
   * Get plugin configuration
   * @param {string} pluginName - Plugin name
   * @param {string} key - Configuration key
   * @param {*} defaultValue - Default value
   * @returns {*} Configuration value
   */
  getPluginConfig(pluginName, key, defaultValue = null) {
    try {
      const configFile = path.join(this.pluginDataDir, pluginName, 'config.json');
      
      if (fs.existsSync(configFile)) {
        const config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
        return key in config ? config[key] : defaultValue;
      }
      
      return defaultValue;
    } catch (error) {
      logger.error(`Failed to get plugin config: ${error.message}`, { module: 'plugins', error });
      return defaultValue;
    }
  }

  /**
   * Set plugin configuration
   * @param {string} pluginName - Plugin name
   * @param {string} key - Configuration key
   * @param {*} value - Configuration value
   */
  setPluginConfig(pluginName, key, value) {
    try {
      const configDir = path.join(this.pluginDataDir, pluginName);
      const configFile = path.join(configDir, 'config.json');
      
      // Create config directory if it doesn't exist
      if (!fs.existsSync(configDir)) {
        fs.mkdirSync(configDir, { recursive: true, mode: 0o750 });
      }
      
      // Load existing config
      let config = {};
      if (fs.existsSync(configFile)) {
        config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
      }
      
      // Update config
      config[key] = value;
      
      // Save config
      fs.writeFileSync(configFile, JSON.stringify(config, null, 2), { mode: 0o640 });
    } catch (error) {
      logger.error(`Failed to set plugin config: ${error.message}`, { module: 'plugins', error });
    }
  }

  /**
   * Get plugin state
   * @param {string} pluginName - Plugin name
   * @param {string} key - State key
   * @param {*} defaultValue - Default value
   * @returns {*} State value
   */
  getPluginState(pluginName, key, defaultValue = null) {
    try {
      const stateFile = path.join(this.pluginStateDir, pluginName, key);
      
      if (fs.existsSync(stateFile)) {
        return fs.readFileSync(stateFile, 'utf8');
      }
      
      return defaultValue;
    } catch (error) {
      logger.error(`Failed to get plugin state: ${error.message}`, { module: 'plugins', error });
      return defaultValue;
    }
  }

  /**
   * Set plugin state
   * @param {string} pluginName - Plugin name
   * @param {string} key - State key
   * @param {*} value - State value
   */
  setPluginState(pluginName, key, value) {
    try {
      const stateDir = path.join(this.pluginStateDir, pluginName);
      const stateFile = path.join(stateDir, key);
      
      // Create state directory if it doesn't exist
      if (!fs.existsSync(stateDir)) {
        fs.mkdirSync(stateDir, { recursive: true, mode: 0o750 });
      }
      
      // Save state
      fs.writeFileSync(stateFile, value.toString(), { mode: 0o640 });
    } catch (error) {
      logger.error(`Failed to set plugin state: ${error.message}`, { module: 'plugins', error });
    }
  }

  /**
   * Enable a plugin
   * @param {string} pluginName - Plugin name
   */
  async enablePlugin(pluginName) {
    logger.info(`Enabling plugin: ${pluginName}`, { module: 'plugins' });
    
    try {
      const pluginFile = path.join(this.pluginDir, `${pluginName}.js`);
      const enabledLink = path.join(this.enabledPluginsDir, `${pluginName}.js`);
      
      // Check if plugin exists
      if (!fs.existsSync(pluginFile)) {
        throw new Error(`Plugin ${pluginName} not found`);
      }
      
      // Create symbolic link
      fs.symlinkSync(pluginFile, enabledLink);
      
      // Load plugin if not already loaded
      if (!this.plugins[pluginName]) {
        await this.loadPlugin(`${pluginName}.js`);
      }
      
      logger.info(`Plugin ${pluginName} enabled`, { module: 'plugins' });
    } catch (error) {
      logger.error(`Failed to enable plugin ${pluginName}: ${error.message}`, { module: 'plugins', error });
      throw error;
    }
  }

  /**
   * Disable a plugin
   * @param {string} pluginName - Plugin name
   */
  async disablePlugin(pluginName) {
    logger.info(`Disabling plugin: ${pluginName}`, { module: 'plugins' });
    
    try {
      const enabledLink = path.join(this.enabledPluginsDir, `${pluginName}.js`);
      
      // Remove symbolic link if it exists
      if (fs.existsSync(enabledLink)) {
        fs.unlinkSync(enabledLink);
      }
      
      // Remove from loaded plugins
      if (this.plugins[pluginName]) {
        delete this.plugins[pluginName];
      }
      
      logger.info(`Plugin ${pluginName} disabled`, { module: 'plugins' });
    } catch (error) {
      logger.error(`Failed to disable plugin ${pluginName}: ${error.message}`, { module: 'plugins', error });
      throw error;
    }
  }

  /**
   * List all plugins
   * @returns {Object[]} Plugin list
   */
  listPlugins() {
    try {
      const pluginFiles = fs.readdirSync(this.pluginDir).filter(file => file.endsWith('.js') && file !== 'index.js');
      
      return pluginFiles.map(file => {
        const pluginName = path.basename(file, '.js');
        const enabledLink = path.join(this.enabledPluginsDir, file);
        const isEnabled = fs.existsSync(enabledLink);
        const isLoaded = !!this.plugins[pluginName];
        
        return {
          name: pluginName,
          file,
          enabled: isEnabled,
          loaded: isLoaded,
          hooks: isLoaded ? Object.keys(this.plugins[pluginName].hooks) : []
        };
      });
    } catch (error) {
      logger.error(`Failed to list plugins: ${error.message}`, { module: 'plugins', error });
      return [];
    }
  }
}

module.exports = new PluginSystem();