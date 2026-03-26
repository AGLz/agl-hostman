<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class ArchonTaskMoved implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public array $task
    ) {}

    public function broadcastOn(): array
    {
        return [
            new Channel('archon'),
            new Channel("archon.projects.{$this->task['project_id']}"),
        ];
    }

    public function broadcastAs(): string
    {
        return 'archon.task.moved';
    }

    public function broadcastWith(): array
    {
        return [
            'task' => $this->task,
        ];
    }
}
