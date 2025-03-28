# Backup and Recovery

## Automated Backups

The container includes a robust backup system that can be enabled with:

```yaml
environment:
  - ENABLE_BACKUPS=true
```

### Backup Configuration

| Variable                 | Default     | Description                        |
|--------------------------|-------------|------------------------------------|
| BACKUP_SCHEDULE          | 0 0 * * *   | Cron schedule (daily at midnight) |
| MAX_BACKUPS              | 7           | Number of backups to retain       |
| BACKUP_COMPRESSION_LEVEL| 6           | Compression level (1-9)           |
| BACKUP_ENCRYPTION_KEY    | (Optional)  | Encryption password               |
| BACKUP_REMOTE_ENABLED    | false       | Enable remote storage             |

### Backup Contents

The backup includes essential wallet data while excluding large blockchain files:

- Wallet files (`wallet.dat`)
- Configuration files
- Key files
- Transaction indexes

### Remote Backup Storage

Configure remote backup destinations:

```yaml
environment:
  - BACKUP_REMOTE_ENABLED=true
  - BACKUP_REMOTE_TYPE=s3
  - BACKUP_S3_BUCKET=my-meowcoin-backups
  # For AWS S3
  - AWS_ACCESS_KEY_ID=your_access_key
  - AWS_SECRET_ACCESS_KEY=your_secret_key
  - AWS_DEFAULT_REGION=us-east-1
```

**Supported remote types:**

- `s3`: Amazon S3 or compatible storage
- `sftp`: SFTP server

## Recovery Process

To restore from a backup:

1. **Stop the container:**
   ```bash
   docker-compose down
   ```

2. **Find the backup file in the volume:**
   ```bash
   docker volume inspect meowcoin-data
   # Note the Mountpoint path
   ls /var/lib/docker/volumes/meowcoin-data/_data/backups/
   ```

3. **Extract the backup:**
   ```bash
   tar -xzf /path/to/backup/meowcoin_backup_20250327_123456.tar.gz -C /tmp/restore/
   ```

4. **If encrypted, decrypt first:**
   ```bash
   openssl enc -d -aes-256-cbc -in backup.tar.gz.enc -out backup.tar.gz
   ```

5. **Restore wallet files:**
   ```bash
   cp /tmp/restore/home/meowcoin/.meowcoin/wallet.dat /var/lib/docker/volumes/meowcoin-data/_data/
   ```

6. **Restart the container:**
   ```bash
   docker-compose up -d
   ```
