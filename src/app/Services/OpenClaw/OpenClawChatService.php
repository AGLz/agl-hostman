<?php

declare(strict_types=1);

namespace App\Services\OpenClaw;

use Illuminate\Support\Facades\Http;
use Symfony\Component\Process\Exception\ProcessTimedOutException;

final class OpenClawChatService
{
    public function __construct(
        private readonly OpenClawRemoteExecutor $remoteExecutor,
    ) {}

    public function transport(): string
    {
        return (string) config('openclaw.chat_transport');
    }

    /**
     * @param  array<int, array{role: string, content: string}>  $messages
     * @return array{0: array<string, mixed>, 1: int}
     */
    public function chatViaHttp(string $agent, array $messages): array
    {
        $token = config('openclaw.gateway_token');
        if (! $token) {
            return [[
                'success' => false,
                'error' => 'OPENCLAW_GATEWAY_TOKEN is not configured for direct agent chat',
            ], 503];
        }

        $baseUrl = config('openclaw.chat_base_url');

        try {
            $started = microtime(true);
            $timeout = (int) config('openclaw.chat_timeout');
            $response = Http::timeout($timeout)
                ->withHeaders([
                    'Authorization' => 'Bearer '.$token,
                    'x-openclaw-agent-id' => $agent,
                ])
                ->post($baseUrl.'/v1/chat/completions', [
                    'model' => 'openclaw/'.$agent,
                    'messages' => $messages,
                    'stream' => false,
                    'max_tokens' => 900,
                ]);

            if (! $response->successful()) {
                return [[
                    'success' => false,
                    'error' => 'OpenClaw chat request failed',
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
                'error' => 'OpenClaw chat unavailable',
                'message' => $e->getMessage(),
            ], 502];
        }
    }

    /**
     * @return array{0: array<string, mixed>, 1: int}
     */
    public function chatViaRemoteCli(string $agent, string $message): array
    {
        try {
            $started = microtime(true);
            $timeout = (int) config('openclaw.chat_timeout');
            $result = $this->remoteExecutor->runOpenClaw([
                'agent',
                '--agent',
                $agent,
                '--message',
                $message,
                '--json',
                '--timeout',
                (string) $timeout,
            ], $timeout + 15);

            if (! $result['success']) {
                return [[
                    'success' => false,
                    'error' => 'OpenClaw agent command failed',
                    'body' => str($result['output'])->limit(500)->toString(),
                ], 502];
            }

            $data = $this->remoteExecutor->decodeJsonOutput($result['output']);
            $payloads = data_get($data, 'result.payloads', data_get($data, 'payloads', []));
            $firstPayload = is_array($payloads) ? ($payloads[0] ?? []) : [];
            $text = $firstPayload['text'] ?? data_get($data, 'result.finalAssistantVisibleText');

            return [[
                'success' => filled($text),
                'agent' => $agent,
                'message' => $text,
                'latency_ms' => (int) round((microtime(true) - $started) * 1000),
                'usage' => data_get($data, 'result.meta.agentMeta.lastCallUsage'),
                'model' => data_get($data, 'result.meta.agentMeta.model'),
                'provider' => data_get($data, 'result.meta.agentMeta.provider'),
                'session_id' => data_get($data, 'result.meta.agentMeta.sessionId'),
                'raw' => filled($text) ? null : $data,
                'timestamp' => now()->toIso8601String(),
            ], filled($text) ? 200 : 502];
        } catch (ProcessTimedOutException) {
            return [[
                'success' => false,
                'error' => 'OpenClaw agent command timed out',
            ], 504];
        } catch (\Throwable $e) {
            return [[
                'success' => false,
                'error' => 'OpenClaw chat unavailable',
                'message' => $e->getMessage(),
            ], 502];
        }
    }
}
