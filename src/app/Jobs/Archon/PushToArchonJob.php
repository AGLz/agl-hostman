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
use Illuminate\Support\Facades\Log;

/**
 * Push local changes to Archon MCP
 */
class PushToArchonJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;

    public int $timeout = 60;

    public function __construct(
        private readonly string $entityType, // 'project' or 'task'
        private readonly int $entityId,
        private readonly string $action = 'update' // 'create', 'update', 'delete'
    ) {}

    public function handle(ArchonMcpService $archon): void
    {
        if (! config('archon.sync_enabled')) {
            Log::info('Archon sync disabled, skipping push');

            return;
        }

        try {
            match ($this->entityType) {
                'project' => $this->pushProject($archon),
                'task' => $this->pushTask($archon),
                default => throw new \InvalidArgumentException("Invalid entity type: {$this->entityType}"),
            };

            Log::info('Pushed to Archon successfully', [
                'entity_type' => $this->entityType,
                'entity_id' => $this->entityId,
                'action' => $this->action,
            ]);

        } catch (\Exception $e) {
            Log::error('Push to Archon failed', [
                'entity_type' => $this->entityType,
                'entity_id' => $this->entityId,
                'action' => $this->action,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    private function pushProject(ArchonMcpService $archon): void
    {
        $sprint = Sprint::findOrFail($this->entityId);

        if ($this->action === 'delete') {
            if ($sprint->archon_project_id) {
                $archon->deleteProject($sprint->archon_project_id);
                $sprint->update(['archon_project_id' => null]);
            }

            return;
        }

        if ($sprint->archon_project_id && $this->action === 'update') {
            // Update existing Archon project
            $projectDto = $archon->updateProject($sprint->archon_project_id, [
                'title' => $sprint->name,
                'description' => $sprint->description,
                'github_repo' => $sprint->github_repo,
            ]);
        } else {
            // Create new Archon project
            $projectDto = $archon->createProject(
                $sprint->name,
                $sprint->description,
                $sprint->github_repo
            );

            $sprint->update([
                'archon_project_id' => $projectDto->id,
                'archon_synced_at' => now(),
            ]);
        }
    }

    private function pushTask(ArchonMcpService $archon): void
    {
        $task = Task::with('sprint')->findOrFail($this->entityId);

        if (! $task->sprint?->archon_project_id) {
            Log::warning('Cannot push task: Sprint has no Archon project ID', [
                'task_id' => $this->entityId,
                'sprint_id' => $task->sprint_id,
            ]);

            return;
        }

        if ($this->action === 'delete') {
            if ($task->archon_task_id) {
                $archon->deleteTask($task->archon_task_id);
                $task->update(['archon_task_id' => null]);
            }

            return;
        }

        $archonStatus = $this->mapLocalStatus($task->status);

        if ($task->archon_task_id && $this->action === 'update') {
            // Update existing Archon task
            $taskDto = $archon->updateTaskStatus($task->archon_task_id, $archonStatus);
        } else {
            // Create new Archon task
            $taskDto = $archon->createTask(
                $task->sprint->archon_project_id,
                $task->title,
                [
                    'description' => $task->description,
                    'status' => $archonStatus,
                    'assignee' => $task->assignee ?? 'User',
                    'task_order' => $task->priority ?? 0,
                ]
            );

            $task->update([
                'archon_task_id' => $taskDto->id,
                'archon_synced_at' => now(),
            ]);
        }
    }

    private function mapLocalStatus(string $localStatus): string
    {
        // Map local status to Archon status
        return match ($localStatus) {
            'pending' => 'todo',
            'in_progress' => 'doing',
            'in_review' => 'review',
            'completed' => 'done',
            default => 'todo',
        };
    }
}
