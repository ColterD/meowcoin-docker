/**
 * Node status types
 */
export declare enum NodeStatus {
    RUNNING = "running",
    STARTING = "starting",
    STOPPING = "stopping",
    STOPPED = "stopped",
    SYNCING = "syncing",
    ERROR = "error",
    UNKNOWN = "unknown"
}
/**
 * Node action types
 */
export declare enum NodeAction {
    START = "start",
    STOP = "stop",
    RESTART = "restart",
    BACKUP = "backup",
    RESTORE = "restore",
    UPDATE = "update",
    RESET = "reset"
}
/**
 * Node type
 */
export declare enum NodeType {
    FULL_NODE = "full_node",
    MINING_NODE = "mining_node",
    ARCHIVE_NODE = "archive_node",
    LIGHT_NODE = "light_node",
    VALIDATOR_NODE = "validator_node"
}
/**
 * Node resource usage
 */
export interface NodeResourceUsage {
    cpuUsage: number;
    memoryUsage: number;
    diskUsage: number;
    networkInbound: number;
    networkOutbound: number;
    connections: number;
    lastUpdated: string;
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
    maxUploadTarget: number;
    maxMempool: number;
    minRelayTxFee: number;
    autoStart: boolean;
    enableUpnp: boolean;
    enableNatPmp: boolean;
    pruneMode: boolean;
    pruneSize: number;
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
    syncProgress: number;
    blockHeight: number;
    lastBlockTime: string;
    peerCount: number;
    uptime: number;
    createdAt: string;
    updatedAt: string;
}
/**
 * Node backup
 */
export interface NodeBackup {
    id: string;
    nodeId: string;
    size: number;
    blockHeight: number;
    createdAt: string;
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
    timestamp: string;
    acknowledged: boolean;
    acknowledgedBy?: string;
    acknowledgedAt?: string;
    data?: any;
}
