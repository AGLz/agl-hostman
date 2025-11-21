<?php

namespace App\Jobs;

use App\Services\AIModelService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * ProcessAIRequest - Background job for parallel AI model execution
 *
 * Replaces broken Http::async() implementation in AIModelService
 * Uses Laravel Job Batching for true parallel execution
 */
class ProcessAIRequest implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $timeout = 120; // 2 minutes max per AI request
    public $tries = 2;
    public $backoff = [10, 30]; // Retry after 10s, then 30s

    /**
     * Create a new job instance.
     */
    public function __construct(
        public string $model,
        public string $prompt,
        public array $options = []
    ) {
        $this->onQueue('ai-processing');
    }

    /**
     * Execute the job.
     */
    public function handle(AIModelService $aiService): array
    {
        $startTime = microtime(true);

        Log::info("Processing AI request for model: {$this->model}", [
            'prompt_length' => strlen($this->prompt),
            'options' => $this->options,
        ]);

        try {
            $result = $aiService->query($this->model, $this->prompt, $this->options);

            $executionTime = round((microtime(true) - $startTime) * 1000, 2);

            Log::info("AI request completed for model: {$this->model}", [
                'execution_time_ms' => $executionTime,
                'success' => $result['success'] ?? false,
            ]);

            return [
                'model' => $this->model,
                'success' => $result['success'] ?? false,
                'response' => $result['response'] ?? null,
                'execution_time_ms' => $executionTime,
                'timestamp' => now()->toIso8601String(),
            ];

        } catch (\Exception $e) {
            Log::error("AI request failed for model: {$this->model}", [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            return [
                'model' => $this->model,
                'success' => false,
                'error' => $e->getMessage(),
                'execution_time_ms' => round((microtime(true) - $startTime) * 1000, 2),
                'timestamp' => now()->toIso8601String(),
            ];
        }
    }

    /**
     * Handle a job failure.
     */
    public function failed(\Throwable $exception): void
    {
        Log::error("AI request job failed permanently for model: {$this->model}", [
            'error' => $exception->getMessage(),
            'attempts' => $this->attempts(),
        ]);
    }

    /**
     * Get the tags that should be assigned to the job.
     */
    public function tags(): array
    {
        return ['ai-processing', "model:{$this->model}"];
    }
}
