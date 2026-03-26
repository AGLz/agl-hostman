<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class ArchonProjectUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public array $project
    ) {}

    public function broadcastOn(): array
    {
        return [
            new Channel('archon'),
        ];
    }

    public function broadcastAs(): string
    {
        return 'archon.project.updated';
    }

    public function broadcastWith(): array
    {
        return [
            'project' => $this->project,
        ];
    }
}
