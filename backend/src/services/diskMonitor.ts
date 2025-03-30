import { Server } from 'socket.io';
import { getDiskUsageDetails } from './systemService';

// Disk usage monitoring interval (in ms)
const DISK_INTERVAL = 900000; // 15 minutes

// Setup disk usage monitoring
export function setupDiskMonitor(io: Server) {
  let intervalId: NodeJS.Timeout;
  
  // Initial disk usage check
  const initialCheckTimeout = setTimeout(async () => {
    try {
      const diskUsage = await getDiskUsageDetails();
      if (diskUsage.success) {
        io.emit('diskUsage', diskUsage);
      }
    } catch (error) {
      console.error('Error in initial disk monitor check:', error);
    }
  }, 5000);
  
  // Periodically check disk usage and emit to connected clients
  intervalId = setInterval(async () => {
    try {
      const diskUsage = await getDiskUsageDetails();
      if (diskUsage.success) {
        io.emit('diskUsage', diskUsage);
      }
    } catch (error) {
      console.error('Error in disk monitor:', error);
    }
  }, DISK_INTERVAL);
  
  // Cleanup on process exit - only register this once
  const cleanup = () => {
    clearInterval(intervalId);
    clearTimeout(initialCheckTimeout);
  };
  
  // Remove existing listeners to prevent duplicates
  process.removeListener('exit', cleanup);
  
  // Register new listener
  process.on('exit', cleanup);
  
  // Return a function to clean up resources
  return () => {
    cleanup();
    process.removeListener('exit', cleanup);
  };
}