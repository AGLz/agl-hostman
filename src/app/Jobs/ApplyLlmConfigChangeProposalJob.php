<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Models\LlmConfigChangeProposal;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Pós-aprovação Tier B — delegação Werner (webhook Hermes quando configurado).
 */
class ApplyLlmConfigChangeProposalJob implements ShouldQueue
{
    use Queueable;

    public function __construct(
        public readonly int $proposalId,
    ) {
        $this->onQueue('llm-monitor');
    }

    public function handle(): void
    {
        $proposal = LlmConfigChangeProposal::query()->find($this->proposalId);
        if ($proposal === null || $proposal->status !== 'approved') {
            return;
        }

        $payload = [
            'proposal_id' => $proposal->id,
            'tier' => $proposal->tier,
            'reason' => $proposal->reason,
            'diff' => $proposal->diff,
            'approved_by' => $proposal->approved_by,
        ];

        Log::info('llm-monitor.tier_b.approved', $payload);

        $webhook = config('llm-monitor.tier_b_delegate_webhook');
        if (is_string($webhook) && $webhook !== '') {
            Http::timeout(15)->post($webhook, [
                'agent' => 'werner',
                'task' => 'Aplicar proposta LiteLLM Tier B aprovada no Mission Control',
                'proposal' => $payload,
            ]);
        }
    }

    /**
     * @return list<string>
     */
    public function tags(): array
    {
        return ['llm-monitor', 'tier-b', 'proposal', (string) $this->proposalId];
    }
}
