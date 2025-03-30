import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import path from 'path';
import { LogResponse } from '../types';

const execAsync = promisify(exec);
const MEOWCOIN_DATA = process.env.MEOWCOIN_DATA || '/data';

// Safe path validation function
function isPathSafe(inputPath: string): boolean {
  // Normalize path to prevent directory traversal
  const normalizedPath = path.normalize(inputPath);
  
  // Check for suspicious characters or patterns
  const suspiciousPatterns = [';', '&', '|', '>', '<', '`', '$', '(', ')', '{', '}', '[', ']', '!', '*', '?', '~'];
  if (suspiciousPatterns.some(pattern => normalizedPath.includes(pattern))) {
    return false;
  }
  
  // Additional checks can be added here
  
  return true;
}

// Get container logs
export async function getContainerLogs(since: number): Promise<LogResponse> {
  try {
    // Validate input
    if (typeof since !== 'number' || since < 0) {
      console.error('Invalid since parameter:', since);
      return {
        success: false,
        logs: [],
        timestamp: Date.now()
      };
    }
    
    // Safe command with validated input
    const { stdout, stderr } = await execAsync('docker logs --tail 100 meowcoin-node 2>&1');
    
    // Combine stdout and stderr
    const allLogs = stdout + stderr;
    const lines = allLogs.split('\n').filter(line => line.trim() !== '');
    
    // If since is provided, filter logs by timestamp
    let filteredLogs = lines;
    if (since > 0) {
      // This is a simplified approach - in production, you'd want to parse
      // actual timestamps from the logs and filter accurately
      const sinceDate = new Date(since);
      filteredLogs = lines.filter(line => {
        // Extract timestamp from log line if present
        const timestampMatch = line.match(/\[([\d-]+ [\d:]+)\]/);
        if (timestampMatch) {
          const logDate = new Date(timestampMatch[1]);
          return logDate.getTime() > sinceDate.getTime();
        }
        return true;
      });
    }
    
    return {
      success: true,
      logs: filteredLogs,
      timestamp: Date.now()
    };
  } catch (error) {
    console.error('Error getting container logs:', error);
    return {
      success: false,
      logs: [],
      timestamp: Date.now()
    };
  }
}

// Get disk usage details
export async function getDiskUsageDetails() {
  try {
    // List of paths to check - these should be validated
    const paths = [
      "/home/meowcoin/.meowcoin",
      "/home/meowcoin/.meowcoin/blocks",
      "/home/meowcoin/.meowcoin/chainstate",
      "/home/meowcoin/.meowcoin/database",
      "/data",
      "/data/backups",
      "/var/log",
      "/config"
    ];
    
    const results = [];
    
    for (const pathToCheck of paths) {
      try {
        // Validate path before using it in shell command
        if (!isPathSafe(pathToCheck)) {
          console.error(`Unsafe path detected: ${pathToCheck}`);
          continue;
        }
        
        if (fs.existsSync(pathToCheck)) {
          // Use path.resolve to get canonical path
          const safePath = path.resolve(pathToCheck);
          const { stdout } = await execAsync(`du -sb "${safePath}" 2>/dev/null`);
          const size = parseInt(stdout.split('\t')[0], 10);
          
          results.push({
            path: safePath,
            sizeBytes: size
          });
          
          // If it's the main blockchain dir, check subdirectories
          if (safePath === path.resolve("/home/meowcoin/.meowcoin")) {
            // Use safer find command with predefined paths
            const { stdout: subdirs } = await execAsync(
              `find "${safePath}" -maxdepth 1 -type d | grep -v "^${safePath}$" | grep -v "/blocks$" | grep -v "/chainstate$" | grep -v "/database$"`
            );
            
            const subdirList = subdirs.split('\n').filter(d => d);
            
            for (const subdir of subdirList) {
              // Validate subdir path
              if (!isPathSafe(subdir)) {
                console.error(`Unsafe subdirectory path detected: ${subdir}`);
                continue;
              }
              
              const safeSubdir = path.resolve(subdir);
              const { stdout: subdirSize } = await execAsync(`du -sb "${safeSubdir}" 2>/dev/null`);
              const size = parseInt(subdirSize.split('\t')[0], 10);
              
              if (size > 10 * 1024 * 1024) { // Only add if > 10MB
                results.push({
                  path: safeSubdir,
                  sizeBytes: size
                });
              }
            }
          }
        }
      } catch (error) {
        console.error(`Error checking disk usage for ${pathToCheck}:`, error);
      }
    }
    
    return {
      success: true,
      paths: results
    };
  } catch (error) {
    console.error('Error getting disk usage details:', error);
    return {
      success: false,
      paths: []
    };
  }
}