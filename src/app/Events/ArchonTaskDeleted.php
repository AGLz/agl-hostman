<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class ArchonTaskDeleted implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public string $taskId
    ) {}

    public function broadcastOn(): array
    {
        return [
            new Channel('archon'),
        ];
    }

    public function broadcastAs(): string
    {
        return 'archon.task.deleted';
    }

    public function broadcastWith(): array
    {
        return [
            'task_id' => $this->taskId
        ];
    }
}
