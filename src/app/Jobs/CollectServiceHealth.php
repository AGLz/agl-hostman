<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Services\MissionControl\MissionControlSnapshotService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * Regenera cache do snapshot Mission Control (health HTTP + guests).
 */
class CollectServiceHealth implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $timeout = 120;

    public int $tries = 2;

    public function __construct(
        public readonly string $hostCode = 'aglsrv1',
    ) {
        $this->onQueue('monitoring');
    }

    public function handle(MissionControlSnapshotService $snapshots): void
    {
        $snapshot = $snapshots->getHostSnapshot($this->hostCode, forceRefresh: true);

        if ($snapshot === null) {
            Log::warning('Mission Control: host não encontrado no registry', [
                'host' => $this->hostCode,
            ]);

            return;
        }

        Log::info('Mission Control health collect completed', [
            'host' => $this->hostCode,
            'guests' => $snapshot['summary']['guests_total'] ?? null,
            'services_ok' => $snapshot['summary']['services_ok'] ?? null,
            'alerts' => $snapshot['summary']['alerts_total'] ?? null,
        ]);
    }

    /**
     * @return list<string>
     */
    public function tags(): array
    {
        return ['mission-control', 'health', $this->hostCode];
    }
}
