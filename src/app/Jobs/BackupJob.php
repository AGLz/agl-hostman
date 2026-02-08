<?php

namespace App\Jobs;

use App\Services\BackupService;
use App\Services\NotificationService;
use App\Models\ContainerBackup;
use App\Models\ProductionBackupLog;
use App\Models\LxcContainer;
use App\Models\ProxmoxServer;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Backup Job
 *
 * Executes backup operations for containers and servers.
 * Supports full, incremental, and snapshot-based backups.
 *
 * @package App\Jobs
 */
class BackupJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /**
     * Job timeout (seconds) - backups can take significant time
     */
    public int $timeout = 3600;

    /**
     * Number of retry attempts
     */
    public int $tries = 2;

    /**
     * Backoff delay between retries (seconds)
     */
    public int $backoff = 300;

    /**
     * Backup type: 'full', 'incremental', 'snapshot'
     */
    protected string $backupType;

    /**
     * Target type: 'all', 'server', 'container'
     */
    protected string $targetType;

    /**
     * Target identifier (server code or container ID)
     */
    protected ?string $targetId;

    /**
     * Retention period in days
     */
    protected int $retentionDays;

    /**
     * Whether to send notifications
     */
    protected bool $notify;

    /**
     * User who initiated the backup
     */
    protected ?int $userId;

    /**
     * Create a new job instance.
     */
    public function __construct(
        string $backupType = 'full',
        string $targetType = 'all',
        ?string $targetId = null,
        int $retentionDays = 7,
        bool $notify = true,
        ?int $userId = null
    ) {
        $this->backupType = $backupType;
        $this->targetType = $targetType;
        $this->targetId = $targetId;
        $this->retentionDays = $retentionDays;
        $this->notify = $notify;
        $this->userId = $userId;

        // Backups go on high-priority queue
        $this->onQueue('backups');
    }

    /**
     * Execute the job.
     */
    public function handle(
        BackupService $backupService,
        NotificationService $notificationService
    ): void {
        $startTime = microtime(true);
        $backupId = 'backup_' . now()->format('Ymd_His') . '_' . Str::random(8);

        Log::info('Starting backup job', [
            'backup_id' => $backupId,
            'type' => $this->backupType,
            'target_type' => $this->targetType,
            'target_id' => $this->targetId,
            'retention_days' => $this->retentionDays,
        ]);

        try {
            $results = [];
            $success = true;
            $errors = [];

            // Execute backup based on target type
            switch ($this->targetType) {
                case 'container':
                    $results = $this->backupContainer($backupService);
                    break;

                case 'server':
                    $results = $this->backupServer($backupService);
                    break;

                case 'all':
                default:
                    $results = $this->backupAll($backupService);
                    break;
            }

            // Check for errors
            foreach ($results as $result) {
                if (!$result['success']) {
                    $success = false;
                    $errors[] = $result;
                }
            }

            $duration = round(microtime(true) - $startTime, 2);

            // Create backup log
            $this->createBackupLog($backupId, $results, $success, $duration);

            // Send notification
            if ($this->notify) {
                $this->sendNotification($notificationService, $success, $results, $duration);
            }

            if ($success) {
                Log::info('Backup completed successfully', [
                    'backup_id' => $backupId,
                    'backups_created' => count($results),
                    'duration' => $duration,
                ]);
            } else {
                Log::warning('Backup completed with errors', [
                    'backup_id' => $backupId,
                    'successful' => count($results) - count($errors),
                    'failed' => count($errors),
                    'errors' => $errors,
                ]);
            }

        } catch (\Exception $e) {
            Log::error('Backup job failed', [
                'backup_id' => $backupId,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            throw $e;
        }
    }

    /**
     * Backup a single container
     */
    protected function backupContainer(BackupService $service): array
    {
        $container = LxcContainer::findOrFail($this->targetId);

        $result = $service->backupContainer($container->vmid, [
            'type' => $this->backupType,
            'retention_days' => $this->retentionDays,
        ]);

        return [$result];
    }

    /**
     * Backup all containers on a server
     */
    protected function backupServer(BackupService $service): array
    {
        $server = ProxmoxServer::where('code', $this->targetId)->firstOrFail();
        $containers = $server->containers()->where('status', 'running')->get();

        $results = [];

        foreach ($containers as $container) {
            $result = $service->backupContainer($container->vmid, [
                'type' => $this->backupType,
                'retention_days' => $this->retentionDays,
            ]);

            $results[] = $result;
        }

        return $results;
    }

    /**
     * Backup all containers across all servers
     */
    protected function backupAll(BackupService $service): array
    {
        $servers = ProxmoxServer::online()->get();
        $results = [];

        foreach ($servers as $server) {
            $containers = $server->containers()->where('status', 'running')->get();

            foreach ($containers as $container) {
                try {
                    $result = $service->backupContainer($container->vmid, [
                        'type' => $this->backupType,
                        'retention_days' => $this->retentionDays,
                    ]);

                    $results[] = $result;
                } catch (\Exception $e) {
                    $results[] = [
                        'success' => false,
                        'container' => $container->vmid,
                        'error' => $e->getMessage(),
                    ];
                }
            }
        }

        return $results;
    }

    /**
     * Create backup log entry
     */
    protected function createBackupLog(string $backupId, array $results, bool $success, float $duration): void
    {
        $totalSize = collect($results)->sum(fn($r) => $r['size'] ?? 0);

        ProductionBackupLog::create([
            'backup_id' => $backupId,
            'backup_type' => $this->backupType,
            'target_type' => $this->targetType,
            'target_id' => $this->targetId,
            'status' => $success ? 'completed' : 'partial',
            'backups_created' => count($results),
            'total_size' => $totalSize,
            'duration' => $duration,
            'initiated_by' => $this->userId,
            'started_at' => now()->subSeconds((int)$duration),
            'completed_at' => now(),
        ]);
    }

    /**
     * Send backup notification
     */
    protected function sendNotification(
        NotificationService $service,
        bool $success,
        array $results,
        float $duration
    ): void {
        $data = [
            'backup_type' => $this->backupType,
            'target_type' => $this->targetType,
            'success' => $success,
            'backups_count' => count($results),
            'duration' => $duration,
            'size' => collect($results)->sum(fn($r) => $r['size'] ?? 0),
        ];

        if ($success) {
            $service->sendNotification('backup_success', $data);
        } else {
            $service->sendNotification('backup_failed', $data);
        }
    }

    /**
     * Handle job failure.
     */
    public function failed(\Throwable $exception): void
    {
        Log::critical('Backup job failed permanently', [
            'type' => $this->backupType,
            'target' => $this->targetType . ':' . $this->targetId,
            'error' => $exception->getMessage(),
            'trace' => $exception->getTraceAsString(),
        ]);
    }

    /**
     * Get the tags that should be assigned to the job.
     */
    public function tags(): array
    {
        return [
            'backup',
            $this->backupType,
            $this->targetType,
            $this->targetId ?? 'all',
        ];
    }
}
