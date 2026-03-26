<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class InfrastructureStatusUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public array $status;

    public string $serverCode;

    public string $statusLevel;

    public function __construct(string $serverCode, array $status, string $statusLevel = 'info')
    {
        $this->serverCode = $serverCode;
        $this->status = $status;
        $this->statusLevel = $statusLevel;
    }

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('infrastructure'),
            new PrivateChannel('server.'.$this->serverCode),
        ];
    }

    public function broadcastAs(): string
    {
        return 'status.updated';
    }

    public function broadcastWith(): array
    {
        return [
            'serverCode' => $this->serverCode,
            'status' => $this->status,
            'statusLevel' => $this->statusLevel,
            'timestamp' => now()->toIso8601String(),
        ];
    }
}
