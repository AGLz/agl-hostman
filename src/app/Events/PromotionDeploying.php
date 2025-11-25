<?php

declare(strict_types=1);

namespace App\Events;

use App\Models\Promotion;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class PromotionDeploying implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public Promotion $promotion
    ) {}

    public function broadcastOn(): array
    {
        return ['promotions'];
    }

    public function broadcastAs(): string
    {
        return 'promotion.deploying';
    }
}
