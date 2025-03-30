import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import { LogResponse } from '../types';

const execAsync = promisify(exec);
const MEOWCOIN_DATA = process.env.MEOWCOIN_DATA || '/data';

// Get container logs
export async function getContainerLogs(since: number): Promise<LogResponse> {
  try {
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
    // List of paths to check
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
    
    for (const path of paths) {
      try {
        if (fs.existsSync(path)) {
          const { stdout } = await execAsync(`du -sb "${path}" 2>/dev/null`);
          const size = parseInt(stdout.split('\t')[0], 10);
          
          results.push({
            path,
            sizeBytes: size
          });
          
          // If it's the main blockchain dir, check subdirectories
          if (path === "/home/meowcoin/.meowcoin") {
            const { stdout: subdirs } = await execAsync(
              `find "${path}" -maxdepth 1 -type d | grep -v "^${path}$" | grep -v "/blocks$" | grep -v "/chainstate$" | grep -v "/database$"`
            );
            
            const subdirList = subdirs.split('\n').filter(d => d);
            
            for (const subdir of subdirList) {
              const { stdout: subdirSize } = await execAsync(`du -sb "${subdir}" 2>/dev/null`);
              const size = parseInt(subdirSize.split('\t')[0], 10);
              
              if (size > 10 * 1024 * 1024) { // Only add if > 10MB
                results.push({
                  path: subdir,
                  sizeBytes: size
                });
              }
            }
          }
        }
      } catch (error) {
        console.error(`Error checking disk usage for ${path}:`, error);
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