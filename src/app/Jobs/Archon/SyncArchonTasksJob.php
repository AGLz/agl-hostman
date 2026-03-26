<?php

declare(strict_types=1);

namespace App\Jobs\Archon;

use App\Models\Sprint;
use App\Models\Task;
use App\Services\ArchonMcpService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Sync tasks from Archon MCP to local database
 */
class SyncArchonTasksJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;

    public int $timeout = 120;

    public function __construct(
        private readonly ?string $projectId = null,
        private readonly ?string $taskId = null
    ) {}

    public function handle(ArchonMcpService $archon): void
    {
        if (! config('archon.sync_enabled')) {
            Log::info('Archon sync disabled, skipping task sync');

            return;
        }

        try {
            $startTime = microtime(true);

            if ($this->taskId) {
                $this->syncSingleTask($archon, $this->taskId);
            } elseif ($this->projectId) {
                $this->syncProjectTasks($archon, $this->projectId);
            } else {
                $this->syncAllTasks($archon);
            }

            $duration = round((microtime(true) - $startTime) * 1000, 2);

            Log::info('Archon tasks synced successfully', [
                'duration_ms' => $duration,
                'project_id' => $this->projectId,
                'task_id' => $this->taskId,
            ]);

        } catch (\Exception $e) {
            Log::error('Archon task sync failed', [
                'error' => $e->getMessage(),
                'project_id' => $this->projectId,
                'task_id' => $this->taskId,
            ]);
            throw $e;
        }
    }

    private function syncSingleTask(ArchonMcpService $archon, string $taskId): void
    {
        $taskDto = $archon->getTask($taskId);
        $this->upsertTask($taskDto);

        Log::info('Single task synced', ['task_id' => $taskId]);
    }

    private function syncProjectTasks(ArchonMcpService $archon, string $projectId): void
    {
        $tasks = $archon->getTasks(['project_id' => $projectId]);
        $syncedCount = 0;

        DB::transaction(function () use ($tasks, &$syncedCount) {
            foreach ($tasks as $taskDto) {
                $this->upsertTask($taskDto);
                $syncedCount++;
            }
        });

        Log::info('Project tasks synced', [
            'project_id' => $projectId,
            'count' => $syncedCount,
        ]);
    }

    private function syncAllTasks(ArchonMcpService $archon): void
    {
        $tasks = $archon->getTasks();
        $syncedCount = 0;

        DB::transaction(function () use ($tasks, &$syncedCount) {
            foreach ($tasks as $taskDto) {
                $this->upsertTask($taskDto);
                $syncedCount++;
            }
        });

        Log::info('All tasks synced', ['count' => $syncedCount]);
    }

    private function upsertTask($taskDto): void
    {
        // Find Sprint by Archon project ID
        $sprint = Sprint::where('archon_project_id', $taskDto->projectId)->first();

        if (! $sprint) {
            Log::warning('Sprint not found for Archon project', [
                'archon_project_id' => $taskDto->projectId,
            ]);

            return;
        }

        Task::updateOrCreate(
            ['archon_task_id' => $taskDto->id],
            [
                'sprint_id' => $sprint->id,
                'title' => $taskDto->title,
                'description' => $taskDto->description,
                'status' => $this->mapArchonStatus($taskDto->status),
                'assignee' => $taskDto->assignee,
                'priority' => $taskDto->taskOrder ?? 0,
                'archon_synced_at' => now(),
            ]
        );
    }

    private function mapArchonStatus(string $archonStatus): string
    {
        // Map Archon status to local status
        return match ($archonStatus) {
            'todo' => 'pending',
            'doing' => 'in_progress',
            'review' => 'in_review',
            'done' => 'completed',
            default => 'pending',
        };
    }
}
