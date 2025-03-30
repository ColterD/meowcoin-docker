// backend/src/services/systemService.ts
import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import path from 'path';
import { LogResponse } from '../types';

const execAsync = promisify(exec);
const MEOWCOIN_DATA = process.env.MEOWCOIN_DATA || '/data';

// Safe path validation function with improved security
function isPathSafe(inputPath: string): boolean {
  try {
    // Normalize path to prevent directory traversal
    const normalizedPath = path.normalize(inputPath);
    
    // Get the canonical path (resolves symbolic links)
    const canonicalPath = path.resolve(normalizedPath);
    
    // Check if path exists
    if (!fs.existsSync(canonicalPath)) {
      return false;
    }
    
    // Check for suspicious characters or patterns that could be used for command injection
    const suspiciousPatterns = [';', '&', '|', '>', '<', '`', '$', '(', ')', '{', '}', '[', ']', '!', '*', '?', '~', '\n', '\r'];
    if (suspiciousPatterns.some(pattern => normalizedPath.includes(pattern))) {
      return false;
    }
    
    // Ensure path doesn't contain double quotes which could break command strings
    if (normalizedPath.includes('"')) {
      return false;
    }
    
    return true;
  } catch (error) {
    console.error('Error validating path safety:', error);
    return false;
  }
}

// Get container logs with improved security
export async function getContainerLogs(since: number): Promise<LogResponse> {
  try {
    // Validate input
    if (typeof since !== 'number' || since < 0 || !Number.isInteger(since)) {
      console.error('Invalid since parameter:', since);
      return {
        success: false,
        logs: [],
        timestamp: Date.now()
      };
    }
    
    // Use a safer approach with validated input
    // Limit the amount of logs that can be retrieved
    const maxLines = 500;
    const safeCommand = `docker logs --tail ${maxLines} meowcoin-node 2>&1`;
    
    const { stdout, stderr } = await execAsync(safeCommand);
    
    // Combine stdout and stderr
    const allLogs = stdout + stderr;
    const lines = allLogs.split('\n').filter(line => line.trim() !== '');
    
    // If since is provided, filter logs by timestamp
    let filteredLogs = lines;
    if (since > 0) {
      const sinceDate = new Date(since);
      filteredLogs = lines.filter(line => {
        // Extract timestamp from log line if present
        const timestampMatch = line.match(/\[([\d-]+ [\d:]+)\]/);
        if (timestampMatch) {
          try {
            const logDate = new Date(timestampMatch[1]);
            return !isNaN(logDate.getTime()) && logDate.getTime() > sinceDate.getTime();
          } catch (e) {
            return true; // If date parsing fails, include the line
          }
        }
        return true;
      });
    }
    
    // Limit the number of logs returned for performance
    const limitedLogs = filteredLogs.slice(-maxLines);
    
    return {
      success: true,
      logs: limitedLogs,
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

// Get disk usage details with improved security
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
          
          // Execute command with properly escaped path
          const { stdout } = await execAsync(`du -sb "${safePath.replace(/"/g, '\\"')}" 2>/dev/null`);
          const sizeParts = stdout.split('\t');
          if (sizeParts.length < 1) {
            console.error(`Unexpected du output format for path: ${safePath}`);
            continue;
          }
          
          const size = parseInt(sizeParts[0], 10);
          if (isNaN(size)) {
            console.error(`Invalid size value for path: ${safePath}`);
            continue;
          }
          
          results.push({
            path: safePath,
            sizeBytes: size
          });
          
          // If it's the main blockchain dir, check subdirectories using a safer approach
          if (safePath === path.resolve("/home/meowcoin/.meowcoin")) {
            try {
              // List subdirectories directly instead of using find
              const subdirs = fs.readdirSync(safePath)
                .filter(item => {
                  const fullPath = path.join(safePath, item);
                  return fs.statSync(fullPath).isDirectory() && 
                         !['blocks', 'chainstate', 'database'].includes(item);
                })
                .map(item => path.join(safePath, item));
              
              for (const subdir of subdirs) {
                // Validate subdir path
                if (!isPathSafe(subdir)) {
                  console.error(`Unsafe subdirectory path detected: ${subdir}`);
                  continue;
                }
                
                const safeSubdir = path.resolve(subdir);
                const { stdout: subdirSize } = await execAsync(`du -sb "${safeSubdir.replace(/"/g, '\\"')}" 2>/dev/null`);
                const subdirSizeParts = subdirSize.split('\t');
                if (subdirSizeParts.length < 1) {
                  continue;
                }
                
                const size = parseInt(subdirSizeParts[0], 10);
                if (isNaN(size)) {
                  continue;
                }
                
                if (size > 10 * 1024 * 1024) { // Only add if > 10MB
                  results.push({
                    path: safeSubdir,
                    sizeBytes: size
                  });
                }
              }
            } catch (error) {
              console.error(`Error checking subdirectories for ${safePath}:`, error);
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