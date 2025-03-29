const logging = require('./logging');
const config = require('./config');
const security = require('./security');
const backup = require('./backup');
const monitor = require('./monitor');
const plugins = require('./plugins');

module.exports = {
  logging,
  config,
  security,
  backup,
  monitor,
  plugins,
  
  async initialize() {
    // Initialize modules in proper order
    await logging.initialize();
    await config.initialize();
    await security.initialize();
    await monitor.initialize();
    await backup.initialize();
    await plugins.initialize();
  }
};