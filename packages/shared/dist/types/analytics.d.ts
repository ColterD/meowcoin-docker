import { TimeRangeFilter } from './common';
/**
 * Time series data point
 */
export interface TimeSeriesDataPoint {
    timestamp: string;
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
    hashrate: number;
    averageBlockTime: number;
    mempoolSize: number;
    mempoolBytes: number;
    totalTransactions: number;
    totalBlocks: number;
    totalSupply: number;
    circulatingSupply: number;
    averageFee: number;
    medianFee: number;
    lastUpdated: string;
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
    totalBandwidth: number;
    inboundBandwidth: number;
    outboundBandwidth: number;
    lastUpdated: string;
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
    averageTransactionSize: number;
    averageTransactionFee: number;
    medianTransactionFee: number;
    feeDistribution: {
        [range: string]: number;
    };
    transactionTypes: {
        [type: string]: number;
    };
    lastUpdated: string;
}
/**
 * Block metrics
 */
export interface BlockMetrics {
    averageBlockSize: number;
    averageTransactionsPerBlock: number;
    averageBlockTime: number;
    blockSizeDistribution: {
        [range: string]: number;
    };
    lastUpdated: string;
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
export interface DashboardWidget {
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
    config: {
        metric?: string;
        chart?: {
            type: 'line' | 'bar' | 'pie' | 'area' | 'scatter';
            stacked?: boolean;
            showLegend?: boolean;
            showGrid?: boolean;
            showTooltip?: boolean;
            showDataLabels?: boolean;
        };
        timeRange?: {
            start: string;
            end?: string;
            preset?: 'last_hour' | 'last_day' | 'last_week' | 'last_month' | 'last_year';
        };
        refreshInterval?: number;
        [key: string]: any;
    };
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
    createdAt: string;
    updatedAt: string;
}
/**
 * Report
 */
export interface Report {
    id: string;
    name: string;
    description?: string;
    type: 'blockchain' | 'network' | 'transaction' | 'custom';
    format: 'pdf' | 'csv' | 'json';
    schedule?: {
        frequency: 'daily' | 'weekly' | 'monthly';
        dayOfWeek?: number;
        dayOfMonth?: number;
        time: string;
        timezone: string;
    };
    recipients?: string[];
    parameters: any;
    createdBy: string;
    createdAt: string;
    updatedAt: string;
    lastRun?: string;
    lastStatus?: 'success' | 'failure';
}
