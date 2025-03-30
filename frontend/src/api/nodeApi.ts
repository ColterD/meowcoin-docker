import axios from 'axios';

const api = axios.create({
  baseURL: '/api',
});

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

export interface LogEntry {
  timestamp: string;
  level: string;
  message: string;
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

// API functions
export const getNodeStatus = async (): Promise<NodeStatus> => {
  const response = await api.get<NodeStatus>('/status');
  return response.data;
};

export const getDiskUsage = async (): Promise<DiskUsage> => {
  const response = await api.get<DiskUsage>('/disk-usage');
  return response.data;
};

export const getLogs = async (since: number): Promise<LogResponse> => {
  const response = await api.get<LogResponse>(`/logs?since=${since}`);
  return response.data;
};

export const saveSettings = async (settings: SettingsRequest): Promise<{ success: boolean, message: string }> => {
  const response = await api.post<{ success: boolean, message: string }>('/settings', settings);
  return response.data;
};

export const controlNode = async (request: NodeControlRequest): Promise<{ success: boolean, message: string }> => {
  const response = await api.post<{ success: boolean, message: string }>('/control', request);
  return response.data;
};

export const updateNode = async (request: UpdateRequest): Promise<{ success: boolean, message: string }> => {
  const response = await api.post<{ success: boolean, message: string }>('/update', request);
  return response.data;
};