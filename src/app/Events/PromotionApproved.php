<?php

declare(strict_types=1);

namespace App\Events;

use App\Models\Promotion;
use App\Models\User;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class PromotionApproved implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public Promotion $promotion,
        public User $approver
    ) {}

    public function broadcastOn(): array
    {
        return ['promotions'];
    }

    public function broadcastAs(): string
    {
        return 'promotion.approved';
    }

    public function broadcastWith(): array
    {
        return [
            'promotion_id' => $this->promotion->id,
            'approver' => $this->approver->name,
            'remaining_approvals' => $this->promotion->getRemainingApprovals(),
        ];
    }
}
