<?php

namespace App\Console\Commands;

use App\Models\Environment;
use App\Models\ProductionBackupLog;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class BackupProductionDatabase extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'production:backup
                            {--type=full : Backup type (full, incremental, differential)}
                            {--verify : Verify backup after creation}
                            {--upload : Upload to offsite storage}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Backup production database with retention policy';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $this->info('💾 Starting production database backup...');
        $this->newLine();

        // Get production environment
        $environment = Environment::where('type', 'production')->first();

        if (!$environment) {
            $this->error('❌ No production environment found');
            return self::FAILURE;
        }

        // Create backup log
        $backupLog = ProductionBackupLog::create([
            'environment_id' => $environment->id,
            'backup_type' => $this->option('type'),
            'status' => 'running',
            'started_at' => now(),
        ]);

        $startTime = microtime(true);

        try {
            // Step 1: Create backup
            $backupFile = $this->createBackup($backupLog);

            if (!$backupFile) {
                throw new \Exception('Failed to create backup file');
            }

            // Step 2: Verify backup (if requested)
            if ($this->option('verify')) {
                $this->info('🔍 Verifying backup integrity...');
                if (!$this->verifyBackup($backupFile)) {
                    throw new \Exception('Backup verification failed');
                }
                $this->info('   ✓ Backup verified successfully');
            }

            // Step 3: Upload to offsite storage (if requested)
            if ($this->option('upload')) {
                $this->info('☁️  Uploading to offsite storage...');
                $storageLocation = $this->uploadToOffsiteStorage($backupFile);

                if (!$storageLocation) {
                    throw new \Exception('Failed to upload to offsite storage');
                }

                $this->info("   ✓ Uploaded to {$storageLocation}");
            } else {
                $storageLocation = 'local';
            }

            // Step 4: Calculate duration and file size
            $duration = round(microtime(true) - $startTime);
            $fileSize = filesize($backupFile);

            // Update backup log
            $backupLog->update([
                'status' => 'completed',
                'backup_file' => basename($backupFile),
                'storage_location' => $storageLocation,
                'file_size_bytes' => $fileSize,
                'duration_seconds' => $duration,
                'completed_at' => now(),
                'backup_metadata' => [
                    'database' => config('database.connections.pgsql.database'),
                    'host' => config('database.connections.pgsql.host'),
                    'verified' => $this->option('verify'),
                    'uploaded' => $this->option('upload'),
                ],
            ]);

            // Step 5: Clean old backups based on retention policy
            $this->cleanOldBackups();

            $this->newLine();
            $this->info('✅ Backup completed successfully!');
            $this->info("   File: {$backupFile}");
            $this->info("   Size: " . $this->formatBytes($fileSize));
            $this->info("   Duration: {$duration} seconds");

            return self::SUCCESS;
        } catch (\Exception $e) {
            $duration = round(microtime(true) - $startTime);

            $backupLog->update([
                'status' => 'failed',
                'error_message' => $e->getMessage(),
                'duration_seconds' => $duration,
                'completed_at' => now(),
            ]);

            $this->error('❌ Backup failed: ' . $e->getMessage());
            return self::FAILURE;
        }
    }

    /**
     * Create database backup.
     */
    private function createBackup(ProductionBackupLog $backupLog): ?string
    {
        $timestamp = now()->format('Y-m-d_His');
        $type = $backupLog->backup_type;
        $backupFile = storage_path("backups/production_{$type}_{$timestamp}.sql.gz");

        // Ensure backup directory exists
        $backupDir = dirname($backupFile);
        if (!is_dir($backupDir)) {
            mkdir($backupDir, 0755, true);
        }

        $this->info("🔧 Creating {$type} backup...");

        // PostgreSQL backup command
        $dbHost = config('database.connections.pgsql.host');
        $dbName = config('database.connections.pgsql.database');
        $dbUser = config('database.connections.pgsql.username');
        $dbPassword = config('database.connections.pgsql.password');

        $pgDumpCommand = sprintf(
            'PGPASSWORD=%s pg_dump -h %s -U %s -F c %s | gzip > %s',
            escapeshellarg($dbPassword),
            escapeshellarg($dbHost),
            escapeshellarg($dbUser),
            escapeshellarg($dbName),
            escapeshellarg($backupFile)
        );

        exec($pgDumpCommand . ' 2>&1', $output, $returnCode);

        if ($returnCode !== 0) {
            $this->error('   ✗ Backup command failed');
            $this->error('   Output: ' . implode("\n", $output));
            return null;
        }

        if (!file_exists($backupFile)) {
            $this->error('   ✗ Backup file was not created');
            return null;
        }

        $this->info('   ✓ Backup file created');

        return $backupFile;
    }

    /**
     * Verify backup integrity.
     */
    private function verifyBackup(string $backupFile): bool
    {
        // Verify file exists and is readable
        if (!file_exists($backupFile) || !is_readable($backupFile)) {
            return false;
        }

        // Verify file size is reasonable (> 1KB)
        if (filesize($backupFile) < 1024) {
            return false;
        }

        // Verify gzip integrity
        exec("gzip -t " . escapeshellarg($backupFile) . " 2>&1", $output, $returnCode);

        return $returnCode === 0;
    }

    /**
     * Upload backup to offsite storage (S3/Backblaze).
     */
    private function uploadToOffsiteStorage(string $backupFile): ?string
    {
        $bucket = config('backup.s3_bucket');
        $region = config('filesystems.disks.s3.region', 'us-east-1');

        if (!$bucket) {
            $this->warn('   ⚠️  S3 bucket not configured');
            return null;
        }

        try {
            $fileName = basename($backupFile);
            $s3Path = "backups/production/{$fileName}";

            Storage::disk('s3')->put($s3Path, fopen($backupFile, 'r'));

            return "s3://{$bucket}/{$s3Path}";
        } catch (\Exception $e) {
            $this->error('   ✗ Upload failed: ' . $e->getMessage());
            return null;
        }
    }

    /**
     * Clean old backups based on retention policy.
     */
    private function cleanOldBackups(): void
    {
        $this->info('🧹 Cleaning old backups...');

        $retentionDays = config('backup.retention_days', 30);
        $cutoffDate = now()->subDays($retentionDays);

        $oldBackups = ProductionBackupLog::where('completed_at', '<', $cutoffDate)
            ->where('status', 'completed')
            ->get();

        $deleted = 0;

        foreach ($oldBackups as $backup) {
            // Delete local file
            if ($backup->backup_file) {
                $localFile = storage_path("backups/{$backup->backup_file}");
                if (file_exists($localFile)) {
                    unlink($localFile);
                }
            }

            // Delete from offsite storage
            if ($backup->storage_location && str_starts_with($backup->storage_location, 's3://')) {
                try {
                    $path = str_replace('s3://' . config('backup.s3_bucket') . '/', '', $backup->storage_location);
                    Storage::disk('s3')->delete($path);
                } catch (\Exception $e) {
                    // Log but continue
                    $this->warn("   ⚠️  Failed to delete S3 file: {$e->getMessage()}");
                }
            }

            // Delete backup log record
            $backup->delete();
            $deleted++;
        }

        $this->info("   ✓ Deleted {$deleted} old backups (retention: {$retentionDays} days)");
    }

    /**
     * Format bytes to human-readable size.
     */
    private function formatBytes(int $bytes): string
    {
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];

        for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
            $bytes /= 1024;
        }

        return round($bytes, 2) . ' ' . $units[$i];
    }
}
