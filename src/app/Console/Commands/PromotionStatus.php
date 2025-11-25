<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\Promotion;
use App\Models\Environment;
use Illuminate\Console\Command;

class PromotionStatus extends Command
{
    protected $signature = 'deployment:status';
    protected $description = 'Show promotion pipeline status';

    public function handle(): int
    {
        $this->info('=== Promotion Pipeline Status ===');
        $this->newLine();

        // Show environment versions
        $environments = Environment::whereIn('type', ['development', 'qa', 'uat', 'production'])
            ->orderByRaw("FIELD(type, 'development', 'qa', 'uat', 'production')")
            ->get();

        $this->table(
            ['Environment', 'Current Version', 'Status'],
            $environments->map(fn($env) => [
                strtoupper($env->type),
                $env->current_version ?? 'N/A',
                $env->status,
            ])
        );

        $this->newLine();

        // Show active promotions
        $active = Promotion::whereIn('status', ['pending_approval', 'approved', 'deploying'])
            ->with(['sourceEnvironment', 'targetEnvironment'])
            ->get();

        if ($active->isNotEmpty()) {
            $this->info('=== Active Promotions ===');
            $this->table(
                ['ID', 'Source', 'Target', 'Version', 'Status', 'Approvals'],
                $active->map(fn($p) => [
                    substr($p->id, 0, 8),
                    $p->sourceEnvironment->type,
                    $p->targetEnvironment->type,
                    $p->source_version,
                    $p->status,
                    "{$p->getRemainingApprovals()}/{$p->requires_approvals} remaining",
                ])
            );
        } else {
            $this->info('No active promotions');
        }

        return self::SUCCESS;
    }
}
