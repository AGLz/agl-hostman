<?php

declare(strict_types=1);

namespace App\Events;

use App\Models\Promotion;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class PromotionRequested implements ShouldBroadcast
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
        return 'promotion.requested';
    }

    public function broadcastWith(): array
    {
        return [
            'promotion_id' => $this->promotion->id,
            'source_env' => $this->promotion->sourceEnvironment->type,
            'target_env' => $this->promotion->targetEnvironment->type,
            'version' => $this->promotion->source_version,
            'requires_approvals' => $this->promotion->requires_approvals,
        ];
    }
}
