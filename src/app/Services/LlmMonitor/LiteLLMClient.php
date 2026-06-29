<?php

declare(strict_types=1);

namespace App\Services\LlmMonitor;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

final class LiteLLMClient
{
    private string $gatewayUrl;

    private ?string $masterKey;

    public function __construct()
    {
        $this->gatewayUrl = (string) config('llm-monitor.litellm_gateway_url');
        $this->masterKey = config('llm-monitor.litellm_master_key') ?: null;
    }

    public function isHealthy(): bool
    {
        try {
            $response = Http::timeout(10)->get("{$this->gatewayUrl}/health/readiness");

            return $response->successful();
        } catch (ConnectionException $e) {
            Log::debug('LiteLLM health check failed', ['error' => $e->getMessage()]);

            return false;
        }
    }

    public function getGlobalSpend(): ?float
    {
        if ($this->masterKey === null || $this->masterKey === '') {
            return null;
        }

        try {
            $response = Http::timeout(20)
                ->withToken($this->masterKey)
                ->get("{$this->gatewayUrl}/global/spend");

            if (! $response->successful()) {
                return null;
            }

            $data = $response->json();
            if (! is_array($data)) {
                return null;
            }

            foreach (['spend', 'total_spend', 'global_spend'] as $key) {
                if (isset($data[$key]) && is_numeric($data[$key])) {
                    return (float) $data[$key];
                }
            }

            return null;
        } catch (ConnectionException $e) {
            Log::warning('LiteLLM global spend fetch failed', ['error' => $e->getMessage()]);

            return null;
        }
    }

    /**
     * @return array{
     *     model: string,
     *     result: string,
     *     latency_ms: int,
     *     http_status: int,
     *     tokens_in: int|null,
     *     tokens_out: int|null,
     *     detail: string|null,
     *     meta: array<string, mixed>
     * }
     */
    public function probe(string $model, int $maxTokens = 4): array
    {
        $started = hrtime(true);
        $headers = ['Content-Type' => 'application/json'];
        if ($this->masterKey !== null && $this->masterKey !== '') {
            $headers['Authorization'] = "Bearer {$this->masterKey}";
        }

        try {
            $response = Http::timeout(45)
                ->withHeaders($headers)
                ->post("{$this->gatewayUrl}/v1/chat/completions", [
                    'model' => $model,
                    'messages' => [
                        ['role' => 'user', 'content' => 'pong'],
                    ],
                    'max_tokens' => $maxTokens,
                ]);
        } catch (ConnectionException $e) {
            return $this->probeResult($model, 'blocked', 0, 0, null, null, $e->getMessage(), $started);
        }

        $latencyMs = (int) round((hrtime(true) - $started) / 1_000_000);
        $httpStatus = $response->status();
        $body = $response->json();

        if (! is_array($body)) {
            return $this->probeResult($model, 'blocked', $latencyMs, $httpStatus, null, null, 'invalid json', $started);
        }

        if (isset($body['error'])) {
            $message = is_array($body['error'])
                ? (string) ($body['error']['message'] ?? json_encode($body['error']))
                : (string) $body['error'];
            $result = $this->classifyError($message, $httpStatus);

            return $this->probeResult($model, $result, $latencyMs, $httpStatus, null, null, $message, $started);
        }

        $usage = is_array($body['usage'] ?? null) ? $body['usage'] : [];
        $tokensIn = isset($usage['prompt_tokens']) ? (int) $usage['prompt_tokens'] : null;
        $tokensOut = isset($usage['completion_tokens']) ? (int) $usage['completion_tokens'] : null;
        $content = $body['choices'][0]['message']['content'] ?? null;
        $detail = is_string($content) ? mb_substr($content, 0, 120) : null;

        if ($httpStatus === 200 && $detail !== null) {
            return $this->probeResult($model, 'ok', $latencyMs, $httpStatus, $tokensIn, $tokensOut, $detail, $started);
        }

        return $this->probeResult($model, 'blocked', $latencyMs, $httpStatus, $tokensIn, $tokensOut, $detail, $started);
    }

    private function classifyError(string $message, int $httpStatus): string
    {
        $low = strtolower($message);

        if ($httpStatus === 429 || str_contains($low, 'rate') || str_contains($low, 'quota') || str_contains($low, 'limit')) {
            return 'rate-limited';
        }

        if (in_array($httpStatus, [401, 403], true)) {
            return 'blocked';
        }

        return 'blocked';
    }

    /**
     * @return array{
     *     model: string,
     *     result: string,
     *     latency_ms: int,
     *     http_status: int,
     *     tokens_in: int|null,
     *     tokens_out: int|null,
     *     detail: string|null,
     *     meta: array<string, mixed>
     * }
     */
    private function probeResult(
        string $model,
        string $result,
        int $latencyMs,
        int $httpStatus,
        ?int $tokensIn,
        ?int $tokensOut,
        ?string $detail,
        int $startedNs,
    ): array {
        return [
            'model' => $model,
            'result' => $result,
            'latency_ms' => $latencyMs > 0 ? $latencyMs : (int) round((hrtime(true) - $startedNs) / 1_000_000),
            'http_status' => $httpStatus,
            'tokens_in' => $tokensIn,
            'tokens_out' => $tokensOut,
            'detail' => $detail,
            'meta' => [],
        ];
    }
}
