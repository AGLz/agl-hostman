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

it('returns live OpenClaw status', function () {
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
});

it('returns categorized OpenClaw agent dashboard metadata', function () {
    Http::fake([
        'http://100.123.184.125:28789/healthz' => Http::response([
            'ok' => true,
            'status' => 'live',
        ]),
    ]);

    $this->getJson('/api/openclaw/agents')
        ->assertOk()
        ->assertJsonPath('gateway', 'running')
        ->assertJsonPath('source', 'ct187-http')
        ->assertJsonPath('base_url', 'http://100.123.184.125:28789')
        ->assertJsonPath('errors', 0)
        ->assertJsonStructure([
            'total',
            'active',
            'standby',
            'errors',
            'categorized' => ['core', 'infrastructure', 'scrum', 'executive'],
            'agents' => [
                '*' => ['id', 'name', 'role', 'group', 'status', 'sessions', 'currentTask', 'lastActive'],
            ],
            'checked_at',
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
        'history' => [
            ['role' => 'user', 'content' => 'contexto anterior'],
            ['role' => 'assistant', 'content' => 'ok'],
        ],
    ])
        ->assertOk()
        ->assertJsonPath('success', true)
        ->assertJsonPath('agent', 'main')
        ->assertJsonPath('message', 'pong');

    Http::assertSent(fn($request) => $request->hasHeader('x-openclaw-agent-id', 'main')
        && $request['model'] === 'openclaw/main'
        && count($request['messages']) === 3
        && $request['messages'][2]['content'] === 'ping');
});

it('rejects invalid agent identifiers before proxying chat', function () {
    Http::fake();

    $this->postJson('/api/openclaw/agents/bad agent/chat', [
        'message' => 'ping',
    ])->assertStatus(404)
        ->assertJsonPath('success', false);

    Http::assertNothingSent();
});

it('returns a clear error when the agent chat upstream fails', function () {
    config(['openclaw.gateway_token' => 'test-token']);

    Http::fake([
        'http://100.123.184.125:28789/v1/chat/completions' => Http::response([
            'error' => 'agent unavailable',
        ], 503),
    ]);

    $this->postJson('/api/openclaw/agents/devops/chat', [
        'message' => 'ping',
    ])
        ->assertStatus(502)
        ->assertJsonPath('success', false)
        ->assertJsonPath('http_status', 503);
});
