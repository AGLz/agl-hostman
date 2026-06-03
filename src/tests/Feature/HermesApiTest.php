<?php

declare(strict_types=1);

use App\Http\Controllers\Api\HermesController;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

covers(HermesController::class);

beforeEach(function () {
    Cache::flush();
    config([
        'hermes.api_base_url' => 'http://100.81.225.22:8642',
        'hermes.api_key' => 'test-hermes-key',
        'hermes.minions_base_url' => 'http://100.81.225.22:6969',
    ]);
});

it('returns live Hermes status and flat agent list', function () {
    Http::fake([
        'http://100.81.225.22:8642/health' => Http::response([
            'status' => 'ok',
            'platform' => 'hermes-agent',
        ]),
        'http://100.81.225.22:6969/api/health' => Http::response(['ok' => true]),
        'http://100.81.225.22:6969/api/tasks' => Http::response(['tasks' => []]),
        'http://100.81.225.22:6969/api/scheduled-tasks' => Http::response(['scheduledTasks' => []]),
    ]);

    $this->getJson('/api/hermes/status')
        ->assertOk()
        ->assertJsonPath('status', 'online')
        ->assertJsonPath('gateway', 'running')
        ->assertJsonPath('base_url', 'http://100.81.225.22:8642');

    $this->getJson('/api/agents')
        ->assertOk()
        ->assertJsonFragment([
            'id' => 'jarvis',
            'status' => 'active',
        ]);
});

it('returns categorized Hermes quartet metadata', function () {
    Http::fake([
        'http://100.81.225.22:8642/health' => Http::response(['status' => 'ok']),
        'http://100.81.225.22:6969/*' => Http::response([]),
    ]);

    $this->getJson('/api/hermes/agents')
        ->assertOk()
        ->assertJsonPath('gateway', 'running')
        ->assertJsonPath('source', 'ct188-http')
        ->assertJsonPath('total', 4)
        ->assertJsonStructure([
            'categorized' => ['executive', 'infrastructure'],
            'agents' => [
                '*' => ['id', 'name', 'role', 'group', 'status', 'sessions', 'currentTask', 'lastActive'],
            ],
        ]);
});

it('returns minions task summary for dashboard polling', function () {
    Http::fake([
        'http://100.81.225.22:8642/health' => Http::response(['status' => 'ok']),
        'http://100.81.225.22:6969/api/health' => Http::response(['ok' => true]),
        'http://100.81.225.22:6969/api/tasks' => Http::response([
            'tasks' => [
                ['id' => '1', 'status' => 'in_progress', 'title' => 'Deploy'],
                ['id' => '2', 'status' => 'done', 'title' => 'Review'],
            ],
        ]),
        'http://100.81.225.22:6969/api/scheduled-tasks' => Http::response(['scheduledTasks' => []]),
    ]);

    $this->getJson('/api/tasks/summary')
        ->assertOk()
        ->assertJsonPath('total', 2)
        ->assertJsonPath('active', 1)
        ->assertJsonPath('completed', 1)
        ->assertJsonStructure(['total', 'active', 'queued', 'failed', 'completed', 'recent', 'checked_at']);
});

it('returns agent status counts for mission control layout', function () {
    Http::fake([
        'http://100.81.225.22:8642/health' => Http::response(['status' => 'ok']),
        'http://100.81.225.22:6969/*' => Http::response([]),
    ]);

    $this->getJson('/api/agent-status')
        ->assertOk()
        ->assertJsonPath('total', 4)
        ->assertJsonPath('active', 1);
});

it('returns a clear error when Hermes chat api key is missing', function () {
    Http::fake();
    config(['hermes.api_key' => null]);

    $this->postJson('/api/hermes/agents/jarvis/chat', [
        'message' => 'ping',
    ])
        ->assertStatus(503)
        ->assertJsonPath('success', false);
});

it('proxies direct chat to the selected Hermes agent persona', function () {
    Http::fake([
        'http://100.81.225.22:8642/health' => Http::response(['status' => 'ok']),
        'http://100.81.225.22:6969/*' => Http::response([]),
        'http://100.81.225.22:8642/v1/chat/completions' => Http::response([
            'choices' => [
                ['message' => ['content' => 'pong']],
            ],
            'usage' => ['total_tokens' => 4],
        ]),
    ]);

    $this->postJson('/api/hermes/agents/satya/chat', [
        'message' => 'ping',
    ])
        ->assertOk()
        ->assertJsonPath('success', true)
        ->assertJsonPath('agent', 'satya')
        ->assertJsonPath('message', 'pong');

    Http::assertSent(fn($request) => $request->hasHeader('Authorization', 'Bearer test-hermes-key')
        && $request['model'] === 'hermes-agent'
        && str_contains($request['messages'][0]['content'], 'Satya'));
});

it('rejects unknown Hermes agent identifiers', function () {
    Http::fake();

    $this->postJson('/api/hermes/agents/unknown/chat', [
        'message' => 'ping',
    ])->assertStatus(404)
        ->assertJsonPath('success', false);
});

it('exposes Hermes UI links for studio embedding', function () {
    config([
        'hermes.studio_base_url' => 'http://100.81.225.22:3000',
        'hermes.studio_access_token' => 'studio-token',
    ]);

    $this->getJson('/api/hermes/ui-links')
        ->assertOk()
        ->assertJsonPath('studio_url', 'http://100.81.225.22:3000')
        ->assertJsonPath('studio_access_token', 'studio-token');
});
