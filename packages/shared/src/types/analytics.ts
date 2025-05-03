import { TimeRangeFilter } from './common';

/**
 * Time series data point
 */
export interface TimeSeriesDataPoint {
  timestamp: string; // ISO date string
  value: number;
}

/**
 * Time series data
 */
export interface TimeSeriesData {
  name: string;
  data: TimeSeriesDataPoint[];
  unit?: string;
}

/**
 * Blockchain metrics
 */
export interface BlockchainMetrics {
  blockHeight: number;
  difficulty: number;
  hashrate: number; // hashes per second
  averageBlockTime: number; // seconds
  mempoolSize: number; // transactions
  mempoolBytes: number; // bytes
  totalTransactions: number;
  totalBlocks: number;
  totalSupply: number;
  circulatingSupply: number;
  averageFee: number;
  medianFee: number;
  lastUpdated: string; // ISO date string
}

/**
 * Network metrics
 */
export interface NetworkMetrics {
  totalNodes: number;
  activeNodes: number;
  totalConnections: number;
  inboundConnections: number;
  outboundConnections: number;
  geographicDistribution: {
    [countryCode: string]: number;
  };
  versionDistribution: {
    [version: string]: number;
  };
  totalBandwidth: number; // bytes
  inboundBandwidth: number; // bytes
  outboundBandwidth: number; // bytes
  lastUpdated: string; // ISO date string
  /**
   * Percentage change in network hashrate compared to previous week. Null if not available.
   * Example: 5.3 means +5.3% from last week.
   */
  hashrateChange?: number | null;
}

/**
 * Transaction metrics
 */
export interface TransactionMetrics {
  totalTransactions: number;
  transactionsPerSecond: number;
  averageTransactionSize: number; // bytes
  averageTransactionFee: number;
  medianTransactionFee: number;
  feeDistribution: {
    [range: string]: number; // e.g. "0-1", "1-5", "5-10", etc.
  };
  transactionTypes: {
    [type: string]: number;
  };
  lastUpdated: string; // ISO date string
}

/**
 * Block metrics
 */
export interface BlockMetrics {
  averageBlockSize: number; // bytes
  averageTransactionsPerBlock: number;
  averageBlockTime: number; // seconds
  blockSizeDistribution: {
    [range: string]: number; // e.g. "0-100KB", "100-500KB", etc.
  };
  lastUpdated: string; // ISO date string
}

/**
 * Analytics query parameters
 */
export interface AnalyticsQueryParams extends TimeRangeFilter {
  metric: string;
  interval?: 'minute' | 'hour' | 'day' | 'week' | 'month';
  nodeId?: string;
  limit?: number;
  aggregate?: 'sum' | 'avg' | 'min' | 'max' | 'count';
}

/**
 * Dashboard widget
 */
export interface DashboardWidget<TConfig = unknown> {
  id: string;
  type: 'chart' | 'metric' | 'table' | 'alert' | 'status' | 'custom';
  title: string;
  description?: string;
  size: 'small' | 'medium' | 'large';
  position: {
    x: number;
    y: number;
    w: number;
    h: number;
  };
  config: TConfig;
}

/**
 * Dashboard
 */
export interface Dashboard {
  id: string;
  name: string;
  description?: string;
  isDefault: boolean;
  userId: string;
  widgets: DashboardWidget[];
  createdAt: string; // ISO date string
  updatedAt: string; // ISO date string
}

/**
 * Report
 */
export interface Report<TParams = unknown> {
  id: string;
  name: string;
  description?: string;
  type: 'blockchain' | 'network' | 'transaction' | 'custom';
  format: 'pdf' | 'csv' | 'json';
  schedule?: {
    frequency: 'daily' | 'weekly' | 'monthly';
    dayOfWeek?: number; // 0-6, where 0 is Sunday
    dayOfMonth?: number; // 1-31
    time: string; // HH:MM in 24-hour format
    timezone: string;
  };
  recipients?: string[]; // email addresses
  parameters: TParams;
  createdBy: string;
  createdAt: string; // ISO date string
  updatedAt: string; // ISO date string
  lastRun?: string; // ISO date string
  lastStatus?: 'success' | 'failure';
}