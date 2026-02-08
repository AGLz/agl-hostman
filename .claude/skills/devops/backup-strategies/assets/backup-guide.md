# Laravel Backup and Disaster Recovery Guide

## Overview

This guide covers comprehensive backup strategies for Laravel applications, including database backups, file storage backups, retention policies, automated scheduling, restoration procedures, and disaster recovery planning.

## Core Concepts

### Backup Types

1. **Full Backups**: Complete database/files copy
2. **Incremental Backups**: Only changed data since last backup
3. **Differential Backups**: All changes since last full backup
4. **Snapshot Backups**: Point-in-time filesystem snapshots

### 3-2-1 Backup Rule

- **3** copies of data (production + 2 backups)
- **2** different storage types (local + cloud)
- **1** off-site backup (cloud or remote location)

### RTO and RPO

- **RTO (Recovery Time Objective)**: Target time to restore service
- **RPO (Recovery Point Objective)**: Maximum acceptable data loss (time)

## Database Backup Strategies

### MySQL Backups

#### mysqldump Backup

```php
<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

class BackupDatabase extends Command
{
    protected $signature = 'db:backup
                            {--filename= : Custom backup filename}
                            {--compress : Compress backup with gzip}
                            {--upload : Upload to S3}';
    protected $description = 'Create database backup';

    public function handle()
    {
        $timestamp = now()->format('Y_m_d_His');
        $filename = $this->option('filename') ?? "backup_{$timestamp}.sql";
        $compress = $this->option('compress');
        $upload = $this->option('upload');

        $localPath = storage_path("app/backups/{$filename}");

        $this->info("Creating database backup...");

        // Build mysqldump command
        $command = [
            'mysqldump',
            '--host=' . config('database.connections.mysql.host'),
            '--port=' . config('database.connections.mysql.port'),
            '--user=' . config('database.connections.mysql.username'),
            '--password=' . config('database.connections.mysql.password'),
            config('database.connections.mysql.database'),
            '--single-transaction',
            '--quick',
            '--lock-tables=false',
        ];

        if ($compress) {
            $command[] = '| gzip >';
            $localPath .= '.gz';
        } else {
            $command[] = '>';
        }

        $command[] = $localPath;

        // Execute backup
        $output = null;
        $returnCode = null;
        exec(implode(' ', $command), $output, $returnCode);

        if ($returnCode !== 0) {
            $this->error("Backup failed with code {$returnCode}");
            return 1;
        }

        $fileSize = filesize($localPath);
        $this->info("✓ Backup created: {$filename} ({$this->formatBytes($fileSize)})");

        // Upload to S3 if requested
        if ($upload) {
            $this->info("Uploading to S3...");
            $s3Path = "backups/database/" . basename($localPath);

            if (Storage::disk('s3')->put($s3Path, file_get_contents($localPath))) {
                $this->info("✓ Uploaded to S3: {$s3Path}");

                // Delete local copy after successful upload
                unlink($localPath);
                $this->info("✓ Local copy removed");
            } else {
                $this->warn("S3 upload failed, local backup retained");
            }
        }

        return 0;
    }

    protected function formatBytes($bytes): string
    {
        $units = ['B', 'KB', 'MB', 'GB'];
        $bytes = max($bytes, 0);
        $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
        $pow = min($pow, count($units) - 1);
        $bytes /= pow(1024, $pow);
        return round($bytes, 2) . ' ' . $units[$pow];
    }
}
```

#### Automated Backup Schedule

```php
<?php

namespace App\Console;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel
{
    protected function schedule(Schedule $schedule)
    {
        // Daily database backup at 2 AM
        $schedule->command('db:backup --compress --upload')
            ->dailyAt('02:00')
            ->onSuccess(function () {
                \Log::info('Database backup completed successfully');
            })
            ->onFailure(function () {
                \Log::error('Database backup failed');
                // Send alert
                \Notification::route('mail', 'ops@example.com')
                    ->notify(new \App\Notifications\BackupFailed());
            });

        // Weekly full backup (Sunday at 3 AM)
        $schedule->command('db:backup --compress --upload --filename=full_backup.sql')
            ->weeklyOn(0, '03:00');

        // Hourly transaction log backup for critical systems
        $schedule->command('db:backup-transactions')
            ->hourly();
    }
}
```

### PostgreSQL Backups

```bash
#!/bin/bash
# PostgreSQL backup script

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/var/backups/postgres"
FILENAME="backup_${TIMESTAMP}.sql.gz"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Dump and compress database
pg_dump -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" | gzip > "$BACKUP_DIR/$FILENAME"

# Upload to S3
aws s3 cp "$BACKUP_DIR/$FILENAME" s3://my-bucket/backups/postgres/

# Keep only last 30 days of backups
find "$BACKUP_DIR" -name "backup_*.sql.gz" -mtime +30 -delete
```

## File Storage Backups

### Local Storage Backup

```php
<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\Process\Process;

class BackupStorage extends Command
{
    protected $signature = 'storage:backup {--path=app : Storage path to backup}';
    protected $description = 'Backup local storage files';

    public function handle()
    {
        $path = $this->option('path');
        $timestamp = now()->format('Y_m_d_His');
        $filename = "storage_backup_{$path}_{$timestamp}.tar.gz";
        $localPath = storage_path("app/backups/{$filename}");

        $this->info("Creating storage backup for: {$path}");

        // Create archive
        $process = new Process([
            'tar',
            '-czf',
            $localPath,
            '-C',
            storage_path($path),
            '.'
        ]);

        $process->run();

        if (!$process->isSuccessful()) {
            $this->error("Backup failed: {$process->getErrorOutput()}");
            return 1;
        }

        $this->info("✓ Backup created: {$filename}");

        // Upload to S3
        $this->info("Uploading to S3...");
        $s3Path = "backups/storage/{$filename}";

        if (Storage::disk('s3')->put($s3Path, fopen($localPath, 'r'))) {
            $this->info("✓ Uploaded to S3: {$s3Path}");
        }

        return 0;
    }
}
```

### S3 Backup Strategy

```php
<?php

namespace App\Services;

use Illuminate\Support\Facades\Storage;
use Aws\S3\S3Client;

class S3BackupService
{
    protected $s3;

    public function __construct()
    {
        $this->s3 = new S3Client([
            'version' => 'latest',
            'region' => config('filesystems.disks.s3.region'),
            'credentials' => [
                'key' => config('filesystems.disks.s3.key'),
                'secret' => config('filesystems.disks.s3.secret'),
            ],
        ]);
    }

    /**
     * Create S3 bucket snapshot
     */
    public function createBucketSnapshot(string $bucket, string $snapshotName): void
    {
        // List all objects
        $objects = $this->s3->listObjectsV2([
            'Bucket' => $bucket,
        ]);

        if (!isset($objects['Contents'])) {
            return;
        }

        // Copy objects to snapshot location
        $iterator = $objects->get('Contents');
        foreach ($iterator as $object) {
            $sourceKey = $object['Key'];
            $targetKey = "snapshots/{$snapshotName}/{$sourceKey}";

            $this->s3->copyObject([
                'Bucket' => $bucket,
                'CopySource' => "{$bucket}/{$sourceKey}",
                'Key' => $targetKey,
            ]);
        }
    }

    /**
     * Enable S3 versioning for automatic backups
     */
    public function enableVersioning(string $bucket): void
    {
        $this->s3->putBucketVersioning([
            'Bucket' => $bucket,
            'VersioningConfiguration' => [
                'Status' => 'Enabled',
            ],
        ]);
    }
}
```

## Retention Policies

### Backup Retention Configuration

```php
<?php

namespace App\Services;

use Illuminate\Support\Facades\Storage;
use Carbon\Carbon;

class BackupRetentionService
{
    protected $policies = [
        'hourly' => 24,    // Keep 24 hours
        'daily' => 30,     // Keep 30 days
        'weekly' => 12,    // Keep 12 weeks
        'monthly' => 12,   // Keep 12 months
    ];

    /**
     * Clean old backups based on retention policy
     */
    public function cleanOldBackups(string $disk = 's3'): void
    {
        $backups = Storage::disk($disk)->files('backups/database');

        foreach ($backups as $backup) {
            $backupDate = $this->extractDateFromFilename($backup);

            if (!$backupDate) {
                continue;
            }

            $ageInDays = $backupDate->diffInDays(now());
            $shouldDelete = false;

            // Determine if backup should be deleted
            if ($ageInDays > $this->policies['daily'] * 30) {
                $shouldDelete = true;
            }

            if ($shouldDelete) {
                Storage::disk($disk)->delete($backup);
                \Log::info("Deleted old backup: {$backup}");
            }
        }
    }

    protected function extractDateFromFilename(string $filename): ?Carbon
    {
        // Extract date from filename like backup_2024_01_15_143022.sql
        if (preg_match('/backup_(\d{4}_\d{2}_\d{2}_\d{6})/', $filename, $matches)) {
            return Carbon::createFromFormat('Y_m_d_His', $matches[1]);
        }

        return null;
    }
}
```

## Restoration Procedures

### Database Restoration Command

```php
<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;

class RestoreDatabase extends Command
{
    protected $signature = 'db:restore {backup : Backup file name or S3 path}
                            {--force : Skip confirmation}
                            {--local : Use local backup instead of S3}';
    protected $description = 'Restore database from backup';

    public function handle()
    {
        $backup = $this->argument('backup');
        $local = $this->option('local');
        $force = $this->option('force');

        // Confirm restoration
        if (!$force && !$this->confirm("Restore database from {$backup}? This will replace all data.")) {
            return 0;
        }

        // Download backup if from S3
        if (!$local && str_starts_with($backup, 'backups/')) {
            $this->info("Downloading backup from S3...");
            $localPath = storage_path("app/temp/backup.sql.gz");

            Storage::disk('s3')->download($backup, $localPath);
        } else {
            $localPath = storage_path("app/backups/{$backup}");
        }

        // Check if file exists
        if (!file_exists($localPath)) {
            $this->error("Backup file not found: {$localPath}");
            return 1;
        }

        // Enable maintenance mode
        $this->call('down');

        try {
            // Drop existing database
            $this->info("Dropping existing database...");
            $this->call('db:wipe', ['--force' => true]);

            // Create new database
            $this->info("Creating fresh database...");
            config(['database.connections.mysql.database' => null]);
            \DB::statement("CREATE DATABASE `{$this->getDatabaseName()}`");
            config(['database.connections.mysql.database' => $this->getDatabaseName()]);

            // Restore backup
            $this->info("Restoring from backup (this may take a while)...");

            $command = str_ends_with($localPath, '.gz')
                ? "gunzip < {$localPath} | mysql -h {$this->getDbHost()} -u {$this->getDbUser()} -p{$this->getDbPassword()} {$this->getDatabaseName()}"
                : "mysql -h {$this->getDbHost()} -u {$this->getDbUser()} -p{$this->getDbPassword()} {$this->getDatabaseName()} < {$localPath}";

            exec($command, $output, $returnCode);

            if ($returnCode !== 0) {
                throw new \Exception("Restore failed with code {$returnCode}");
            }

            $this->info("✓ Database restored successfully");

            // Run migrations to ensure schema is up to date
            $this->call('migrate', ['--force' => true]);

        } catch (\Exception $e) {
            $this->error("Restore failed: {$e->getMessage()}");
            return 1;
        } finally {
            // Disable maintenance mode
            $this->call('up');
        }

        return 0;
    }

    protected function getDatabaseName(): string
    {
        return config('database.connections.mysql.database');
    }

    protected function getDbHost(): string
    {
        return config('database.connections.mysql.host');
    }

    protected function getDbUser(): string
    {
        return config('database.connections.mysql.username');
    }

    protected function getDbPassword(): string
    {
        return config('database.connections.mysql.password');
    }
}
```

## Disaster Recovery

### Point-in-Time Recovery (MySQL)

```bash
#!/bin/bash
# Point-in-time recovery script

FULL_BACKUP=$1
BINLOG_START=$2
BINLOG_END=$3

# Restore full backup
mysql < "$FULL_BACKUP"

# Apply binary logs
mysqlbinlog \
  --start-datetime="$BINLOG_START" \
  --stop-datetime="$BINLOG_END" \
  /var/lib/mysql/mysql-bin.000001 | mysql
```

### Disaster Recovery Runbook

```markdown
# Disaster Recovery Runbook

## Recovery Objectives
- **RTO**: 4 hours
- **RPO**: 15 minutes (for critical data)

## Scenarios

### 1. Database Corruption
1. Identify last good backup
2. Put application in maintenance mode
3. Restore database backup
4. Verify data integrity
5. Bring application back online
6. Monitor for errors

### 2. Complete Server Failure
1. Provision new server
2. Install dependencies (Docker, PHP, etc.)
3. Pull latest code from git
4. Restore database from latest backup
5. Restore file storage from S3
6. Configure environment variables
7. SSL certificates (use Let's Encrypt)
8. Health checks
9. DNS failover (if applicable)
10. Monitor logs

### 3. Accidental Data Deletion
1. Stop application immediately
2. Identify time of deletion
3. Restore from backup just before deletion
4. Apply binary logs to recover changes
5. Verify recovered data
6. Resume application

## Contact Information
- On-call DevOps: +1-XXX-XXX-XXXX
- Systems Lead: email@example.com
- CTO: ctemail@example.com

## Emergency Shells
```bash
# Quick restore script
curl -s https://scripts.example.com/emergency-restore.sh | bash
```
```

## Monitoring and Alerts

### Backup Health Check

```php
<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;
use Carbon\Carbon;

class CheckBackupHealth extends Command
{
    protected $signature = 'backup:health-check';
    protected $description = 'Check if backups are up to date';

    public function handle()
    {
        $latestBackup = $this->getLatestBackup();
        $maxAgeHours = 24; // Maximum acceptable age in hours

        if (!$latestBackup) {
            $this->error('No backups found!');
            \Notification::route('mail', 'ops@example.com')
                ->notify(new \App\Notifications\BackupMissing());
            return 1;
        }

        $ageInHours = $latestBackup->diffInHours(now());

        if ($ageInHours > $maxAgeHours) {
            $this->warn("Latest backup is {$ageInHours} hours old (max: {$maxAgeHours}h)");
            \Notification::route('mail', 'ops@example.com')
                ->notify(new \App\Notifications\BackupStale($ageInHours));
            return 1;
        }

        $this->info("✓ Latest backup is {$ageInHours} hours old (healthy)");
        return 0;
    }

    protected function getLatestBackup(): ?Carbon
    {
        $backups = Storage::disk('s3')->files('backups/database');
        $latestFile = collect($backups)->sortByDesc(function ($file) {
            return Storage::disk('s3')->lastModified($file);
        })->first();

        return $latestFile
            ? Carbon::createFromTimestamp(Storage::disk('s3')->lastModified($latestFile))
            : null;
    }
}
```

## Best Practices

1. **Automate everything** - Manual backups fail
2. **Test restores regularly** - Untested backups are useless
3. **Encrypt backups** - At rest and in transit
4. **Use lifecycle policies** - Auto-delete old backups
5. **Monitor backup jobs** - Alert on failures
6. **Document procedures** - Keep runbooks up to date
7. **Geographic redundancy** - Store backups in multiple regions
8. **Version control backups** - Track what changed
9. **Secure backup credentials** - Rotate regularly
10. **Compliance requirements** - Meet regulatory standards (GDPR, HIPAA)
