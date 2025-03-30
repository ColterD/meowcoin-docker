import { Server } from 'socket.io';
import { getDiskUsageDetails } from './systemService';

// Disk usage monitoring interval (in ms)
const DISK_INTERVAL = 900000; // 15 minutes

// Setup disk usage monitoring
export function setupDiskMonitor(io: Server) {
  // Initial disk usage check
  setTimeout(async () => {
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
  const diskInterval = setInterval(async () => {
    try {
      const diskUsage = await getDiskUsageDetails();
      if (diskUsage.success) {
        io.emit('diskUsage', diskUsage);
      }
    } catch (error) {
      console.error('Error in disk monitor:', error);
    }
  }, DISK_INTERVAL);
  
  // Cleanup on process exit
  process.on('exit', () => {
    clearInterval(diskInterval);
  });
}