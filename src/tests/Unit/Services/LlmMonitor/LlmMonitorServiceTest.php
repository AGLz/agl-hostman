<?php

declare(strict_types=1);

use App\Models\LlmLimitEvent;
use App\Models\LlmProviderSnapshot;
use App\Services\LlmMonitor\LiteLLMClient;
use App\Services\LlmMonitor\LlmMonitorService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

uses(RefreshDatabase::class);

beforeEach(function () {
    Cache::flush();
    $example = base_path('../config/monitoring/quota-governor-state.example.json');

    config([
        'llm-monitor.governor_state_path' => $example,
        'llm-monitor.governor_state_fallback' => $example,
        'llm-monitor.litellm_gateway_url' => 'http://litellm.test',
        'llm-monitor.ingest_cache_ttl' => 1,
    ]);
});

it('parses governor tiers into provider snapshots', function () {
    $state = [
        'timestamp' => '2026-06-27T10:00:00Z',
        'action' => 'ok',
        'tiers' => [
            'T3' => [
                'ok' => 2,
                'quota' => 0,
                'fail' => 1,
                'detail' => 'zai-glm-5:OK,gpt-5.4-mini:OK,claude-haiku:FAIL:401',
            ],
        ],
    ];

    $service = app(LlmMonitorService::class);
    $written = $service->ingestGovernorState($state);

    expect($written)->toBeGreaterThanOrEqual(3);
    expect(LlmProviderSnapshot::query()->where('model_alias', 'zai-glm-5')->exists())->toBeTrue();
    expect(LlmLimitEvent::query()->where('model_alias', 'claude-haiku')->exists())->toBeTrue();
});

it('records probe runs from lite llm client', function () {
    Http::fake([
        'litellm.test/v1/chat/completions' => Http::response([
            'choices' => [['message' => ['content' => 'pong']]],
            'usage' => ['prompt_tokens' => 2, 'completion_tokens' => 1],
        ], 200),
    ]);

    config(['llm-monitor.litellm_gateway_url' => 'http://litellm.test']);

    $client = app(LiteLLMClient::class);
    $result = $client->probe('glm-4.7-flash');

    expect($result['result'])->toBe('ok');
    expect($result['tokens_in'])->toBe(2);

    $run = app(LlmMonitorService::class)->recordProbeRun('simple', 'glm-4.7-flash', $result);

    expect($run->id)->toBeGreaterThan(0);
    expect($run->result)->toBe('ok');
});

it('classifies rate limit errors in probe', function () {
    Http::fake([
        'litellm.test/v1/chat/completions' => Http::response([
            'error' => ['message' => 'Rate limit exceeded'],
        ], 429),
    ]);

    config(['llm-monitor.litellm_gateway_url' => 'http://litellm.test']);

    $result = app(LiteLLMClient::class)->probe('gpt-5.4-mini');

    expect($result['result'])->toBe('rate-limited');
});

it('resolves provider model aliases', function () {
    $service = app(LlmMonitorService::class);

    expect($service->resolveProviderModel('anthropic'))->toBe('claude-haiku');
    expect($service->resolveProviderModel('cursor'))->toBe('cursor-composer');
    expect($service->resolveProviderModel('nope'))->toBeNull();
});
