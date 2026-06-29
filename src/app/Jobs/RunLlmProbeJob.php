<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Services\LlmMonitor\LiteLLMClient;
use App\Services\LlmMonitor\LlmMonitorService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * Probe HTTP ao LiteLLM — grava resultado em llm_probe_runs.
 */
class RunLlmProbeJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $timeout = 90;

    public int $tries = 2;

    public function __construct(
        public readonly string $probeType = 'simple',
        public readonly ?string $model = null,
        public readonly string $harness = 'laravel',
    ) {
        $this->onQueue('llm-monitor');
    }

    public function handle(LiteLLMClient $client, LlmMonitorService $monitor): void
    {
        $model = $this->model ?? (string) config('llm-monitor.default_probe_model', 'glm-4.7-flash');
        $result = $client->probe($model);

        $run = $monitor->recordProbeRun($this->probeType, $model, $result, $this->harness);

        Log::info('LLM probe completed', [
            'probe_run_id' => $run->id,
            'model' => $model,
            'result' => $run->result,
            'latency_ms' => $run->latency_ms,
        ]);
    }

    /**
     * @return list<string>
     */
    public function tags(): array
    {
        return ['llm-monitor', 'probe', $this->probeType];
    }
}
