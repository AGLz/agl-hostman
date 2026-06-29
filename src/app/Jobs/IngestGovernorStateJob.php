<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Services\LlmMonitor\LlmMonitorService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * Ingere quota-governor-state.json para snapshots e eventos de limite.
 */
class IngestGovernorStateJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $timeout = 120;

    public int $tries = 3;

    public function __construct()
    {
        $this->onQueue('llm-monitor');
    }

    public function handle(LlmMonitorService $monitor): void
    {
        $written = $monitor->ingestGovernorState();

        Log::info('LLM monitor governor ingest completed', [
            'records_written' => $written,
        ]);
    }

    /**
     * @return list<string>
     */
    public function tags(): array
    {
        return ['llm-monitor', 'ingest', 'governor'];
    }
}
