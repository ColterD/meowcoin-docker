// backend/src/services/nodeMonitor.ts
import { Server } from 'socket.io';
import { getNodeStatus } from './nodeService';
import { getContainerLogs } from './systemService';
import { setupMonitor } from './monitorUtils';

// Node status monitoring interval (in ms)
const STATUS_INTERVAL = 5000;
const LOGS_INTERVAL = 10000;

// Setup node status monitoring
export function setupNodeMonitor(io: Server) {
  // Keep track of last log timestamp
  let lastLogTimestamp = Date.now();
  
  // Setup status monitor
  const statusCleanup = setupMonitor(
    io,
    getNodeStatus,
    'nodeStatus',
    STATUS_INTERVAL,
    5000,
    'node status'
  );
  
  // Setup logs monitor with custom function
  const logsMonitorFunction = async () => {
    const logs = await getContainerLogs(lastLogTimestamp);
    if (logs.success && logs.logs.length > 0) {
      lastLogTimestamp = logs.timestamp;
      return logs;
    }
    return null;
  };
  
  const logsCleanup = setupMonitor(
    io,
    logsMonitorFunction,
    'logs',
    LOGS_INTERVAL,
    7000,
    'logs'
  );
  
  // Return combined cleanup function
  return () => {
    statusCleanup();
    logsCleanup();
  };
}