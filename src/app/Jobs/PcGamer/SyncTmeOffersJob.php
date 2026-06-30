<?php

declare(strict_types=1);

namespace App\Jobs\PcGamer;

use App\Services\PcGamer\Telegram\TmeSyncService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class SyncTmeOffersJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $timeout = 300;

    public int $tries = 2;

    /**
     * @param  list<string>|null  $chatKeys
     */
    public function __construct(
        public readonly ?array $chatKeys = null,
        public readonly ?int $limit = null,
    ) {
        $this->onQueue('pc-gamer');
    }

    public function handle(TmeSyncService $syncService): void
    {
        $results = $syncService->syncAll($this->chatKeys, $this->limit);

        $imported = array_sum(array_map(fn($r) => $r->imported, $results));
        $skipped = array_sum(array_map(fn($r) => $r->skipped, $results));
        $errors = array_sum(array_map(fn($r) => $r->errors, $results));

        Log::info('PC Gamer t.me sync concluído', [
            'channels' => count($results),
            'imported' => $imported,
            'skipped' => $skipped,
            'errors' => $errors,
        ]);
    }

    /** @return list<int> */
    public function backoff(): array
    {
        return [60, 180];
    }
}
