#!/usr/bin/env node

/**
 * Meowcoin backup script
 * Creates, verifies, and manages backups of the Meowcoin node
 */

const core = require('../core');
const path = require('path');
const fs = require('fs');

// Initialize core modules
async function init() {
  await core.logging.initialize();
  await core.config.initialize();
  await core.backup.initialize();
}

// Process command line arguments
async function processArgs() {
  const command = process.argv[2] || 'help';
  const type = process.argv[3] || 'manual';
  
  switch (command) {
    case 'create':
      await createBackup(type);
      break;
    case 'verify':
      await verifyBackups();
      break;
    case 'cleanup':
      await cleanupBackups();
      break;
    case 'restore':
      const file = process.argv[3];
      const key = process.argv[4];
      if (!file) {
        console.error('Error: Backup file path required');
        showHelp();
        process.exit(1);
      }
      await restoreBackup(file, key);
      break;
    case 'list':
      await listBackups();
      break;
    case 'help':
    default:
      showHelp();
      break;
  }
}

// Create a backup
async function createBackup(type) {
  console.log(`Creating ${type} backup...`);
  
  try {
    const result = await core.backup.createBackup(type);
    
    if (result.success) {
      console.log(`Backup created successfully: ${result.file}`);
      console.log(`Size: ${formatSize(result.size)}`);
      console.log(`Checksum: ${result.checksum}`);
      process.exit(0);
    } else {
      console.error(`Backup failed: ${result.error}`);
      process.exit(1);
    }
  } catch (error) {
    console.error(`Backup failed: ${error.message}`);
    process.exit(1);
  }
}

// Verify backups
async function verifyBackups() {
  console.log('Verifying backups...');
  
  try {
    const backupDir = core.backup.backupDir;
    const files = fs.readdirSync(backupDir)
      .filter(file => file.endsWith('.tar.gz'))
      .map(file => path.join(backupDir, file));
    
    console.log(`Found ${files.length} backups to verify`);
    
    let successCount = 0;
    let failCount = 0;
    
    for (const file of files) {
      process.stdout.write(`Verifying ${path.basename(file)}... `);
      
      if (await core.backup.verifyBackup(file)) {
        process.stdout.write('OK\n');
        successCount++;
      } else {
        process.stdout.write('FAILED\n');
        failCount++;
      }
    }
    
    console.log(`Verification complete: ${successCount} OK, ${failCount} FAILED`);
    
    if (failCount > 0) {
      process.exit(1);
    } else {
      process.exit(0);
    }
  } catch (error) {
    console.error(`Verification failed: ${error.message}`);
    process.exit(1);
  }
}

// Clean up old backups
async function cleanupBackups() {
  console.log('Cleaning up old backups...');
  
  try {
    await core.backup.cleanupBackups();
    console.log('Cleanup complete');
    process.exit(0);
  } catch (error) {
    console.error(`Cleanup failed: ${error.message}`);
    process.exit(1);
  }
}

// Restore a backup
async function restoreBackup(file, key) {
  console.log(`Restoring backup: ${file}...`);
  
  try {
    if (await core.backup.restoreBackup(file, key)) {
      console.log('Restore complete');
      process.exit(0);
    } else {
      console.error('Restore failed');
      process.exit(1);
    }
  } catch (error) {
    console.error(`Restore failed: ${error.message}`);
    process.exit(1);
  }
}

// List backups
async function listBackups() {
  console.log('Available backups:');
  
  try {
    const backupDir = core.backup.backupDir;
    const files = fs.readdirSync(backupDir)
      .filter(file => file.endsWith('.tar.gz'))
      .map(file => ({
        file,
        path: path.join(backupDir, file),
        stats: fs.statSync(path.join(backupDir, file))
      }))
      .sort((a, b) => b.stats.mtime.getTime() - a.stats.mtime.getTime());
    
    if (files.length === 0) {
      console.log('No backups found');
      process.exit(0);
    }
    
    console.log('');
    console.log('| Backup                                | Size     | Date                 |');
    console.log('|---------------------------------------|----------|----------------------|');
    
    for (const backup of files) {
      const name = backup.file.padEnd(38);
      const size = formatSize(backup.stats.size).padEnd(9);
      const date = backup.stats.mtime.toISOString().replace('T', ' ').substr(0, 19);
      
      console.log(`| ${name}| ${size}| ${date} |`);
    }
    
    console.log('');
    process.exit(0);
  } catch (error) {
    console.error(`Failed to list backups: ${error.message}`);
    process.exit(1);
  }
}

// Show help
function showHelp() {
  console.log('Meowcoin Backup Tool');
  console.log('');
  console.log('Usage:');
  console.log('  meowcoin-backup.js create [type]     Create a new backup');
  console.log('  meowcoin-backup.js verify            Verify all backups');
  console.log('  meowcoin-backup.js cleanup           Clean up old backups');
  console.log('  meowcoin-backup.js restore <file>    Restore a backup');
  console.log('  meowcoin-backup.js list              List available backups');
  console.log('  meowcoin-backup.js help              Show this help');
  console.log('');
  console.log('Options:');
  console.log('  type    Backup type (default: manual)');
  console.log('  file    Path to backup file');
  console.log('');
}

// Format file size
function formatSize(size) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let i = 0;
  
  while (size >= 1024 && i < units.length - 1) {
    size /= 1024;
    i++;
  }
  
  return `${Math.round(size * 100) / 100} ${units[i]}`;
}

// Run script
init()
  .then(processArgs)
  .catch(error => {
    console.error(`Unhandled error: ${error.message}`);
    process.exit(1);
  });