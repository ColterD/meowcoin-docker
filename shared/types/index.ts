// shared/types/index.ts
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