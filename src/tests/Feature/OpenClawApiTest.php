<?php

declare(strict_types=1);

use App\Http\Controllers\Api\OpenClawController;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

covers(OpenClawController::class);

beforeEach(function () {
    Cache::flush();
    config([
        'openclaw.remote_status_enabled' => false,
        'openclaw.chat_transport' => 'http',
    ]);
});

it('returns live OpenClaw status and flat agent list', function () {
    Http::fake([
        'http://100.123.184.125:28789/healthz' => Http::response([
            'ok' => true,
            'status' => 'live',
        ]),
    ]);

    $this->getJson('/api/openclaw/status')
        ->assertOk()
        ->assertJsonPath('status', 'online')
        ->assertJsonPath('gateway', 'running')
        ->assertJsonPath('base_url', 'http://100.123.184.125:28789');

    $this->getJson('/api/agents')
        ->assertOk()
        ->assertJsonFragment([
            'id' => 'main',
            'status' => 'active',
        ]);
});

it('returns a clear error when agent chat token is missing', function () {
    Http::fake();
    config(['openclaw.gateway_token' => null]);

    $this->postJson('/api/openclaw/agents/main/chat', [
        'message' => 'ping',
    ])
        ->assertStatus(503)
        ->assertJsonPath('success', false);
});

it('proxies direct chat to the selected OpenClaw agent', function () {
    config(['openclaw.gateway_token' => 'test-token']);

    Http::fake([
        'http://100.123.184.125:28789/v1/chat/completions' => Http::response([
            'choices' => [
                ['message' => ['content' => 'pong']],
            ],
            'usage' => ['total_tokens' => 4],
        ]),
    ]);

    $this->postJson('/api/openclaw/agents/main/chat', [
        'message' => 'ping',
    ])
        ->assertOk()
        ->assertJsonPath('success', true)
        ->assertJsonPath('agent', 'main')
        ->assertJsonPath('message', 'pong');

    Http::assertSent(fn ($request) => $request->hasHeader('x-openclaw-agent-id', 'main')
        && $request['model'] === 'openclaw/main');
});
