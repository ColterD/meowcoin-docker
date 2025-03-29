const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const crypto = require('crypto');
const logger = require('./logging');
const config = require('./config');

/**
 * Backup management for Meowcoin Docker
 */
class Backup {
  /**
   * Create a new backup manager
   * @param {Object} options - Configuration options
   */
  constructor(options = {}) {
    this.options = options;
    this.dataDir = options.dataDir || '/home/meowcoin/.meowcoin';
    this.backupDir = path.join(this.dataDir, 'backups');
    this.backupStatusFile = path.join('/var/lib/meowcoin', 'backup_status.json');
    this.maxBackups = config.get('maxBackups', 7);
    this.backupSchedule = config.get('backupSchedule', '0 0 * * *');
    this.backupRemoteEnabled = config.get('backupRemoteEnabled', false);
    this.backupRemoteType = config.get('backupRemoteType', '');
  }

  /**
   * Initialize the backup system
   */
  async initialize() {
    logger.info('Initializing backup system', { module: 'backup' });
    
    // Create backup directory if it doesn't exist
    if (!fs.existsSync(this.backupDir)) {
      fs.mkdirSync(this.backupDir, { recursive: true, mode: 0o750 });
      logger.debug('Created backup directory', { module: 'backup', dir: this.backupDir });
    }
    
    // Initialize backup status
    await this.initializeBackupStatus();
    
    // Setup automated backups if enabled
    if (config.get('enableBackups')) {
      await this.setupAutomatedBackups();
    }
    
    // Setup remote backups if enabled
    if (this.backupRemoteEnabled) {
      await this.setupRemoteBackups();
    }
    
    logger.info('Backup system initialized', { module: 'backup' });
  }

  /**
   * Initialize backup status
   */
  async initializeBackupStatus() {
    // Create status file if it doesn't exist
    if (!fs.existsSync(this.backupStatusFile)) {
      const status = {
        lastBackup: null,
        lastBackupStatus: null,
        backupHistory: [],
        backupStats: {
          total: 0,
          successful: 0,
          failed: 0
        }
      };
      
      fs.writeFileSync(this.backupStatusFile, JSON.stringify(status, null, 2));
      logger.debug('Created backup status file', { module: 'backup', file: this.backupStatusFile });
    }
  }

  /**
   * Setup automated backups
   */
  async setupAutomatedBackups() {
    logger.info('Setting up automated backups', { module: 'backup' });
    
    try {
      // Create cron job
      const cronDir = '/etc/cron.d';
      const cronFile = path.join(cronDir, 'meowcoin-backup');
      
      // Ensure directory exists
      if (!fs.existsSync(cronDir)) {
        fs.mkdirSync(cronDir, { recursive: true });
      }
      
      // Create cron job file
      const cronContent = `# Meowcoin automated backup
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=""
HOME=/home/meowcoin

# Backup schedule
${this.backupSchedule} meowcoin /usr/local/bin/meowcoin-backup.js create > /var/log/meowcoin/backup.log 2>&1

# Backup cleanup
0 1 * * * meowcoin /usr/local/bin/meowcoin-backup.js cleanup > /var/log/meowcoin/backup-cleanup.log 2>&1
`;
      
      fs.writeFileSync(cronFile, cronContent, { mode: 0o644 });
      logger.info('Automated backups scheduled', { module: 'backup', schedule: this.backupSchedule });
    } catch (error) {
      logger.error(`Failed to setup automated backups: ${error.message}`, { module: 'backup', error });
    }
  }

  /**
   * Setup remote backups
   */
  async setupRemoteBackups() {
    logger.info('Setting up remote backups', { module: 'backup' });
    
    try {
      switch (this.backupRemoteType) {
        case 's3':
          await this.setupS3Backups();
          break;
        case 'sftp':
          await this.setupSftpBackups();
          break;
        default:
          logger.warn(`Unknown remote backup type: ${this.backupRemoteType}`, { module: 'backup' });
          break;
      }
    } catch (error) {
      logger.error(`Failed to setup remote backups: ${error.message}`, { module: 'backup', error });
    }
  }

  /**
   * Setup S3 backups
   */
  async setupS3Backups() {
    logger.info('Setting up S3 backups', { module: 'backup' });
    
    // Create sync script
    const scriptDir = '/usr/local/bin';
    const scriptFile = path.join(scriptDir, 'meowcoin-s3-sync.js');
    
    // Create cron job
    const cronDir = '/etc/cron.d';
    const cronFile = path.join(cronDir, 'meowcoin-s3-sync');
    
    // Ensure directories exist
    if (!fs.existsSync(cronDir)) {
      fs.mkdirSync(cronDir, { recursive: true });
    }
    
    // Create cron job file
    const cronContent = `# Meowcoin S3 backup sync
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=""
HOME=/home/meowcoin

# Sync schedule (1 hour after backup)
0 1 * * * meowcoin /usr/local/bin/meowcoin-s3-sync.js > /var/log/meowcoin/s3-sync.log 2>&1
`;
    
    fs.writeFileSync(cronFile, cronContent, { mode: 0o644 });
    logger.info('S3 backup sync scheduled', { module: 'backup' });
  }

  /**
   * Setup SFTP backups
   */
  async setupSftpBackups() {
    logger.info('Setting up SFTP backups', { module: 'backup' });
    
    // Create sync script
    const scriptDir = '/usr/local/bin';
    const scriptFile = path.join(scriptDir, 'meowcoin-sftp-sync.js');
    
    // Create cron job
    const cronDir = '/etc/cron.d';
    const cronFile = path.join(cronDir, 'meowcoin-sftp-sync');
    
    // Ensure directories exist
    if (!fs.existsSync(cronDir)) {
      fs.mkdirSync(cronDir, { recursive: true });
    }
    
    // Create cron job file
    const cronContent = `# Meowcoin SFTP backup sync
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=""
HOME=/home/meowcoin

# Sync schedule (1 hour after backup)
0 1 * * * meowcoin /usr/local/bin/meowcoin-sftp-sync.js > /var/log/meowcoin/sftp-sync.log 2>&1
`;
    
    fs.writeFileSync(cronFile, cronContent, { mode: 0o644 });
    logger.info('SFTP backup sync scheduled', { module: 'backup' });
  }

  /**
   * Create a backup
   * @param {string} type - Backup type (e.g., 'manual', 'scheduled')
   * @returns {Object} Backup result
   */
  async createBackup(type = 'manual') {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupFile = path.join(this.backupDir, `meowcoin_backup_${timestamp}.tar.gz`);
    
    logger.info(`Creating ${type} backup`, { module: 'backup', file: backupFile });
    
    try {
      // Ensure backup directory exists
      if (!fs.existsSync(this.backupDir)) {
        fs.mkdirSync(this.backupDir, { recursive: true, mode: 0o750 });
      }
      
      // Check available disk space
      const diskInfo = execSync('df -k ' + this.backupDir, { encoding: 'utf8' });
      const availableSpace = parseInt(diskInfo.split('\n')[1].split(/\s+/)[3]) * 1024;
      
      // Estimate required space
      const walletSize = fs.existsSync(path.join(this.dataDir, 'wallet.dat')) ? fs.statSync(path.join(this.dataDir, 'wallet.dat')).size : 0;
      const requiredSpace = walletSize * 2; // Conservative estimate
      
      if (availableSpace < requiredSpace) {
        throw new Error(`Not enough disk space for backup: required ${requiredSpace}, available ${availableSpace}`);
      }
      
      // Create backup archive
      const excludes = [
        '--exclude="blocks"',
        '--exclude="chainstate"',
        '--exclude="database"',
        '--exclude="debug.log"',
        '--exclude="logs"',
        '--exclude="fee_estimates.dat"',
        '--exclude="backups"'
      ].join(' ');
      
      execSync(`tar -czf "${backupFile}" -C "${this.dataDir}" ${excludes} .`, { stdio: 'pipe' });
      
      // Create checksum file
      const checksum = crypto.createHash('sha256').update(fs.readFileSync(backupFile)).digest('hex');
      fs.writeFileSync(`${backupFile}.sha256`, checksum);
      
      // Encrypt backup if encryption key is provided
      const encryptionKey = config.get('backupEncryptionKey');
      if (encryptionKey) {
        await this.encryptBackup(backupFile, encryptionKey);
      }
      
      // Update backup status
      await this.updateBackupStatus({
        timestamp: new Date().toISOString(),
        file: backupFile,
        type,
        size: fs.statSync(backupFile).size,
        encrypted: !!encryptionKey,
        checksum,
        status: 'success'
      });
      
      logger.info('Backup created successfully', { module: 'backup', file: backupFile });
      
      // Clean up old backups
      await this.cleanupBackups();
      
      return {
        success: true,
        file: backupFile,
        size: fs.statSync(backupFile).size,
        checksum
      };
    } catch (error) {
      logger.error(`Backup creation failed: ${error.message}`, { module: 'backup', error });
      
      // Update backup status
      await this.updateBackupStatus({
        timestamp: new Date().toISOString(),
        file: backupFile,
        type,
        error: error.message,
        status: 'failed'
      });
      
      // Clean up failed backup
      if (fs.existsSync(backupFile)) {
        fs.unlinkSync(backupFile);
      }
      
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Encrypt a backup file
   * @param {string} file - Backup file path
   * @param {string} key - Encryption key
   * @returns {boolean} Success status
   */
  async encryptBackup(file, key) {
    logger.info('Encrypting backup', { module: 'backup', file });
    
    try {
      // Create a temporary key file
      const keyFile = `${file}.key`;
      fs.writeFileSync(keyFile, key, { mode: 0o600 });
      
      // Encrypt the file
      const encryptedFile = `${file}.enc`;
      execSync(`openssl enc -aes-256-cbc -salt -pbkdf2 -iter 10000 -in "${file}" -out "${encryptedFile}" -pass file:"${keyFile}"`, { stdio: 'pipe' });
      
      // Replace original with encrypted version
      fs.unlinkSync(file);
      fs.renameSync(encryptedFile, file);
      
      // Remove key file
      fs.unlinkSync(keyFile);
      
      // Update checksum
      const checksum = crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
      fs.writeFileSync(`${file}.sha256`, checksum);
      
      logger.info('Backup encrypted successfully', { module: 'backup', file });
      return true;
    } catch (error) {
      logger.error(`Backup encryption failed: ${error.message}`, { module: 'backup', error });
      return false;
    }
  }

  /**
   * Update backup status
   * @param {Object} status - Backup status
   */
  async updateBackupStatus(status) {
    try {
      // Read current status
      let currentStatus = {};
      if (fs.existsSync(this.backupStatusFile)) {
        currentStatus = JSON.parse(fs.readFileSync(this.backupStatusFile, 'utf8'));
      } else {
        currentStatus = {
          lastBackup: null,
          lastBackupStatus: null,
          backupHistory: [],
          backupStats: {
            total: 0,
            successful: 0,
            failed: 0
          }
        };
      }
      
      // Update status
      currentStatus.lastBackup = status.timestamp;
      currentStatus.lastBackupStatus = status.status;
      
      // Update history
      currentStatus.backupHistory.unshift(status);
      if (currentStatus.backupHistory.length > 10) {
        currentStatus.backupHistory = currentStatus.backupHistory.slice(0, 10);
      }
      
      // Update stats
      currentStatus.backupStats.total++;
      if (status.status === 'success') {
        currentStatus.backupStats.successful++;
      } else {
        currentStatus.backupStats.failed++;
      }
      
      // Write updated status
      fs.writeFileSync(this.backupStatusFile, JSON.stringify(currentStatus, null, 2));
    } catch (error) {
      logger.error(`Failed to update backup status: ${error.message}`, { module: 'backup', error });
    }
  }

  /**
   * Clean up old backups
   */
  async cleanupBackups() {
    logger.info('Cleaning up old backups', { module: 'backup' });
    
    try {
      // Get list of backup files
      const files = fs.readdirSync(this.backupDir)
        .filter(file => file.startsWith('meowcoin_backup_') && file.endsWith('.tar.gz'))
        .map(file => path.join(this.backupDir, file))
        .map(file => ({
          file,
          stats: fs.statSync(file)
        }))
        .sort((a, b) => b.stats.mtime.getTime() - a.stats.mtime.getTime());
      
      // Keep only the latest maxBackups
      if (files.length > this.maxBackups) {
        const filesToDelete = files.slice(this.maxBackups);
        
        filesToDelete.forEach(file => {
          try {
            fs.unlinkSync(file.file);
            // Also delete checksum file if it exists
            if (fs.existsSync(`${file.file}.sha256`)) {
              fs.unlinkSync(`${file.file}.sha256`);
            }
            logger.debug(`Deleted old backup: ${file.file}`, { module: 'backup' });
          } catch (error) {
            logger.error(`Failed to delete old backup: ${error.message}`, { module: 'backup', file: file.file });
          }
        });
        
        logger.info(`Deleted ${filesToDelete.length} old backups`, { module: 'backup' });
      } else {
        logger.info('No old backups to delete', { module: 'backup' });
      }
    } catch (error) {
      logger.error(`Backup cleanup failed: ${error.message}`, { module: 'backup', error });
    }
  }

  /**
   * Verify backup integrity
   * @param {string} file - Backup file path
   * @returns {boolean} Verification result
   */
  async verifyBackup(file) {
    logger.info('Verifying backup integrity', { module: 'backup', file });
    
    try {
      // Check if file exists
      if (!fs.existsSync(file)) {
        throw new Error('Backup file does not exist');
      }
      
      // Check if checksum file exists
      const checksumFile = `${file}.sha256`;
      if (!fs.existsSync(checksumFile)) {
        throw new Error('Checksum file does not exist');
      }
      
      // Verify checksum
      const expectedChecksum = fs.readFileSync(checksumFile, 'utf8').trim();
      const actualChecksum = crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
      
      if (expectedChecksum !== actualChecksum) {
        throw new Error(`Checksum mismatch: expected ${expectedChecksum}, got ${actualChecksum}`);
      }
      
      // Verify archive integrity
      execSync(`tar -tzf "${file}" > /dev/null`, { stdio: 'pipe' });
      
      logger.info('Backup integrity verified successfully', { module: 'backup', file });
      return true;
    } catch (error) {
      logger.error(`Backup verification failed: ${error.message}`, { module: 'backup', file, error });
      return false;
    }
  }

  /**
   * Restore a backup
   * @param {string} file - Backup file path
   * @param {string} key - Encryption key (if encrypted)
   * @returns {boolean} Restoration result
   */
  async restoreBackup(file, key = null) {
    logger.info('Restoring backup', { module: 'backup', file });
    
    try {
      // Check if file exists
      if (!fs.existsSync(file)) {
        throw new Error('Backup file does not exist');
      }
      
      // Create temporary directory
      const tempDir = `/tmp/meowcoin-restore-${Date.now()}`;
      fs.mkdirSync(tempDir, { recursive: true });
      
      // If encrypted and key provided, decrypt first
      let fileToExtract = file;
      if (key) {
        const decryptedFile = path.join(tempDir, 'backup.tar.gz');
        
        // Create a temporary key file
        const keyFile = path.join(tempDir, 'key');
        fs.writeFileSync(keyFile, key, { mode: 0o600 });
        
        // Decrypt the file
        execSync(`openssl enc -d -aes-256-cbc -pbkdf2 -iter 10000 -in "${file}" -out "${decryptedFile}" -pass file:"${keyFile}"`, { stdio: 'pipe' });
        
        // Remove key file
        fs.unlinkSync(keyFile);
        
        fileToExtract = decryptedFile;
      }
      
      // Extract backup to temporary directory
      execSync(`tar -xzf "${fileToExtract}" -C "${tempDir}"`, { stdio: 'pipe' });
      
      // Stop Meowcoin daemon if running
      let daemonWasRunning = false;
      try {
        execSync('meowcoin-cli stop', { stdio: 'pipe' });
        daemonWasRunning = true;
        logger.info('Stopped Meowcoin daemon', { module: 'backup' });
        
        // Wait for daemon to stop
        let attempts = 0;
        while (attempts < 30) {
          try {
            execSync('meowcoin-cli getinfo', { stdio: 'pipe' });
            // If no error, daemon is still running
            logger.debug('Waiting for daemon to stop...', { module: 'backup' });
            await new Promise(resolve => setTimeout(resolve, 1000));
            attempts++;
          } catch (e) {
            // Error means daemon has stopped
            break;
          }
        }
      } catch (error) {
        // Daemon was not running
        logger.debug('Meowcoin daemon was not running', { module: 'backup' });
      }
      
      // Backup current wallet.dat if it exists
      const walletFile = path.join(this.dataDir, 'wallet.dat');
      if (fs.existsSync(walletFile)) {
        const backupWalletFile = `${walletFile}.backup-${Date.now()}`;
        fs.copyFileSync(walletFile, backupWalletFile);
        logger.info('Backed up current wallet.dat', { module: 'backup', file: backupWalletFile });
      }
      
      // Restore wallet.dat from backup
      const backupWalletFile = path.join(tempDir, 'wallet.dat');
      if (fs.existsSync(backupWalletFile)) {
        fs.copyFileSync(backupWalletFile, walletFile);
        fs.chmodSync(walletFile, 0o600);
        logger.info('Restored wallet.dat from backup', { module: 'backup' });
      } else {
        logger.warn('No wallet.dat found in backup', { module: 'backup' });
      }
      
      // Clean up
      execSync(`rm -rf "${tempDir}"`, { stdio: 'pipe' });
      
      // Restart daemon if it was running
      if (daemonWasRunning) {
        execSync('meowcoind -daemon', { stdio: 'pipe' });
        logger.info('Restarted Meowcoin daemon', { module: 'backup' });
      }
      
      logger.info('Backup restored successfully', { module: 'backup' });
      return true;
    } catch (error) {
      logger.error(`Backup restoration failed: ${error.message}`, { module: 'backup', error });
      return false;
    }
  }
}

module.exports = new Backup();