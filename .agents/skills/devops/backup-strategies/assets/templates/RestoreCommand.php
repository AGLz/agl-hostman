<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\DB;
use Symfony\Component\Process\Process;
use Carbon\Carbon;

class RestoreDatabase extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'db:restore
                            {backup : Backup file name or S3 path}
                            {--force : Skip confirmation prompt}
                            {--local : Use local backup instead of downloading from S3}
                            {--skip-migrations : Skip running migrations after restore}
                            {--seed : Run seeders after restore}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Restore database from backup file';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $backup = $this->argument('backup');
        $force = $this->option('force');
        $local = $this->option('local');
        $skipMigrations = $this->option('skip-migrations');
        $seed = $this->option('seed');

        $this->info("=== Database Restore ===");
        $this->info("Backup: {$backup}");
        $this->warn("This will replace all existing data!");
        $this->newLine();

        // Confirm restoration
        if (!$force && !$this->confirm('Proceed with restore?')) {
            $this->info('Restore cancelled');
            return 0;
        }

        // Get local backup path
        $localPath = $this->getLocalBackupPath($backup, $local);

        if (!$localPath || !file_exists($localPath)) {
            $this->error("Backup file not found: {$localPath}");
            return 1;
        }

        $this->info("Local backup: {$localPath}");
        $this->info("File size: " . $this->formatBytes(filesize($localPath)));
        $this->newLine();

        // Enable maintenance mode
        $this->task('Enabling maintenance mode', function () {
            $this->callSilent('down', ['--render' => 'maintenance.html']);
            return true;
        });

        $restoreSuccess = false;

        try {
            // Get database info
            $dbHost = config('database.connections.mysql.host');
            $dbPort = config('database.connections.mysql.port');
            $dbUser = config('database.connections.mysql.username');
            $dbPass = config('database.connections.mysql.password');
            $dbName = config('database.connections.mysql.database');

            $this->task('Dropping existing database', function () use ($dbName, $dbUser, $dbPass, $dbHost) {
                $process = new Process([
                    'mysql',
                    "-h{$dbHost}",
                    "-u{$dbUser}",
                    "-p{$dbPass}",
                    '-e',
                    "DROP DATABASE IF EXISTS `{$dbName}`"
                ]);
                $process->run();
                return $process->isSuccessful();
            });

            $this->task('Creating fresh database', function () use ($dbName, $dbUser, $dbPass, $dbHost) {
                $process = new Process([
                    'mysql',
                    "-h{$dbHost}",
                    "-u{$dbUser}",
                    "-p{$dbPass}",
                    '-e',
                    "CREATE DATABASE `{$dbName}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
                ]);
                $process->run();
                return $process->isSuccessful();
            });

            $this->task('Restoring from backup', function () use ($localPath, $dbHost, $dbUser, $dbPass, $dbName) {
                return $this->restoreBackup($localPath, $dbHost, $dbUser, $dbPass, $dbName);
            });

            // Run migrations if not skipped
            if (!$skipMigrations) {
                $this->task('Running migrations', function () {
                    $this->callSilent('migrate', ['--force' => true]);
                    return true;
                });
            }

            // Run seeders if requested
            if ($seed) {
                $this->task('Running seeders', function () {
                    $this->callSilent('db:seed', ['--force' => true]);
                    return true;
                });
            }

            // Clear and cache configs
            $this->task('Clearing cache', function () {
                $this->callSilent('cache:clear');
                $this->callSilent('config:clear');
                $this->callSilent('route:clear');
                $this->callSilent('view:clear');
                return true;
            });

            $restoreSuccess = true;

        } catch (\Exception $e) {
            $this->error("Restore failed: {$e->getMessage()}");
            $restoreSuccess = false;
        } finally {
            // Disable maintenance mode
            $this->task('Disabling maintenance mode', function () {
                $this->callSilent('up');
                return true;
            });
        }

        $this->newLine();

        if ($restoreSuccess) {
            $this->info('✓ Database restored successfully');
            return 0;
        } else {
            $this->error('✗ Database restore failed');
            $this->warn('Maintenance mode has been disabled');
            $this->warn('Please check logs and try again');
            return 1;
        }
    }

    /**
     * Get local path for backup (download if from S3)
     */
    protected function getLocalBackupPath(string $backup, bool $local): ?string
    {
        $backupDir = storage_path('app/backups');

        // If already a local file path
        if ($local || file_exists($backup)) {
            return $backup;
        }

        // Download from S3
        if (str_starts_with($backup, 'backups/') || str_contains($backup, '/')) {
            $this->info("Downloading backup from S3...");

            $filename = basename($backup);
            $localPath = "{$backupDir}/{$filename}";

            if (!Storage::disk('s3')->exists($backup)) {
                $this->error("Backup not found on S3: {$backup}");
                return null;
            }

            // Ensure directory exists
            if (!is_dir($backupDir)) {
                mkdir($backupDir, 0755, true);
            }

            Storage::disk('s3')->download($backup, $localPath);
            $this->info("✓ Downloaded to: {$localPath}");

            return $localPath;
        }

        // Assume local file in backups directory
        $localPath = "{$backupDir}/{$backup}";
        return file_exists($localPath) ? $localPath : null;
    }

    /**
     * Restore backup to database
     */
    protected function restoreBackup(string $backupPath, string $host, string $user, string $pass, string $database): bool
    {
        $isCompressed = str_ends_with($backupPath, '.gz');

        if ($isCompressed) {
            $command = "gunzip < {$backupPath} | mysql -h{$host} -u{$user} -p{$pass} {$database}";
        } else {
            $command = "mysql -h{$host} -u{$user} -p{$pass} {$database} < {$backupPath}";
        }

        $process = Process::fromShellCommandline($command);
        $process->setTimeout(3600); // 1 hour timeout
        $process->run(function ($type, $output) {
            if ($type === Process::ERR) {
                $this->warn($output);
            }
        });

        return $process->isSuccessful();
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
