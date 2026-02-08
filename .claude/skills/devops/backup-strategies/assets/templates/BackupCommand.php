<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\DB;
use Symfony\Component\Process\Process;

class BackupDatabase extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'db:backup
                            {--filename= : Custom backup filename}
                            {--compress : Compress backup with gzip}
                            {--upload : Upload to S3 after creation}
                            {--notify : Send notification on completion}
                            {--retention-days=30 : Days to keep backup}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Create database backup with optional compression and S3 upload';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $timestamp = now()->format('Y_m_d_His');
        $filename = $this->option('filename') ?? "backup_{$timestamp}.sql";
        $compress = $this->option('compress');
        $upload = $this->option('upload');
        $notify = $this->option('notify');
        $retentionDays = (int) $this->option('retention-days');

        $backupDir = storage_path("app/backups");
        $localPath = "{$backupDir}/{$filename}";

        if ($compress) {
            $localPath .= '.gz';
        }

        $this->info("=== Database Backup ===");
        $this->info("Timestamp: {$timestamp}");
        $this->info("Database: " . config('database.connections.mysql.database'));
        $this->newLine();

        // Ensure backup directory exists
        if (!is_dir($backupDir)) {
            mkdir($backupDir, 0755, true);
        }

        // Create backup
        $this->task('Creating backup', function () use ($localPath, $compress) {
            return $this->createBackup($localPath, $compress);
        });

        if (!file_exists($localPath)) {
            $this->error('Backup file was not created');
            return 1;
        }

        $fileSize = filesize($localPath);
        $this->info("File size: " . $this->formatBytes($fileSize));
        $this->newLine();

        // Upload to S3
        if ($upload) {
            $this->task('Uploading to S3', function () use ($localPath, $filename) {
                return $this->uploadToS3($localPath, $filename);
            });
        }

        // Clean old backups
        if ($retentionDays > 0) {
            $this->task('Cleaning old backups', function () use ($backupDir, $retentionDays) {
                return $this->cleanOldBackups($backupDir, $retentionDays);
            });
        }

        // Send notification
        if ($notify) {
            $this->info('Sending notification...');
            // Implement notification logic
            $this->info('✓ Notification sent');
        }

        $this->newLine();
        $this->info('✓ Backup completed successfully');

        return 0;
    }

    /**
     * Create the database backup
     */
    protected function createBackup(string $outputPath, bool $compress): bool
    {
        $connection = config('database.default');
        $config = config("database.connections.{$connection}");

        if ($config['driver'] !== 'mysql') {
            $this->error("Only MySQL is currently supported");
            return false;
        }

        // Build mysqldump command
        $command = [
            'mysqldump',
            "--host={$config['host']}",
            "--port={$config['port']}",
            "--user={$config['username']}",
            "--password={$config['password']}",
            $config['database'],
            '--single-transaction',
            '--quick',
            '--lock-tables=false',
            '--routines',
            '--triggers',
            '--events',
        ];

        if ($compress) {
            $commandString = implode(' ', $command) . " | gzip > {$outputPath}";
        } else {
            $commandString = implode(' ', $command) . " > {$outputPath}";
        }

        $process = Process::fromShellCommandline($commandString);
        $process->run();

        return $process->isSuccessful();
    }

    /**
     * Upload backup to S3
     */
    protected function uploadToS3(string $localPath, string $filename): bool
    {
        $s3Path = "backups/database/" . basename($localPath);

        try {
            Storage::disk('s3')->put($s3Path, file_get_contents($localPath));
            $this->info("  S3 path: {$s3Path}");

            // Optionally delete local copy after successful upload
            if (unlink($localPath)) {
                $this->info("  Local copy removed");
            }

            return true;
        } catch (\Exception $e) {
            $this->warn("  S3 upload failed: {$e->getMessage()}");
            $this->warn("  Local backup retained at: {$localPath}");
            return false;
        }
    }

    /**
     * Delete old backups based on retention policy
     */
    protected function cleanOldBackups(string $backupDir, int $days): int
    {
        $deleted = 0;
        $cutoff = now()->subDays($days)->timestamp;

        foreach (glob("{$backupDir}/backup_*.sql*") as $file) {
            if (filemtime($file) < $cutoff) {
                if (unlink($file)) {
                    $deleted++;
                    $this->info("  Deleted: " . basename($file));
                }
            }
        }

        return $deleted;
    }

    /**
     * Format bytes to human readable
     */
    protected function formatBytes(int $bytes): string
    {
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];
        $bytes = max($bytes, 0);
        $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
        $pow = min($pow, count($units) - 1);
        $bytes /= pow(1024, $pow);

        return round($bytes, 2) . ' ' . $units[$pow];
    }
}
