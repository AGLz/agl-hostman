<?php

declare(strict_types=1);

namespace App\Services\Hermes;

use Illuminate\Support\Facades\Http;

final class HermesChatService
{
    /**
     * @param  array<int, array{role: string, content: string}>  $messages
     * @return array{0: array<string, mixed>, 1: int}
     */
    public function chat(string $agent, array $messages): array
    {
        $apiKey = config('hermes.api_key');
        if (! $apiKey) {
            return [[
                'success' => false,
                'error' => 'HERMES_API_KEY is not configured for direct agent chat',
            ], 503];
        }

        $meta = HermesAgentCatalog::metadata($agent);
        $systemMessage = sprintf(
            'You are %s (%s), part of the AGLz Hermes quartet on CT188. Respond in Portuguese when the user writes in Portuguese.',
            $meta['name'],
            $meta['role'],
        );

        $payloadMessages = [
            ['role' => 'system', 'content' => $systemMessage],
            ...$messages,
        ];

        $baseUrl = config('hermes.api_base_url');

        try {
            $started = microtime(true);
            $response = Http::timeout((int) config('hermes.chat_timeout'))
                ->withToken($apiKey)
                ->post($baseUrl . '/v1/chat/completions', [
                    'model' => config('hermes.chat_model'),
                    'messages' => $payloadMessages,
                    'stream' => false,
                    'max_tokens' => 900,
                ]);

            if (! $response->successful()) {
                return [[
                    'success' => false,
                    'error' => 'Hermes chat request failed',
                    'http_status' => $response->status(),
                    'body' => str($response->body())->limit(500)->toString(),
                ], 502];
            }

            $data = $response->json();
            $message = data_get($data, 'choices.0.message.content');

            return [[
                'success' => true,
                'agent' => $agent,
                'message' => $message,
                'latency_ms' => (int) round((microtime(true) - $started) * 1000),
                'usage' => $data['usage'] ?? null,
                'raw' => $message ? null : $data,
                'timestamp' => now()->toIso8601String(),
            ], 200];
        } catch (\Throwable $e) {
            return [[
                'success' => false,
                'error' => 'Hermes chat unavailable',
                'message' => $e->getMessage(),
            ], 502];
        }
    }
}
