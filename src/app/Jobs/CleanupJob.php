<?php

namespace App\Jobs;

use App\Models\Alert;
use App\Models\ContainerBackup;
use App\Models\ContainerHealthLog;
use App\Models\ContainerSnapshot;
use App\Models\NotificationHistory;
use App\Models\SecurityAuditLog;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

/**
 * Cleanup Job
 *
 * Performs routine cleanup tasks including old log deletion,
 * expired backup removal, and database optimization.
 */
class CleanupJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /**
     * Job timeout (seconds)
     */
    public int $timeout = 600;

    /**
     * Number of retry attempts
     */
    public int $tries = 2;

    /**
     * Backoff delay between retries (seconds)
     */
    public int $backoff = 60;

    /**
     * Cleanup type: 'all', 'logs', 'backups', 'snapshots', 'database'
     */
    protected string $cleanupType;

    /**
     * Retention period in days
     */
    protected int $retentionDays;

    /**
     * Dry run mode - don't actually delete
     */
    protected bool $dryRun;

    /**
     * Create a new job instance.
     */
    public function __construct(
        string $cleanupType = 'all',
        int $retentionDays = 30,
        bool $dryRun = false
    ) {
        $this->cleanupType = $cleanupType;
        $this->retentionDays = $retentionDays;
        $this->dryRun = $dryRun;

        // Cleanup jobs run on low-priority queue
        $this->onQueue('cleanup');
    }

    /**
     * Execute the job.
     */
    public function handle(): void
    {
        $startTime = microtime(true);
        $cutoffDate = now()->subDays($this->retentionDays);

        Log::info('Starting cleanup job', [
            'type' => $this->cleanupType,
            'retention_days' => $this->retentionDays,
            'cutoff_date' => $cutoffDate->toIso8601String(),
            'dry_run' => $this->dryRun,
        ]);

        $results = [];

        try {
            switch ($this->cleanupType) {
                case 'logs':
                    $results = $this->cleanupLogs($cutoffDate);
                    break;

                case 'backups':
                    $results = $this->cleanupBackups($cutoffDate);
                    break;

                case 'snapshots':
                    $results = $this->cleanupSnapshots($cutoffDate);
                    break;

                case 'database':
                    $results = $this->cleanupDatabase($cutoffDate);
                    break;

                case 'all':
                default:
                    $results = array_merge(
                        $this->cleanupLogs($cutoffDate),
                        $this->cleanupBackups($cutoffDate),
                        $this->cleanupSnapshots($cutoffDate),
                        $this->cleanupDatabase($cutoffDate)
                    );
                    break;
            }

            $duration = round(microtime(true) - $startTime, 2);

            Log::info('Cleanup job completed', [
                'type' => $this->cleanupType,
                'items_deleted' => array_sum($results),
                'duration' => $duration,
                'dry_run' => $this->dryRun,
            ]);

        } catch (\Exception $e) {
            Log::error('Cleanup job failed', [
                'type' => $this->cleanupType,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            throw $e;
        }
    }

    /**
     * Cleanup old log entries
     */
    protected function cleanupLogs($cutoffDate): array
    {
        $results = [];

        // Cleanup health logs
        $healthLogsCount = ContainerHealthLog::where('created_at', '<', $cutoffDate)->count();
        if (! $this->dryRun && $healthLogsCount > 0) {
            ContainerHealthLog::where('created_at', '<', $cutoffDate)->delete();
        }
        $results['health_logs'] = $healthLogsCount;

        // Cleanup security audit logs (keep longer - usually 90 days)
        $auditLogsCount = SecurityAuditLog::where('performed_at', '<', $cutoffDate)->count();
        if (! $this->dryRun && $auditLogsCount > 0) {
            SecurityAuditLog::where('performed_at', '<', $cutoffDate)->delete();
        }
        $results['audit_logs'] = $auditLogsCount;

        // Cleanup notification history
        $notificationCount = NotificationHistory::where('created_at', '<', $cutoffDate)->count();
        if (! $this->dryRun && $notificationCount > 0) {
            NotificationHistory::where('created_at', '<', $cutoffDate)->delete();
        }
        $results['notifications'] = $notificationCount;

        // Cleanup resolved old alerts
        $alertsCount = Alert::where('status', 'resolved')
            ->where('resolved_at', '<', $cutoffDate)
            ->count();
        if (! $this->dryRun && $alertsCount > 0) {
            Alert::where('status', 'resolved')
                ->where('resolved_at', '<', $cutoffDate)
                ->delete();
        }
        $results['alerts'] = $alertsCount;

        return $results;
    }

    /**
     * Cleanup old backups
     */
    protected function cleanupBackups($cutoffDate): array
    {
        $results = ['backups_deleted' => 0, 'space_freed' => 0];

        $backups = ContainerBackup::where('created_at', '<', $cutoffDate)
            ->where('retained', false)
            ->get();

        foreach ($backups as $backup) {
            if (! $this->dryRun) {
                // Delete backup file from storage
                if ($backup->storage_path && Storage::exists($backup->storage_path)) {
                    $size = Storage::size($backup->storage_path);
                    Storage::delete($backup->storage_path);
                    $results['space_freed'] += $size;
                }

                // Delete database record
                $backup->delete();
            }

            $results['backups_deleted']++;
        }

        return $results;
    }

    /**
     * Cleanup old snapshots
     */
    protected function cleanupSnapshots($cutoffDate): array
    {
        $results = ['snapshots_deleted' => 0];

        $snapshots = ContainerSnapshot::where('created_at', '<', $cutoffDate)
            ->where('is_auto', true)
            ->get();

        foreach ($snapshots as $snapshot) {
            if (! $this->dryRun) {
                // Note: Actual Proxmox snapshot deletion would be done via ProxmoxService
                // This just removes the database record
                $snapshot->delete();
            }

            $results['snapshots_deleted']++;
        }

        return $results;
    }

    /**
     * Cleanup and optimize database
     */
    protected function cleanupDatabase($cutoffDate): array
    {
        $results = [];

        // Cleanup failed jobs table
        $failedJobsCount = DB::table('failed_jobs')
            ->where('failed_at', '<', $cutoffDate)
            ->count();

        if (! $this->dryRun && $failedJobsCount > 0) {
            DB::table('failed_jobs')
                ->where('failed_at', '<', $cutoffDate)
                ->delete();
        }
        $results['failed_jobs'] = $failedJobsCount;

        // Cleanup old job batches
        $batchesCount = DB::table('job_batches')
            ->where('created_at', '<', $cutoffDate)
            ->whereNotNull('finished_at')
            ->count();

        if (! $this->dryRun && $batchesCount > 0) {
            DB::table('job_batches')
                ->where('created_at', '<', $cutoffDate)
                ->whereNotNull('finished_at')
                ->delete();
        }
        $results['job_batches'] = $batchesCount;

        // Optimize tables (only in production, not dry run)
        if (! $this->dryRun && config('app.env') === 'production') {
            try {
                DB::statement('OPTIMIZE TABLE container_health_logs');
                DB::statement('OPTIMIZE TABLE security_audit_logs');
                DB::statement('OPTIMIZE TABLE notification_histories');
                $results['tables_optimized'] = 3;
            } catch (\Exception $e) {
                Log::warning('Database optimization failed', [
                    'error' => $e->getMessage(),
                ]);
                $results['tables_optimized'] = 0;
            }
        } else {
            $results['tables_optimized'] = 0;
        }

        return $results;
    }

    /**
     * Handle job failure.
     */
    public function failed(\Throwable $exception): void
    {
        Log::critical('Cleanup job failed permanently', [
            'type' => $this->cleanupType,
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
            'cleanup',
            $this->cleanupType,
            'retention_'.$this->retentionDays.'d',
        ];
    }
}
