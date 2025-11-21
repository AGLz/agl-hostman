<?php

namespace App\Services;

use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Artisan;
use Carbon\Carbon;
use ZipArchive;

class BackupService
{
    protected array $backupConfig;
    protected string $backupPath;
    
    public function __construct()
    {
        $this->backupConfig = config('backup', [
            'databases' => ['mysql'],
            'paths' => ['app', 'config', 'database', 'resources'],
            'exclude' => ['node_modules', 'vendor', '.git', 'storage/logs'],
            'retention' => 30, // days
            'compression' => true,
            'encrypt' => true,
        ]);
        
        $this->backupPath = storage_path('backups');
        
        if (!is_dir($this->backupPath)) {
            mkdir($this->backupPath, 0755, true);
        }
    }

    /**
     * Perform complete backup
     */
    public function performBackup(string $type = 'full'): array
    {
        $timestamp = Carbon::now()->format('Y-m-d_H-i-s');
        $backupName = "backup_{$type}_{$timestamp}";
        $tempPath = "{$this->backupPath}/temp_{$backupName}";
        
        try {
            // Create temp directory
            mkdir($tempPath, 0755, true);
            
            $results = [
                'name' => $backupName,
                'type' => $type,
                'timestamp' => $timestamp,
                'components' => [],
            ];
            
            // Backup databases
            if ($type === 'full' || $type === 'database') {
                $dbResult = $this->backupDatabases($tempPath);
                $results['components']['databases'] = $dbResult;
            }
            
            // Backup files
            if ($type === 'full' || $type === 'files') {
                $filesResult = $this->backupFiles($tempPath);
                $results['components']['files'] = $filesResult;
            }
            
            // Backup environment
            if ($type === 'full' || $type === 'config') {
                $envResult = $this->backupEnvironment($tempPath);
                $results['components']['environment'] = $envResult;
            }
            
            // Create archive
            if ($this->backupConfig['compression']) {
                $archivePath = $this->createArchive($tempPath, $backupName);
                $results['archive'] = $archivePath;
                $results['size'] = filesize($archivePath);
                
                // Encrypt if enabled
                if ($this->backupConfig['encrypt']) {
                    $encryptedPath = $this->encryptBackup($archivePath);
                    $results['encrypted'] = true;
                    $results['archive'] = $encryptedPath;
                    unlink($archivePath); // Remove unencrypted
                }
            }
            
            // Upload to remote storage
            if (config('backup.remote_storage')) {
                $uploadResult = $this->uploadToRemote($results['archive']);
                $results['remote'] = $uploadResult;
            }
            
            // Clean temp directory
            $this->removeDirectory($tempPath);
            
            // Clean old backups
            $this->cleanOldBackups();
            
            // Store backup metadata
            $this->storeBackupMetadata($results);
            
            Log::info('Backup completed successfully', $results);
            
            return [
                'success' => true,
                'backup' => $results,
            ];
            
        } catch (\Exception $e) {
            Log::error('Backup failed', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);
            
            // Cleanup on failure
            if (is_dir($tempPath)) {
                $this->removeDirectory($tempPath);
            }
            
            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Backup all databases
     */
    protected function backupDatabases(string $path): array
    {
        $results = [];
        
        foreach ($this->backupConfig['databases'] as $connection) {
            $config = config("database.connections.{$connection}");
            
            if ($connection === 'mysql') {
                $filename = "{$path}/database_{$connection}.sql";
                $command = sprintf(
                    'mysqldump --host=%s --port=%s --user=%s --password=%s %s > %s',
                    escapeshellarg($config['host']),
                    escapeshellarg($config['port']),
                    escapeshellarg($config['username']),
                    escapeshellarg($config['password']),
                    escapeshellarg($config['database']),
                    escapeshellarg($filename)
                );
                
                exec($command, $output, $returnCode);
                
                if ($returnCode === 0) {
                    $results[$connection] = [
                        'success' => true,
                        'file' => basename($filename),
                        'size' => filesize($filename),
                    ];
                } else {
                    $results[$connection] = [
                        'success' => false,
                        'error' => 'Database dump failed',
                    ];
                }
            }
            
            // Add support for other database types
            // PostgreSQL, SQLite, etc.
        }
        
        // Backup Redis if configured
        if (config('database.redis.default')) {
            $redisBackup = $this->backupRedis($path);
            $results['redis'] = $redisBackup;
        }
        
        return $results;
    }

    /**
     * Backup Redis data
     */
    protected function backupRedis(string $path): array
    {
        try {
            // Use Redis BGSAVE
            $redis = app('redis');
            $redis->bgsave();
            
            // Wait for save to complete
            sleep(2);
            
            // Copy dump file
            $rdbPath = '/var/lib/redis/dump.rdb';
            if (file_exists($rdbPath)) {
                copy($rdbPath, "{$path}/redis_dump.rdb");
                return [
                    'success' => true,
                    'file' => 'redis_dump.rdb',
                    'size' => filesize("{$path}/redis_dump.rdb"),
                ];
            }
            
            return ['success' => false, 'error' => 'Redis dump file not found'];
            
        } catch (\Exception $e) {
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    /**
     * Backup application files
     */
    protected function backupFiles(string $path): array
    {
        $results = [];
        $filesPath = "{$path}/files";
        mkdir($filesPath, 0755, true);
        
        foreach ($this->backupConfig['paths'] as $dir) {
            $sourcePath = base_path($dir);
            if (is_dir($sourcePath)) {
                $targetPath = "{$filesPath}/{$dir}";
                $this->copyDirectory($sourcePath, $targetPath, $this->backupConfig['exclude']);
                $results[$dir] = [
                    'success' => true,
                    'files' => $this->countFiles($targetPath),
                ];
            }
        }
        
        return $results;
    }

    /**
     * Backup environment and configuration
     */
    protected function backupEnvironment(string $path): array
    {
        $envPath = "{$path}/environment";
        mkdir($envPath, 0755, true);
        
        // Copy .env file
        copy(base_path('.env'), "{$envPath}/.env");
        
        // Export current configuration
        $config = config()->all();
        file_put_contents(
            "{$envPath}/config.json", 
            json_encode($config, JSON_PRETTY_PRINT)
        );
        
        // Store application metadata
        $metadata = [
            'app_version' => config('app.version', '1.0.0'),
            'laravel_version' => app()->version(),
            'php_version' => PHP_VERSION,
            'backup_date' => Carbon::now()->toIso8601String(),
            'environment' => app()->environment(),
        ];
        
        file_put_contents(
            "{$envPath}/metadata.json",
            json_encode($metadata, JSON_PRETTY_PRINT)
        );
        
        return [
            'success' => true,
            'files' => ['.env', 'config.json', 'metadata.json'],
        ];
    }

    /**
     * Create compressed archive
     */
    protected function createArchive(string $sourcePath, string $name): string
    {
        $archivePath = "{$this->backupPath}/{$name}.zip";
        
        $zip = new ZipArchive();
        if ($zip->open($archivePath, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== true) {
            throw new \Exception('Cannot create zip archive');
        }
        
        $this->addDirectoryToZip($zip, $sourcePath, '');
        $zip->close();
        
        return $archivePath;
    }

    /**
     * Add directory to zip archive recursively
     */
    protected function addDirectoryToZip(ZipArchive $zip, string $source, string $target): void
    {
        $iterator = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($source, \RecursiveDirectoryIterator::SKIP_DOTS),
            \RecursiveIteratorIterator::SELF_FIRST
        );
        
        foreach ($iterator as $file) {
            $filePath = $file->getRealPath();
            $relativePath = substr($filePath, strlen($source) + 1);
            
            if ($file->isDir()) {
                $zip->addEmptyDir($relativePath);
            } else {
                $zip->addFile($filePath, $relativePath);
            }
        }
    }

    /**
     * Encrypt backup archive
     */
    protected function encryptBackup(string $archivePath): string
    {
        $encryptedPath = "{$archivePath}.enc";
        $password = config('backup.encryption_password', env('BACKUP_PASSWORD'));
        
        if (!$password) {
            throw new \Exception('Backup encryption password not configured');
        }
        
        $command = sprintf(
            'openssl enc -aes-256-cbc -salt -in %s -out %s -pass pass:%s',
            escapeshellarg($archivePath),
            escapeshellarg($encryptedPath),
            escapeshellarg($password)
        );
        
        exec($command, $output, $returnCode);
        
        if ($returnCode !== 0) {
            throw new \Exception('Encryption failed');
        }
        
        return $encryptedPath;
    }

    /**
     * Upload backup to remote storage
     */
    protected function uploadToRemote(string $filePath): array
    {
        $disk = Storage::disk(config('backup.remote_disk', 's3'));
        $remotePath = 'backups/' . basename($filePath);
        
        try {
            $disk->put($remotePath, file_get_contents($filePath));
            
            return [
                'success' => true,
                'disk' => config('backup.remote_disk'),
                'path' => $remotePath,
                'url' => $disk->url($remotePath),
            ];
        } catch (\Exception $e) {
            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Clean old backups based on retention policy
     */
    protected function cleanOldBackups(): void
    {
        $retentionDays = $this->backupConfig['retention'];
        $cutoffDate = Carbon::now()->subDays($retentionDays);
        
        $files = glob("{$this->backupPath}/backup_*.{zip,enc}", GLOB_BRACE);
        
        foreach ($files as $file) {
            if (filemtime($file) < $cutoffDate->timestamp) {
                unlink($file);
                Log::info('Deleted old backup', ['file' => basename($file)]);
            }
        }
    }

    /**
     * Store backup metadata in database
     */
    protected function storeBackupMetadata(array $metadata): void
    {
        DB::table('backups')->insert([
            'name' => $metadata['name'],
            'type' => $metadata['type'],
            'size' => $metadata['size'] ?? 0,
            'path' => $metadata['archive'] ?? null,
            'remote_path' => $metadata['remote']['path'] ?? null,
            'metadata' => json_encode($metadata),
            'created_at' => now(),
        ]);
    }

    /**
     * Restore from backup
     */
    public function restoreFromBackup(string $backupName): array
    {
        // Implementation for restore functionality
        // This would be the inverse of backup operations
        
        return [
            'success' => true,
            'message' => 'Restore functionality to be implemented',
        ];
    }

    /**
     * List available backups
     */
    public function listBackups(): array
    {
        return DB::table('backups')
            ->orderBy('created_at', 'desc')
            ->limit(50)
            ->get()
            ->toArray();
    }

    /**
     * Helper: Copy directory recursively
     */
    protected function copyDirectory(string $source, string $dest, array $exclude = []): void
    {
        if (!is_dir($dest)) {
            mkdir($dest, 0755, true);
        }
        
        $iterator = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($source, \RecursiveDirectoryIterator::SKIP_DOTS),
            \RecursiveIteratorIterator::SELF_FIRST
        );
        
        foreach ($iterator as $file) {
            $filePath = $file->getRealPath();
            $relativePath = substr($filePath, strlen($source) + 1);
            
            // Check exclusions
            foreach ($exclude as $pattern) {
                if (strpos($relativePath, $pattern) !== false) {
                    continue 2;
                }
            }
            
            $targetPath = "{$dest}/{$relativePath}";
            
            if ($file->isDir()) {
                if (!is_dir($targetPath)) {
                    mkdir($targetPath, 0755, true);
                }
            } else {
                copy($filePath, $targetPath);
            }
        }
    }

    /**
     * Helper: Remove directory recursively
     */
    protected function removeDirectory(string $path): void
    {
        if (!is_dir($path)) {
            return;
        }
        
        $files = array_diff(scandir($path), ['.', '..']);
        
        foreach ($files as $file) {
            $filePath = "{$path}/{$file}";
            if (is_dir($filePath)) {
                $this->removeDirectory($filePath);
            } else {
                unlink($filePath);
            }
        }
        
        rmdir($path);
    }

    /**
     * Helper: Count files in directory
     */
    protected function countFiles(string $path): int
    {
        $count = 0;
        $iterator = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($path, \RecursiveDirectoryIterator::SKIP_DOTS)
        );
        
        foreach ($iterator as $file) {
            if ($file->isFile()) {
                $count++;
            }
        }
        
        return $count;
    }
}