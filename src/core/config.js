const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');
const Joi = require('joi');
const logger = require('./logging');
const crypto = require('crypto');

/**
 * Configuration management for Meowcoin Docker
 */
class Config {
  /**
   * Create a new configuration manager
   * @param {Object} options - Configuration options
   */
  constructor(options = {}) {
    this.options = options;
    this.configDir = options.configDir || '/etc/meowcoin';
    this.dataDir = options.dataDir || '/home/meowcoin/.meowcoin';
    this.secretsDir = options.secretsDir || '/run/secrets';
    this.config = {};
    this.schema = this.createValidationSchema();
  }

  /**
   * Create validation schema for configuration
   * @returns {Joi.ObjectSchema} Validation schema
   */
  createValidationSchema() {
    return Joi.object({
      // Core configuration
      rpcUser: Joi.string().alphanum().min(3).max(32).default('meowcoin'),
      rpcPassword: Joi.string().min(16),
      rpcBind: Joi.string().ip().default('127.0.0.1'),
      rpcAllowIp: Joi.string().default('127.0.0.1'),
      
      // Security settings
      enableSsl: Joi.boolean().default(false),
      enableFail2Ban: Joi.boolean().default(false),
      enableJwtAuth: Joi.boolean().default(false),
      enableReadonlyFs: Joi.boolean().default(false),
      
      // Resource settings
      dbCache: Joi.number().integer().min(128).max(16384),
      maxConnections: Joi.number().integer().min(1).max(1000),
      maxMempool: Joi.number().integer().min(64).max(4096),
      rpcThreads: Joi.number().integer().min(1).max(16),
      rpcTimeout: Joi.number().integer().min(5).max(600),
      
      // Monitoring settings
      enableMetrics: Joi.boolean().default(false),
      
      // Backup settings
      enableBackups: Joi.boolean().default(false),
      backupSchedule: Joi.string().default('0 0 * * *'),
      maxBackups: Joi.number().integer().min(1).max(100).default(7),
      backupRemoteEnabled: Joi.boolean().default(false),
      
      // Plugin settings
      enablePlugins: Joi.boolean().default(false),
      pluginsIsolation: Joi.boolean().default(true)
    });
  }

  /**
   * Initialize the configuration system
   */
  async initialize() {
    logger.info('Initializing configuration system', { module: 'config' });
    
    // Load configuration from various sources in order of precedence
    await this.loadFromDefaults();
    await this.loadFromConfigFile();
    await this.loadFromEnvironment();
    await this.loadFromSecrets();
    
    // Validate configuration
    await this.validateConfig();
    
    // Ensure RPC password exists
    await this.ensureRpcPassword();
    
    logger.info('Configuration system initialized', { module: 'config' });
  }

  /**
   * Load defaults into configuration
   */
  async loadFromDefaults() {
    // Default values are already set in the schema
    this.config = {
      rpcUser: 'meowcoin',
      rpcBind: '127.0.0.1',
      rpcAllowIp: '127.0.0.1',
      enableSsl: false,
      enableFail2Ban: false,
      enableJwtAuth: false,
      enableReadonlyFs: false,
      enableMetrics: false,
      enableBackups: false,
      backupSchedule: '0 0 * * *',
      maxBackups: 7,
      backupRemoteEnabled: false,
      enablePlugins: false,
      pluginsIsolation: true
    };
    
    logger.debug('Loaded default configuration', { module: 'config' });
  }

  /**
   * Load configuration from config file
   */
  async loadFromConfigFile() {
    const configFile = path.join(this.configDir, 'config.yaml');
    
    if (fs.existsSync(configFile)) {
      try {
        const fileContent = fs.readFileSync(configFile, 'utf8');
        const fileConfig = yaml.load(fileContent);
        
        // Merge with existing config
        this.config = { ...this.config, ...fileConfig };
        
        logger.debug('Loaded configuration from file', { module: 'config', file: configFile });
      } catch (error) {
        logger.error(`Failed to load configuration file: ${error.message}`, { module: 'config', error });
      }
    } else {
      logger.debug('No configuration file found', { module: 'config', file: configFile });
    }
  }

  /**
   * Load configuration from environment variables
   */
  async loadFromEnvironment() {
    // Map of environment variables to config keys
    const envMapping = {
      RPC_USER: 'rpcUser',
      RPC_PASSWORD: 'rpcPassword',
      RPC_BIND: 'rpcBind',
      RPC_ALLOWIP: 'rpcAllowIp',
      ENABLE_SSL: 'enableSsl',
      ENABLE_FAIL2BAN: 'enableFail2Ban',
      ENABLE_JWT_AUTH: 'enableJwtAuth',
      ENABLE_READONLY_FS: 'enableReadonlyFs',
      DBCACHE: 'dbCache',
      MAX_CONNECTIONS: 'maxConnections',
      MAXMEMPOOL: 'maxMempool',
      RPC_THREADS: 'rpcThreads',
      RPC_TIMEOUT: 'rpcTimeout',
      ENABLE_METRICS: 'enableMetrics',
      ENABLE_BACKUPS: 'enableBackups',
      BACKUP_SCHEDULE: 'backupSchedule',
      MAX_BACKUPS: 'maxBackups',
      BACKUP_REMOTE_ENABLED: 'backupRemoteEnabled',
      ENABLE_PLUGINS: 'enablePlugins',
      PLUGINS_ISOLATION: 'pluginsIsolation'
    };
    
    // Process each environment variable
    Object.entries(envMapping).forEach(([envVar, configKey]) => {
      if (process.env[envVar] !== undefined) {
        // Convert string boolean values
        if (process.env[envVar] === 'true') {
          this.config[configKey] = true;
        } else if (process.env[envVar] === 'false') {
          this.config[configKey] = false;
        } else if (!isNaN(Number(process.env[envVar]))) {
          // Convert numeric values
          this.config[configKey] = Number(process.env[envVar]);
        } else {
          // String values
          this.config[configKey] = process.env[envVar];
        }
      }
    });
    
    logger.debug('Loaded configuration from environment', { module: 'config' });
  }

  /**
   * Load configuration from Docker secrets
   */
  async loadFromSecrets() {
    // Map of secret files to config keys
    const secretMapping = {
      'meowcoin_rpc_password': 'rpcPassword',
      'meowcoin_jwt_key': 'jwtKey',
      'meowcoin_backup_key': 'backupEncryptionKey'
    };
    
    // Process each secret
    Object.entries(secretMapping).forEach(([secretFile, configKey]) => {
      const secretPath = path.join(this.secretsDir, secretFile);
      
      if (fs.existsSync(secretPath)) {
        try {
          const secretValue = fs.readFileSync(secretPath, 'utf8').trim();
          this.config[configKey] = secretValue;
          
          logger.debug(`Loaded secret for ${configKey}`, { module: 'config' });
        } catch (error) {
          logger.error(`Failed to load secret ${secretFile}: ${error.message}`, { module: 'config', error });
        }
      }
    });
  }

  /**
   * Validate configuration against schema
   */
  async validateConfig() {
    try {
      const { error, value } = this.schema.validate(this.config);
      
      if (error) {
        logger.error(`Configuration validation failed: ${error.message}`, { module: 'config', error });
        throw new Error(`Configuration validation failed: ${error.message}`);
      }
      
      // Update config with validated values
      this.config = value;
      
      logger.debug('Configuration validated successfully', { module: 'config' });
    } catch (error) {
      logger.error(`Configuration validation error: ${error.message}`, { module: 'config', error });
      throw error;
    }
  }

  /**
   * Ensure RPC password exists
   */
  async ensureRpcPassword() {
    // If RPC password is not set, generate one
    if (!this.config.rpcPassword) {
      logger.info('Generating RPC password', { module: 'config' });
      
      // Generate a secure random password
      const password = crypto.randomBytes(32).toString('base64');
      this.config.rpcPassword = password;
      
      // Save password to file
      const passwordFile = path.join(this.dataDir, '.rpcpassword');
      
      try {
        fs.writeFileSync(passwordFile, password, { mode: 0o600 });
        logger.info('RPC password saved to file', { module: 'config', file: passwordFile });
      } catch (error) {
        logger.error(`Failed to save RPC password: ${error.message}`, { module: 'config', error });
        throw error;
      }
    }
  }

  /**
   * Generate Meowcoin configuration file
   */
  async generateMeowcoinConfig() {
    const configFile = path.join(this.dataDir, 'meowcoin.conf');
    
    // Build configuration content
    let content = '';
    
    // Basic settings
    content += '# Meowcoin configuration generated by Meowcoin Docker\n';
    content += '# Generated at: ' + new Date().toISOString() + '\n\n';
    content += '# Node Configuration\n';
    content += 'server=1\n';
    content += 'listen=1\n';
    content += 'txindex=1\n\n';
    
    // Network settings
    content += '# Network Settings\n';
    content += `rpcbind=${this.config.rpcBind}\n`;
    content += `rpcallowip=${this.config.rpcAllowIp}\n\n`;
    
    // RPC authentication
    content += '# RPC Authentication\n';
    content += `rpcuser=${this.config.rpcUser}\n`;
    content += `rpcpassword=${this.config.rpcPassword}\n\n`;
    
    // Security settings
    content += '# Security Settings\n';
    content += `rpcthreads=${this.config.rpcThreads || 4}\n`;
    content += `rpctimeout=${this.config.rpcTimeout || 30}\n`;
    content += `rpcworkqueue=${this.config.rpcWorkqueue || 16}\n\n`;
    
    // Performance settings
    content += '# Performance Settings\n';
    content += `dbcache=${this.config.dbCache || 450}\n`;
    content += `maxorphantx=${this.config.maxOrphanTx || 10}\n`;
    content += `maxmempool=${this.config.maxMempool || 300}\n`;
    content += `maxconnections=${this.config.maxConnections || 40}\n\n`;
    
    // Console output settings
    content += '# Console Output Settings\n';
    content += 'printtoconsole=1\n';
    content += 'logtimestamps=1\n\n';
    
    // SSL settings if enabled
    if (this.config.enableSsl) {
      content += '# SSL Settings\n';
      content += 'rpcssl=1\n';
      content += 'rpcsslcertificatechainfile=/home/meowcoin/.meowcoin/certs/meowcoin.crt\n';
      content += 'rpcsslprivatekeyfile=/home/meowcoin/.meowcoin/certs/meowcoin.key\n';
      content += 'rpcsslciphers=ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384\n\n';
    }
    
    // JWT auth settings if enabled
    if (this.config.enableJwtAuth) {
      content += '# JWT Authentication Settings\n';
      content += 'rest=1\n';
      content += 'rpcauth=jwtsecret\n';
      content += 'jwt=1\n';
      content += 'jwtalgos=ES256\n\n';
    }
    
    // Custom options
    if (this.config.customOpts) {
      content += '# Custom Options\n';
      content += this.config.customOpts + '\n\n';
    }
    
    // Write config file
    try {
      fs.writeFileSync(configFile, content, { mode: 0o600 });
      logger.info('Meowcoin configuration generated', { module: 'config', file: configFile });
    } catch (error) {
      logger.error(`Failed to generate Meowcoin configuration: ${error.message}`, { module: 'config', error });
      throw error;
    }
    
    return configFile;
  }

  /**
   * Get configuration value
   * @param {string} key - Configuration key
   * @param {*} defaultValue - Default value if key is not found
   * @returns {*} Configuration value
   */
  get(key, defaultValue = null) {
    return this.config[key] !== undefined ? this.config[key] : defaultValue;
  }

  /**
   * Set configuration value
   * @param {string} key - Configuration key
   * @param {*} value - Configuration value
   */
  set(key, value) {
    this.config[key] = value;
  }
}

module.exports = new Config();