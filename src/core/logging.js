const winston = require('winston');
const path = require('path');
const fs = require('fs');

// Default configuration
const DEFAULT_CONFIG = {
  logDir: '/var/log/meowcoin',
  logLevel: 'info',
  maxSize: '10m',
  maxFiles: 5,
  consoleOutput: true
};

/**
 * Centralized logging system for Meowcoin Docker
 */
class Logger {
  /**
   * Create a new logger instance
   * @param {Object} options - Configuration options
   */
  constructor(options = {}) {
    this.config = { ...DEFAULT_CONFIG, ...options };
    this.initialize();
  }

  /**
   * Initialize the logging system
   */
  initialize() {
    // Create log directory if it doesn't exist
    if (!fs.existsSync(this.config.logDir)) {
      fs.mkdirSync(this.config.logDir, { recursive: true, mode: 0o750 });
    }

    // Create transport configurations
    const fileTransport = new winston.transports.File({
      filename: path.join(this.config.logDir, 'meowcoin.log'),
      maxsize: this.config.maxSize,
      maxFiles: this.config.maxFiles,
      tailable: true,
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
      )
    });

    const transports = [fileTransport];

    // Add console transport if enabled
    if (this.config.consoleOutput) {
      transports.push(new winston.transports.Console({
        format: winston.format.combine(
          winston.format.colorize(),
          winston.format.timestamp(),
          winston.format.printf(({ level, message, timestamp, module }) => {
            return `${timestamp} [${level}] [${module || 'main'}]: ${message}`;
          })
        )
      }));
    }

    // Create the logger
    this.logger = winston.createLogger({
      level: this.config.logLevel,
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
      ),
      defaultMeta: { service: 'meowcoin-node' },
      transports
    });

    this.logger.info('Logging system initialized', { module: 'logging' });
  }

  /**
   * Log a message
   * @param {string} level - Log level
   * @param {string} message - Message to log
   * @param {Object} meta - Additional metadata
   */
  log(level, message, meta = {}) {
    this.logger.log(level, message, meta);
  }

  /**
   * Log an info message
   * @param {string} message - Message to log
   * @param {Object} meta - Additional metadata
   */
  info(message, meta = {}) {
    this.logger.info(message, meta);
  }

  /**
   * Log a warning message
   * @param {string} message - Message to log
   * @param {Object} meta - Additional metadata
   */
  warn(message, meta = {}) {
    this.logger.warn(message, meta);
  }

  /**
   * Log an error message
   * @param {string} message - Message to log
   * @param {Object} meta - Additional metadata
   */
  error(message, meta = {}) {
    this.logger.error(message, meta);
  }

  /**
   * Log a debug message
   * @param {string} message - Message to log
   * @param {Object} meta - Additional metadata
   */
  debug(message, meta = {}) {
    this.logger.debug(message, meta);
  }
}

module.exports = new Logger();