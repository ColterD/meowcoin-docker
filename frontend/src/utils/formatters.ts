/**
 * Format bytes to a human-readable string with appropriate units
 * @param bytes - The number of bytes to format
 * @param decimals - The number of decimal places to include
 * @returns Formatted string (e.g. "1.5 MB")
 */
export function formatBytes(bytes: number, decimals = 2) {
    if (bytes === 0) return '0 B';
    
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return `${parseFloat((bytes / Math.pow(k, i)).toFixed(dm))} ${sizes[i]}`;
  }
  
  /**
   * Format bytes per second to a human-readable string
   * @param bytes - The number of bytes per second to format
   * @returns Formatted string (e.g. "1.5 MB/s")
   */
  export function formatBytesPerSecond(bytes: number) {
    return `${formatBytes(bytes)}/s`;
  }