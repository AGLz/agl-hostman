<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Jobs\Archon\SyncArchonProjectsJob;
use App\Jobs\Archon\SyncArchonTasksJob;
use App\Services\ArchonMcpService;
use Illuminate\Console\Command;

/**
 * Manually trigger Archon MCP sync
 */
class ArchonSyncCommand extends Command
{
    protected $signature = 'archon:sync
                          {--type=all : Type of sync (projects, tasks, all)}
                          {--project= : Specific project ID to sync}
                          {--task= : Specific task ID to sync}
                          {--async : Run sync in background queue}';

    protected $description = 'Sync data between Archon MCP and local database';

    public function handle(ArchonMcpService $archon): int
    {
        if (! config('archon.enabled')) {
            $this->error('Archon integration is disabled. Enable it in config/archon.php');

            return self::FAILURE;
        }

        // Test connection first
        $this->info('Testing Archon MCP connection...');
        if (! $archon->ping()) {
            $this->error('Failed to connect to Archon MCP server');
            $this->error('URL: '.config('archon.mcp_url'));

            return self::FAILURE;
        }
        $this->info('✓ Connected to Archon MCP');

        $type = $this->option('type');
        $async = $this->option('async');
        $projectId = $this->option('project');
        $taskId = $this->option('task');

        if ($async) {
            return $this->syncAsync($type, $projectId, $taskId);
        }

        return $this->syncNow($type, $projectId, $taskId, $archon);
    }

    private function syncAsync(string $type, ?string $projectId, ?string $taskId): int
    {
        $this->info('Dispatching sync jobs to queue...');

        if ($type === 'all' || $type === 'projects') {
            SyncArchonProjectsJob::dispatch($projectId);
            $this->info('✓ Projects sync job dispatched');
        }

        if ($type === 'all' || $type === 'tasks') {
            SyncArchonTasksJob::dispatch($projectId, $taskId);
            $this->info('✓ Tasks sync job dispatched');
        }

        $this->info('Jobs dispatched. Check queue workers for progress.');

        return self::SUCCESS;
    }

    private function syncNow(string $type, ?string $projectId, ?string $taskId, ArchonMcpService $archon): int
    {
        $startTime = microtime(true);

        if ($type === 'all' || $type === 'projects') {
            $this->info('Syncing projects...');
            $this->syncProjects($archon, $projectId);
        }

        if ($type === 'all' || $type === 'tasks') {
            $this->info('Syncing tasks...');
            $this->syncTasks($archon, $projectId, $taskId);
        }

        $duration = round((microtime(true) - $startTime) * 1000, 2);
        $this->info("✓ Sync completed in {$duration}ms");

        return self::SUCCESS;
    }

    private function syncProjects(ArchonMcpService $archon, ?string $projectId): void
    {
        try {
            if ($projectId) {
                $project = $archon->getProject($projectId);
                $this->line("  - {$project->title}");
                $count = 1;
            } else {
                $projects = $archon->getProjects();
                foreach ($projects as $project) {
                    $this->line("  - {$project->title}");
                }
                $count = $projects->count();
            }

            $this->info("  ✓ Synced {$count} project(s)");

        } catch (\Exception $e) {
            $this->error("  ✗ Failed: {$e->getMessage()}");
        }
    }

    private function syncTasks(ArchonMcpService $archon, ?string $projectId, ?string $taskId): void
    {
        try {
            if ($taskId) {
                $task = $archon->getTask($taskId);
                $this->line("  - {$task->title} [{$task->status}]");
                $count = 1;
            } elseif ($projectId) {
                $tasks = $archon->getTasks(['project_id' => $projectId]);
                foreach ($tasks as $task) {
                    $this->line("  - {$task->title} [{$task->status}]");
                }
                $count = $tasks->count();
            } else {
                $tasks = $archon->getTasks();
                foreach ($tasks as $task) {
                    $this->line("  - {$task->title} [{$task->status}]");
                }
                $count = $tasks->count();
            }

            $this->info("  ✓ Synced {$count} task(s)");

        } catch (\Exception $e) {
            $this->error("  ✗ Failed: {$e->getMessage()}");
        }
    }
}
