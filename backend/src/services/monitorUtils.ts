// backend/src/services/monitorUtils.ts
import { Server } from 'socket.io';

export interface MonitorCleanup {
  (): void;
}

export function setupCleanupHandler(
  cleanup: () => void,
  name: string
): void {
  // Remove existing listener to prevent duplicates
  process.removeListener('exit', cleanup);
  process.removeListener('SIGTERM', cleanup);
  process.removeListener('SIGINT', cleanup);
  
  // Register new listener for different signals
  process.on('exit', cleanup);
  process.on('SIGTERM', () => {
    console.log(`Received SIGTERM - cleaning up ${name} monitor`);
    cleanup();
  });
  process.on('SIGINT', () => {
    console.log(`Received SIGINT - cleaning up ${name} monitor`);
    cleanup();
  });
}

export function setupMonitor<T>(
  io: Server,
  monitorFunction: () => Promise<T | null>,
  eventName: string,
  interval: number,
  initialDelay: number = 5000,
  name: string = 'generic'
): MonitorCleanup {
  let intervalId: NodeJS.Timeout;
  
  // Initial check
  const initialCheckTimeout = setTimeout(async () => {
    try {
      const data = await monitorFunction();
      if (data) {
        io.emit(eventName, data);
      }
    } catch (error) {
      console.error(`Error in initial ${name} monitor check:`, error);
    }
  }, initialDelay);
  
  // Periodic check
  intervalId = setInterval(async () => {
    try {
      const data = await monitorFunction();
      if (data) {
        io.emit(eventName, data);
      }
    } catch (error) {
      console.error(`Error in ${name} monitor:`, error);
    }
  }, interval);
  
  // Cleanup function
  const cleanup = () => {
    clearInterval(intervalId);
    clearTimeout(initialCheckTimeout);
  };
  
  // Setup cleanup handler
  setupCleanupHandler(cleanup, name);
  
  return cleanup;
}