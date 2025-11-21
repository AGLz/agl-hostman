<?php

declare(strict_types=1);

namespace App\Jobs\Archon;

use App\Models\Sprint;
use App\Services\ArchonMcpService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Sync projects from Archon MCP to local database
 */
class SyncArchonProjectsJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;
    public int $timeout = 120;

    public function __construct(
        private readonly ?string $projectId = null
    ) {}

    public function handle(ArchonMcpService $archon): void
    {
        if (!config('archon.sync_enabled')) {
            Log::info('Archon sync disabled, skipping project sync');
            return;
        }

        try {
            $startTime = microtime(true);

            if ($this->projectId) {
                $this->syncSingleProject($archon, $this->projectId);
            } else {
                $this->syncAllProjects($archon);
            }

            $duration = round((microtime(true) - $startTime) * 1000, 2);

            Log::info('Archon projects synced successfully', [
                'duration_ms' => $duration,
                'project_id' => $this->projectId,
            ]);

        } catch (\Exception $e) {
            Log::error('Archon project sync failed', [
                'error' => $e->getMessage(),
                'project_id' => $this->projectId,
            ]);
            throw $e;
        }
    }

    private function syncSingleProject(ArchonMcpService $archon, string $projectId): void
    {
        $projectDto = $archon->getProject($projectId);

        DB::transaction(function () use ($projectDto) {
            // Map Archon project to Laravel Sprint model
            Sprint::updateOrCreate(
                ['archon_project_id' => $projectDto->id],
                [
                    'name' => $projectDto->title,
                    'description' => $projectDto->description,
                    'github_repo' => $projectDto->githubRepo,
                    'archon_synced_at' => now(),
                    'start_date' => $projectDto->createdAt,
                    'status' => 'active',
                ]
            );
        });

        Log::info('Single project synced', ['project_id' => $projectId]);
    }

    private function syncAllProjects(ArchonMcpService $archon): void
    {
        $projects = $archon->getProjects();
        $syncedCount = 0;

        DB::transaction(function () use ($projects, &$syncedCount) {
            foreach ($projects as $projectDto) {
                Sprint::updateOrCreate(
                    ['archon_project_id' => $projectDto->id],
                    [
                        'name' => $projectDto->title,
                        'description' => $projectDto->description,
                        'github_repo' => $projectDto->githubRepo,
                        'archon_synced_at' => now(),
                        'start_date' => $projectDto->createdAt,
                        'status' => 'active',
                    ]
                );
                $syncedCount++;
            }
        });

        Log::info('All projects synced', ['count' => $syncedCount]);
    }
}
