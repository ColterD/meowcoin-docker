// backend/src/services/diskMonitor.ts
import { Server } from 'socket.io';
import { getDiskUsageDetails } from './systemService';
import { setupMonitor } from './monitorUtils';

// Disk usage monitoring interval (in ms)
const DISK_INTERVAL = 900000; // 15 minutes

// Setup disk usage monitoring
export function setupDiskMonitor(io: Server) {
  return setupMonitor(
    io,
    getDiskUsageDetails,
    'diskUsage',
    DISK_INTERVAL,
    5000,
    'disk usage'
  );
}