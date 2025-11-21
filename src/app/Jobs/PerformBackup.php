<?php

namespace App\Jobs;

use App\Services\BackupService;
use App\Services\N8NService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

class PerformBackup implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected string $backupType;
    protected bool $notifyOnComplete;
    protected ?string $notificationEmail;

    /**
     * Create a new job instance.
     */
    public function __construct(
        string $backupType = 'full',
        bool $notifyOnComplete = true,
        ?string $notificationEmail = null
    ) {
        $this->backupType = $backupType;
        $this->notifyOnComplete = $notifyOnComplete;
        $this->notificationEmail = $notificationEmail ?? config('backup.notification_email');
    }

    /**
     * Execute the job.
     */
    public function handle(BackupService $backupService, N8NService $n8nService): void
    {
        Log::info('Starting backup job', [
            'type' => $this->backupType,
            'notify' => $this->notifyOnComplete,
        ]);

        $startTime = microtime(true);
        
        // Perform backup
        $result = $backupService->performBackup($this->backupType);
        
        $duration = round(microtime(true) - $startTime, 2);
        
        if ($result['success']) {
            Log::info('Backup completed successfully', [
                'backup' => $result['backup'],
                'duration' => $duration,
            ]);
            
            // Trigger N8N workflow for successful backup
            $n8nService->executeWorkflow('backup-success', [
                'backup_name' => $result['backup']['name'],
                'backup_size' => $result['backup']['size'] ?? 0,
                'duration' => $duration,
                'components' => $result['backup']['components'],
            ]);
            
            // Send notification if configured
            if ($this->notifyOnComplete && $this->notificationEmail) {
                $this->sendNotification($result['backup'], $duration, true);
            }
        } else {
            Log::error('Backup failed', [
                'error' => $result['error'],
                'duration' => $duration,
            ]);
            
            // Trigger N8N workflow for failed backup
            $n8nService->executeWorkflow('backup-failure', [
                'error' => $result['error'],
                'type' => $this->backupType,
                'duration' => $duration,
            ]);
            
            // Send failure notification
            if ($this->notifyOnComplete && $this->notificationEmail) {
                $this->sendNotification(['error' => $result['error']], $duration, false);
            }
        }
    }

    /**
     * Send email notification
     */
    protected function sendNotification(array $backup, float $duration, bool $success): void
    {
        $subject = $success 
            ? "Backup Completed Successfully - {$backup['name']}"
            : "Backup Failed - {$this->backupType}";
        
        $data = [
            'success' => $success,
            'backup' => $backup,
            'duration' => $duration,
            'type' => $this->backupType,
        ];
        
        // Simple email notification
        // In production, use a proper Mailable class
        try {
            Mail::raw(
                view('emails.backup-notification', $data)->render(),
                function ($message) use ($subject) {
                    $message->to($this->notificationEmail)
                            ->subject($subject);
                }
            );
        } catch (\Exception $e) {
            Log::error('Failed to send backup notification', [
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Get the tags that should be assigned to this job.
     */
    public function tags(): array
    {
        return ['backup', $this->backupType];
    }

    /**
     * The job failed to process.
     */
    public function failed(\Throwable $exception): void
    {
        Log::error('Backup job failed with exception', [
            'type' => $this->backupType,
            'error' => $exception->getMessage(),
            'trace' => $exception->getTraceAsString(),
        ]);
    }
}