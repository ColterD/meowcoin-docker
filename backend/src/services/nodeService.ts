// backend/src/services/nodeService.ts
// This is a partial update focusing on the error handling improvements

// Create backup of blockchain data with better error handling and logging
export async function createBackup(): Promise<boolean> {
    try {
      const backup_dir = `${MEOWCOIN_DATA}/backups`;
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const backup_file = `${backup_dir}/meowcoin_backup_${timestamp}.tar.gz`;
      
      // Ensure backup directory exists
      try {
        await fs.promises.mkdir(backup_dir, { recursive: true });
      } catch (error) {
        console.error(`Failed to create backup directory: ${error instanceof Error ? error.message : 'Unknown error'}`);
        return false;
      }
      
      console.log(`Creating backup: ${backup_file}`);
      
      // Create compressed backup - with timeout to prevent hanging
      try {
        const { stdout, stderr } = await execAsync(
          `tar -czf "${backup_file}" -C "${MEOWCOIN_DATA}" .meowcoin`,
          { timeout: 3600000 } // 1 hour timeout
        );
        
        if (stderr && stderr.length > 0) {
          console.warn(`Backup generated warnings: ${stderr}`);
        }
        
        console.log(`Backup completed successfully: ${backup_file}`);
        
        // Clean up old backups (keep last 5) - with error handling
        try {
          const backupFiles = await fs.promises.readdir(backup_dir);
          const backupPaths = backupFiles
            .filter(file => /^meowcoin_backup_.*\.tar\.gz$/.test(file))
            .map(file => path.join(backup_dir, file));
          
          // Sort by modification time (oldest first)
          const sortedBackups = await Promise.all(
            backupPaths.map(async file => {
              const stats = await fs.promises.stat(file);
              return { path: file, mtime: stats.mtime.getTime() };
            })
          );
          
          sortedBackups.sort((a, b) => a.mtime - b.mtime);
          
          // Delete all but the newest 5 backups
          const backupsToDelete = sortedBackups.slice(0, Math.max(0, sortedBackups.length - 5));
          
          for (const backup of backupsToDelete) {
            await fs.promises.unlink(backup.path);
            console.log(`Deleted old backup: ${backup.path}`);
          }
        } catch (error) {
          console.error(`Error cleaning up old backups: ${error instanceof Error ? error.message : 'Unknown error'}`);
          // Don't fail the backup operation if cleanup fails
        }
        
        return true;
      } catch (error) {
        console.error(`Backup command failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
        return false;
      }
    } catch (error) {
      console.error(`Unexpected error in createBackup: ${error instanceof Error ? error.message : 'Unknown error'}`);
      return false;
    }
  }