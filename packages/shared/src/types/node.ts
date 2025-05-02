/**
 * Node status types
 */
export enum NodeStatus {
  RUNNING = 'running',
  STARTING = 'starting',
  STOPPING = 'stopping',
  STOPPED = 'stopped',
  SYNCING = 'syncing',
  ERROR = 'error',
  UNKNOWN = 'unknown',
}

/**
 * Node action types
 */
export enum NodeAction {
  START = 'start',
  STOP = 'stop',
  RESTART = 'restart',
  BACKUP = 'backup',
  RESTORE = 'restore',
  UPDATE = 'update',
  RESET = 'reset',
}

/**
 * Node type
 */
export enum NodeType {
  FULL_NODE = 'full_node',
  MINING_NODE = 'mining_node',
  ARCHIVE_NODE = 'archive_node',
  LIGHT_NODE = 'light_node',
  VALIDATOR_NODE = 'validator_node',
}

/**
 * Node resource usage
 */
export interface NodeResourceUsage {
  cpuUsage: number; // percentage (0-100)
  memoryUsage: number; // percentage (0-100)
  diskUsage: number; // percentage (0-100)
  networkInbound: number; // bytes per second
  networkOutbound: number; // bytes per second
  connections: number; // number of peer connections
  lastUpdated: string; // ISO date string
}

/**
 * Node configuration
 */
export interface NodeConfig {
  id: string;
  name: string;
  type: NodeType;
  version: string;
  rpcEnabled: boolean;
  rpcPort: number;
  rpcUsername: string;
  rpcPassword: string;
  p2pPort: number;
  dataDir: string;
  logLevel: 'debug' | 'info' | 'warn' | 'error';
  maxConnections: number;
  maxUploadTarget: number; // MB per day
  maxMempool: number; // MB
  minRelayTxFee: number;
  autoStart: boolean;
  enableUpnp: boolean;
  enableNatPmp: boolean;
  pruneMode: boolean;
  pruneSize: number; // MB
  txIndex: boolean;
  addressIndex: boolean;
  customParameters: Record<string, string>;
}

/**
 * Node information
 */
export interface NodeInfo {
  id: string;
  name: string;
  type: NodeType;
  status: NodeStatus;
  version: string;
  protocolVersion: number;
  resources: NodeResourceUsage;
  network: 'mainnet' | 'testnet' | 'regtest';
  syncProgress: number; // percentage (0-100)
  blockHeight: number;
  lastBlockTime: string; // ISO date string
  peerCount: number;
  uptime: number; // in seconds
  createdAt: string; // ISO date string
  updatedAt: string; // ISO date string
}

/**
 * Node backup
 */
export interface NodeBackup {
  id: string;
  nodeId: string;
  size: number; // bytes
  blockHeight: number;
  createdAt: string; // ISO date string
  status: 'pending' | 'completed' | 'failed';
  location: string;
  checksum: string;
  note?: string;
}

/**
 * Node alert
 */
export interface NodeAlert {
  id: string;
  nodeId: string;
  type: 'error' | 'warning' | 'info';
  message: string;
  timestamp: string; // ISO date string
  acknowledged: boolean;
  acknowledgedBy?: string;
  acknowledgedAt?: string; // ISO date string
  data?: any;
}