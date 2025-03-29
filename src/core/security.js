const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process');
const logger = require('./logging');
const config = require('./config');

/**
 * Security management for Meowcoin Docker
 */
class Security {
  /**
   * Create a new security manager
   * @param {Object} options - Configuration options
   */
  constructor(options = {}) {
    this.options = options;
    this.dataDir = options.dataDir || '/home/meowcoin/.meowcoin';
    this.certDir = path.join(this.dataDir, 'certs');
    this.jwtDir = this.dataDir;
    this.sslCertFile = path.join(this.certDir, 'meowcoin.crt');
    this.sslKeyFile = path.join(this.certDir, 'meowcoin.key');
    this.jwtSecretFile = path.join(this.jwtDir, '.jwtsecret');
  }

  /**
   * Initialize the security system
   */
  async initialize() {
    logger.info('Initializing security system', { module: 'security' });
    
    // Create necessary directories
    this.createDirectories();
    
    // Setup SSL if enabled
    if (config.get('enableSsl')) {
      await this.setupSsl();
    }
    
    // Setup JWT auth if enabled
    if (config.get('enableJwtAuth')) {
      await this.setupJwtAuth();
    }
    
    // Setup fail2ban if enabled
    if (config.get('enableFail2Ban')) {
      await this.setupFail2ban();
    }
    
    // Setup read-only filesystem if enabled
    if (config.get('enableReadonlyFs')) {
      await this.setupReadonlyFs();
    }
    
    // Apply general security hardening
    await this.applySecurityHardening();
    
    logger.info('Security system initialized', { module: 'security' });
  }

  /**
   * Create necessary directories
   */
  createDirectories() {
    // Create cert directory if it doesn't exist
    if (!fs.existsSync(this.certDir)) {
      fs.mkdirSync(this.certDir, { recursive: true, mode: 0o750 });
      logger.debug('Created certificate directory', { module: 'security', dir: this.certDir });
    }
  }

  /**
   * Setup SSL certificates
   */
  async setupSsl() {
    logger.info('Setting up SSL', { module: 'security' });
    
    // Check if certificates already exist
    if (fs.existsSync(this.sslCertFile) && fs.existsSync(this.sslKeyFile)) {
      logger.info('SSL certificates already exist', { module: 'security' });
      
      // Verify certificates
      await this.verifySslCertificates();
    } else {
      // Generate new certificates
      await this.generateSslCertificates();
    }
  }

  /**
   * Verify SSL certificates
   */
  async verifySslCertificates() {
    try {
      // Check certificate expiration
      const certInfo = execSync(`openssl x509 -in ${this.sslCertFile} -noout -text`, { encoding: 'utf8' });
      
      // Extract expiration date
      const expiryMatch = certInfo.match(/Not After\s*:\s*(.+?)$/m);
      if (expiryMatch) {
        const expiryDate = new Date(expiryMatch[1]);
        const now = new Date();
        const daysRemaining = Math.floor((expiryDate - now) / (1000 * 60 * 60 * 24));
        
        logger.info(`SSL certificate expires in ${daysRemaining} days`, { module: 'security' });
        
        // Warn if certificate is expiring soon
        if (daysRemaining < 30) {
          logger.warn(`SSL certificate expires in ${daysRemaining} days`, { module: 'security' });
          
          // Regenerate if less than 7 days remaining
          if (daysRemaining < 7) {
            logger.info('Regenerating SSL certificates', { module: 'security' });
            await this.generateSslCertificates();
          }
        }
      }
    } catch (error) {
      logger.error(`Failed to verify SSL certificates: ${error.message}`, { module: 'security', error });
      
      // Regenerate certificates on verification error
      await this.generateSslCertificates();
    }
  }

  /**
   * Generate SSL certificates
   */
  async generateSslCertificates() {
    logger.info('Generating SSL certificates', { module: 'security' });
    
    try {
      // Create directory if it doesn't exist
      if (!fs.existsSync(this.certDir)) {
        fs.mkdirSync(this.certDir, { recursive: true, mode: 0o750 });
      }
      
      // Generate private key
      execSync(`openssl genrsa -out ${this.sslKeyFile} 4096`, { stdio: 'pipe' });
      fs.chmodSync(this.sslKeyFile, 0o600);
      
      // Generate certificate
      execSync(`openssl req -new -x509 -key ${this.sslKeyFile} -out ${this.sslCertFile} -days 365 -subj "/CN=meowcoin-node" -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"`, { stdio: 'pipe' });
      fs.chmodSync(this.sslCertFile, 0o644);
      
      logger.info('SSL certificates generated successfully', { module: 'security' });
    } catch (error) {
      logger.error(`Failed to generate SSL certificates: ${error.message}`, { module: 'security', error });
      throw error;
    }
  }

  /**
   * Setup JWT authentication
   */
  async setupJwtAuth() {
    logger.info('Setting up JWT authentication', { module: 'security' });
    
    // Check if JWT secret already exists
    if (fs.existsSync(this.jwtSecretFile)) {
      logger.info('JWT secret already exists', { module: 'security' });
    } else {
      // Generate new JWT secret
      await this.generateJwtSecret();
    }
  }

  /**
   * Generate JWT secret
   */
  async generateJwtSecret() {
    logger.info('Generating JWT secret', { module: 'security' });
    
    try {
      // Generate an EC key for JWT
      execSync(`openssl ecparam -name prime256v1 -genkey | openssl pkcs8 -topk8 -nocrypt -out ${this.jwtSecretFile}`, { stdio: 'pipe' });
      fs.chmodSync(this.jwtSecretFile, 0o600);
      
      // Generate public key for verification
      execSync(`openssl ec -in ${this.jwtSecretFile} -pubout -out ${this.jwtSecretFile}.pub`, { stdio: 'pipe' });
      fs.chmodSync(`${this.jwtSecretFile}.pub`, 0o644);
      
      logger.info('JWT secret generated successfully', { module: 'security' });
    } catch (error) {
      logger.error(`Failed to generate JWT secret: ${error.message}`, { module: 'security', error });
      throw error;
    }
  }

  /**
   * Setup fail2ban
   */
  async setupFail2ban() {
    logger.info('Setting up fail2ban', { module: 'security' });
    
    try {
      // Create fail2ban filter for RPC authentication failures
      const filterDir = '/etc/fail2ban/filter.d';
      const jailFile = '/etc/fail2ban/jail.local';
      
      // Ensure directories exist
      if (!fs.existsSync(filterDir)) {
        fs.mkdirSync(filterDir, { recursive: true });
      }
      
      // Create RPC filter
      const rpcFilterFile = path.join(filterDir, 'meowcoin-rpc.conf');
      const rpcFilterContent = `[Definition]
failregex = ^.*Incorrect rpcuser or rpcpassword.*\\[<HOST>\\]$
            ^.*Unauthorized RPC access.*\\[<HOST>\\]$
            ^.*Failed authentication from.*\\[<HOST>\\]$
ignoreregex =
`;
      fs.writeFileSync(rpcFilterFile, rpcFilterContent, { mode: 0o644 });
      
      // Create fail2ban jail configuration
      const jailContent = `[DEFAULT]
bantime = ${config.get('fail2banBantime', 3600)}
findtime = ${config.get('fail2banFindtime', 600)}
maxretry = ${config.get('fail2banMaxretry', 5)}
ignoreip = 127.0.0.1/8 ::1 ${config.get('fail2banIgnoreip', '')}

[meowcoin-rpc]
enabled = true
filter = meowcoin-rpc
logpath = /home/meowcoin/.meowcoin/logs/debug.log
maxretry = 5
bantime = 7200
`;
      fs.writeFileSync(jailFile, jailContent, { mode: 0o644 });
      
      logger.info('fail2ban configuration completed', { module: 'security' });
    } catch (error) {
      logger.error(`Failed to setup fail2ban: ${error.message}`, { module: 'security', error });
      
      // Non-critical, continue without fail2ban
      logger.warn('Continuing without fail2ban', { module: 'security' });
    }
  }

  /**
   * Setup read-only filesystem
   */
  async setupReadonlyFs() {
    logger.info('Setting up read-only filesystem', { module: 'security' });
    
    try {
      // Create necessary writable directories
      const writableDirs = [
        '/home/meowcoin/.meowcoin/database',
        '/home/meowcoin/.meowcoin/blocks',
        '/home/meowcoin/.meowcoin/chainstate',
        '/home/meowcoin/.meowcoin/indexes',
        '/home/meowcoin/.meowcoin/logs',
        '/home/meowcoin/.meowcoin/backups',
        '/tmp',
        '/var/log',
        '/var/run',
        '/var/lib/meowcoin'
      ];
      
      writableDirs.forEach(dir => {
        if (!fs.existsSync(dir)) {
          fs.mkdirSync(dir, { recursive: true, mode: 0o750 });
        }
      });
      
      // Create marker file
      fs.writeFileSync('/etc/meowcoin/.readonly_enabled', '', { mode: 0o644 });
      
      logger.info('Read-only filesystem configured', { module: 'security' });
    } catch (error) {
      logger.error(`Failed to setup read-only filesystem: ${error.message}`, { module: 'security', error });
      throw error;
    }
  }

  /**
   * Apply general security hardening
   */
  async applySecurityHardening() {
    logger.info('Applying security hardening', { module: 'security' });
    
    try {
      // Fix file permissions
      this.fixFilePermissions();
      
      // Create security banner
      this.createSecurityBanner();
      
      // Create binary integrity file
      this.createBinaryIntegrityFile();
      
      logger.info('Security hardening applied', { module: 'security' });
    } catch (error) {
      logger.error(`Failed to apply security hardening: ${error.message}`, { module: 'security', error });
    }
  }

  /**
   * Fix file permissions
   */
  fixFilePermissions() {
    logger.info('Fixing file permissions', { module: 'security' });
    
    try {
      // Fix data directory permissions
      execSync(`find ${this.dataDir} -type d -exec chmod 750 {} \\;`, { stdio: 'pipe' });
      execSync(`find ${this.dataDir} -type f -exec chmod 640 {} \\;`, { stdio: 'pipe' });
      
      // Fix sensitive file permissions
      execSync(`find ${this.dataDir} -name "wallet.dat" -exec chmod 600 {} \\;`, { stdio: 'pipe' });
      execSync(`find ${this.dataDir} -name "*.conf" -exec chmod 600 {} \\;`, { stdio: 'pipe' });
      execSync(`find ${this.dataDir} -name "*key*" -exec chmod 600 {} \\;`, { stdio: 'pipe' });
      
      logger.info('File permissions fixed', { module: 'security' });
    } catch (error) {
      logger.error(`Failed to fix file permissions: ${error.message}`, { module: 'security', error });
    }
  }

  /**
   * Create security banner
   */
  createSecurityBanner() {
    const bannerFile = '/etc/meowcoin/security-banner.txt';
    const bannerContent = `================================================================================
                         MEOWCOIN NODE - AUTHORIZED ACCESS ONLY
================================================================================
This system is restricted to authorized users for legitimate Meowcoin node
operation. All activities may be monitored and recorded.
Unauthorized access will be fully investigated and reported to authorities.
================================================================================`;
    
    fs.writeFileSync(bannerFile, bannerContent, { mode: 0o644 });
    logger.info('Security banner created', { module: 'security' });
  }

  /**
   * Create binary integrity file
   */
  createBinaryIntegrityFile() {
    const integrityFile = '/etc/meowcoin/binary-integrity.txt';
    
    try {
      // Generate SHA-256 hashes of binary files
      const hash1 = crypto.createHash('sha256').update(fs.readFileSync('/usr/bin/meowcoind')).digest('hex');
      const hash2 = crypto.createHash('sha256').update(fs.readFileSync('/usr/bin/meowcoin-cli')).digest('hex');
      
      const content = `/usr/bin/meowcoind ${hash1}\n/usr/bin/meowcoin-cli ${hash2}\n`;
      fs.writeFileSync(integrityFile, content, { mode: 0o444 });
      
      logger.info('Binary integrity file created', { module: 'security' });
    } catch (error) {
      logger.error(`Failed to create binary integrity file: ${error.message}`, { module: 'security', error });
    }
  }

  /**
   * Generate a secure random password
   * @param {number} length - Password length
   * @returns {string} Generated password
   */
  generateSecurePassword(length = 32) {
    const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-_=+';
    
    // Generate random bytes
    const randomBytes = crypto.randomBytes(length);
    
    // Convert to password
    let password = '';
    for (let i = 0; i < length; i++) {
      password += charset.charAt(randomBytes[i] % charset.length);
    }
    
    return password;
  }

  /**
   * Check file permissions
   * @returns {Object} Permission check results
   */
  async checkPermissions() {
    logger.info('Checking file permissions', { module: 'security' });
    
    const results = {
      walletIssues: 0,
      keyIssues: 0,
      configIssues: 0,
      dirIssues: 0
    };
    
    try {
      // Check wallet.dat permissions
      const walletFiles = execSync(`find ${this.dataDir} -name "wallet.dat" 2>/dev/null`, { encoding: 'utf8' }).split('\n').filter(Boolean);
      
      walletFiles.forEach(file => {
        const stats = fs.statSync(file);
        const perms = stats.mode & 0o777;
        
        if (perms !== 0o600) {
          logger.warn(`wallet.dat has incorrect permissions: ${perms.toString(8)}`, { module: 'security', file });
          fs.chmodSync(file, 0o600);
          results.walletIssues++;
        }
      });
      
      // Check key files
      const keyFiles = execSync(`find ${this.dataDir} -name "*key*" -o -name "*.pem" -o -name "*.key" 2>/dev/null`, { encoding: 'utf8' }).split('\n').filter(Boolean);
      
      keyFiles.forEach(file => {
        const stats = fs.statSync(file);
        const perms = stats.mode & 0o777;
        
        if (perms !== 0o600 && perms !== 0o400) {
          logger.warn(`Key file has incorrect permissions: ${perms.toString(8)}`, { module: 'security', file });
          fs.chmodSync(file, 0o600);
          results.keyIssues++;
        }
      });
      
      // Check configuration files
      const configFiles = execSync(`find ${this.dataDir} -name "*.conf" 2>/dev/null`, { encoding: 'utf8' }).split('\n').filter(Boolean);
      
      configFiles.forEach(file => {
        const stats = fs.statSync(file);
        const perms = stats.mode & 0o777;
        
        if (perms !== 0o600 && perms !== 0o640) {
          logger.warn(`Config file has incorrect permissions: ${perms.toString(8)}`, { module: 'security', file });
          fs.chmodSync(file, 0o640);
          results.configIssues++;
        }
      });
      
      // Check directories
      const dirs = execSync(`find ${this.dataDir} -type d 2>/dev/null`, { encoding: 'utf8' }).split('\n').filter(Boolean);
      
      dirs.forEach(dir => {
        const stats = fs.statSync(dir);
        const perms = stats.mode & 0o777;
        
        if (perms !== 0o750 && perms !== 0o700) {
          logger.warn(`Directory has incorrect permissions: ${perms.toString(8)}`, { module: 'security', dir });
          fs.chmodSync(dir, 0o750);
          results.dirIssues++;
        }
      });
      
      logger.info('Permission check completed', { module: 'security', results });
    } catch (error) {
      logger.error(`Permission check failed: ${error.message}`, { module: 'security', error });
    }
    
    return results;
  }

  /**
   * Check binary integrity
   * @returns {boolean} Integrity check result
   */
  async checkBinaryIntegrity() {
    logger.info('Checking binary integrity', { module: 'security' });
    
    const integrityFile = '/etc/meowcoin/binary-integrity.txt';
    
    try {
      // Check if integrity file exists
      if (!fs.existsSync(integrityFile)) {
        logger.warn('Integrity file not found', { module: 'security' });
        return false;
      }
      
      // Read file content
      const content = fs.readFileSync(integrityFile, 'utf8');
      const lines = content.split('\n').filter(Boolean);
      
      // Verify each line
      for (const line of lines) {
        const [file, expectedHash] = line.split(' ');
        
        // Calculate current hash
        const currentHash = crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
        
        // Compare hashes
        if (currentHash !== expectedHash) {
          logger.error(`Binary integrity check failed for ${file}`, { module: 'security', expected: expectedHash, current: currentHash });
          return false;
        }
      }
      
      logger.info('Binary integrity check passed', { module: 'security' });
      return true;
    } catch (error) {
      logger.error(`Binary integrity check failed: ${error.message}`, { module: 'security', error });
      return false;
    }
  }
}

module.exports = new Security();