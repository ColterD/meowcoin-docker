import { Server } from 'socket.io';
import { getNodeStatus } from './nodeService';
import { getContainerLogs } from './systemService';

// Node status monitoring interval (in ms)
const STATUS_INTERVAL = 5000;

// Keep track of last log timestamp
let lastLogTimestamp = 0;

// Setup node status monitoring
export function setupNodeMonitor(io: Server) {
  // Initialize last log timestamp
  lastLogTimestamp = Date.now();
  
  let statusIntervalId: NodeJS.Timeout;
  let logsIntervalId: NodeJS.Timeout;
  
  // Periodically check node status and emit to connected clients
  statusIntervalId = setInterval(async () => {
    try {
      const status = await getNodeStatus();
      if (status) {
        io.emit('nodeStatus', status);
      }
    } catch (error) {
      console.error('Error in node monitor:', error);
    }
  }, STATUS_INTERVAL);
  
  // Logs monitoring (every 10 seconds)
  logsIntervalId = setInterval(async () => {
    try {
      const logs = await getContainerLogs(lastLogTimestamp);
      if (logs.success && logs.logs.length > 0) {
        lastLogTimestamp = logs.timestamp;
        io.emit('logs', logs);
      }
    } catch (error) {
      console.error('Error in logs monitor:', error);
    }
  }, 10000);
  
  // Define cleanup function
  const cleanup = () => {
    clearInterval(statusIntervalId);
    clearInterval(logsIntervalId);
  };
  
  // Remove existing listener to prevent duplicates
  process.removeListener('exit', cleanup);
  
  // Add new listener
  process.on('exit', cleanup);
  
  // Return cleanup function
  return cleanup;
}