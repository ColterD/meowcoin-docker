// Centralized environment variable configuration
export const environment = {
    // Server configuration
    port: process.env.PORT || 8080,
    
    // Meowcoin configuration
    meowcoinConfig: process.env.MEOWCOIN_CONFIG || '/config',
    meowcoinData: process.env.MEOWCOIN_DATA || '/data',
    
    // Docker configuration
    rpcPort: process.env.RPC_PORT || '9766',
    p2pPort: process.env.P2P_PORT || '8788',
    webPort: process.env.WEB_PORT || '8080',
    
    // Node configuration
    meowcoinMode: process.env.MEOWCOIN_MODE || 'full',
    meowcoinOptions: process.env.MEOWCOIN_OPTIONS || '',
    systemMemory: process.env.SYSTEM_MEMORY || 'auto',
    maxConnections: process.env.MAX_CONNECTIONS || 'auto',
    enableTxindex: process.env.ENABLE_TXINDEX || '1',
    autoUpdate: process.env.AUTO_UPDATE || 'security',
    
    // Backup configuration
    backupEnabled: process.env.BACKUP_ENABLED === 'true',
    backupInterval: process.env.BACKUP_INTERVAL || 'daily',
    
    // Node environment
    isDevelopment: process.env.NODE_ENV === 'development',
    isProduction: process.env.NODE_ENV === 'production',
  };