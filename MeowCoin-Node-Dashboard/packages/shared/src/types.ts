export type NodeStatusType = 'running' | 'stopped' | 'error';

export interface NodeStatus {
  id: string;
  name: string;
  status: NodeStatusType;
  cpuUsage: number;
  memoryUsage: number;
  diskUsage: number;
  lastUpdated: string; // ISO date string
}

export interface NodeConfig {
  port: number;
  apiKey: string;
  syncInterval: number;
  maxConnections: number;
}

export interface ApiResponse<T> {
  data: T;
  success: boolean;
  message?: string;
  code?: string;
}

export interface UserData {
  id: string;
  username: string;
  role: 'admin' | 'viewer';
}