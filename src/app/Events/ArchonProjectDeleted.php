<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class ArchonProjectDeleted implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public string $projectId
    ) {}

    public function broadcastOn(): array
    {
        return [
            new Channel('archon'),
        ];
    }

    public function broadcastAs(): string
    {
        return 'archon.project.deleted';
    }

    public function broadcastWith(): array
    {
        return [
            'project_id' => $this->projectId,
        ];
    }
}
