<?php

declare(strict_types=1);

namespace App\Listeners\Archon;

use App\Events\TaskCreated;
use App\Events\TaskUpdated;
use App\Jobs\Archon\PushToArchonJob;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Support\Facades\Log;

/**
 * Listen for Task events and sync to Archon
 */
class SyncTaskToArchon implements ShouldQueue
{
    public function handle(TaskCreated|TaskUpdated $event): void
    {
        if (! config('archon.sync_enabled')) {
            return;
        }

        $task = $event->task;
        $action = $event instanceof TaskCreated ? 'create' : 'update';

        Log::info('Syncing task to Archon', [
            'task_id' => $task->id,
            'action' => $action,
        ]);

        PushToArchonJob::dispatch('task', $task->id, $action);
    }
}
