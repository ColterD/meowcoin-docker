export interface NodeStatus {
    status: 'running' | 'syncing' | 'stopped' | 'no_connections' | 'starting';
    blockchain: {
      blocks: number;
      headers: number;
      progress: string;
    };
    node: {
      version: string;
      subversion: string;
      connections: number;
      bytesReceived: number;
      bytesSent: number;
    };
    system: {
      memory: {
        used: number;
        total: number;
        percent: string;
      };
      disk: {
        size: string;
        used: string;
        percent: number;
      };
    };
    settings: {
      maxConnections: number;
      enableTxindex: number;
    };
    updated: string;
    updateAvailable?: boolean;
    latestVersion?: string;
}
  
export interface DiskUsage {
  success: boolean;
  paths: {
    path: string;
    sizeBytes: number;
  }[];
}

export interface LogResponse {
  success: boolean;
  logs: string[];
  timestamp: number;
}

export interface SettingsRequest {
  maxConnections: number;
  enableTxindex: number;
}

export interface NodeControlRequest {
  action: 'restart' | 'shutdown';
}

export interface UpdateRequest {
  version: string;
}

export interface BlockchainInfo {
  chain: string;
  blocks: number;
  headers: number;
  bestblockhash: string;
  difficulty: number;
  mediantime: number;
  verificationprogress: number;
  initialblockdownload: boolean;
  chainwork: string;
  size_on_disk: number;
  pruned: boolean;
}

export interface NetworkInfo {
  version: number;
  subversion: string;
  protocolversion: number;
  localservices: string;
  localrelay: boolean;
  timeoffset: number;
  connections: number;
  networkactive: boolean;
  networks: any[];
  relayfee: number;
  incrementalfee: number;
}

export interface NetTotals {
  totalbytesrecv: number;
  totalbytessent: number;
  timeMillis: number;
}

export interface LogEntry {
  timestamp: string;
  level: string;
  message: string;
}