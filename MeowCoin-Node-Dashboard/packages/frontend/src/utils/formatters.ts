import { CPU_WARNING_THRESHOLD, MEMORY_WARNING_THRESHOLD, DISK_WARNING_THRESHOLD } from '@meowcoin/shared';

// Format percentage values
export const formatPercentage = (value: number): string => {
  return `${value.toFixed(1)}%`;
};

// Format date strings
export const formatDate = (dateString: string): string => {
  const date = new Date(dateString);
  return date.toLocaleString();
};

// Format bytes to human-readable values
export const formatBytes = (bytes: number, decimals = 2): string => {
  if (bytes === 0) return '0 Bytes';
  
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(decimals))} ${sizes[i]}`;
};

// Get status color based on resource usage
export const getStatusColor = (type: 'cpu' | 'memory' | 'disk', value: number): string => {
  let threshold: number;
  
  switch (type) {
    case 'cpu':
      threshold = CPU_WARNING_THRESHOLD;
      break;
    case 'memory':
      threshold = MEMORY_WARNING_THRESHOLD;
      break;
    case 'disk':
      threshold = DISK_WARNING_THRESHOLD;
      break;
    default:
      threshold = 80;
  }
  
  if (value >= threshold) {
    return 'text-red-500';
  } else if (value >= threshold * 0.7) {
    return 'text-yellow-500';
  }
  
  return 'text-green-500';
};

// Format uptime in a human-readable format
export const formatUptime = (uptimeSeconds: number): string => {
  if (uptimeSeconds < 60) {
    return `${uptimeSeconds} seconds`;
  }
  
  const minutes = Math.floor(uptimeSeconds / 60);
  if (minutes < 60) {
    return `${minutes} minute${minutes !== 1 ? 's' : ''}`;
  }
  
  const hours = Math.floor(minutes / 60);
  if (hours < 24) {
    const remainingMinutes = minutes % 60;
    return `${hours} hour${hours !== 1 ? 's' : ''} ${remainingMinutes} minute${remainingMinutes !== 1 ? 's' : ''}`;
  }
  
  const days = Math.floor(hours / 24);
  const remainingHours = hours % 24;
  return `${days} day${days !== 1 ? 's' : ''} ${remainingHours} hour${remainingHours !== 1 ? 's' : ''}`;
};