<?php

declare(strict_types=1);

namespace App\Listeners\Archon;

use App\Events\SprintCreated;
use App\Events\SprintUpdated;
use App\Jobs\Archon\PushToArchonJob;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Support\Facades\Log;

/**
 * Listen for Sprint events and sync to Archon
 */
class SyncProjectToArchon implements ShouldQueue
{
    public function handle(SprintCreated|SprintUpdated $event): void
    {
        if (! config('archon.sync_enabled')) {
            return;
        }

        $sprint = $event->sprint;
        $action = $event instanceof SprintCreated ? 'create' : 'update';

        Log::info('Syncing project to Archon', [
            'sprint_id' => $sprint->id,
            'action' => $action,
        ]);

        PushToArchonJob::dispatch('project', $sprint->id, $action);
    }
}
