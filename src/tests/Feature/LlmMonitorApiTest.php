<?php

declare(strict_types=1);

use App\Http\Controllers\Api\LlmMonitorController;
use App\Models\LlmProviderSnapshot;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

uses(RefreshDatabase::class);

covers(LlmMonitorController::class);

beforeEach(function () {
    Cache::flush();
    $example = base_path('../config/monitoring/quota-governor-state.example.json');

    config([
        'llm-monitor.governor_state_path' => $example,
        'llm-monitor.governor_state_fallback' => $example,
        'llm-monitor.litellm_gateway_url' => 'http://litellm.test',
        'llm-monitor.litellm_master_key' => 'test-master-key',
        'llm-monitor.ingest_cache_ttl' => 1,
        'services.hostman.api_key' => 'llm-monitor-test-key',
    ]);

    Http::fake([
        'litellm.test/health/readiness' => Http::response(['status' => 'ok'], 200),
        'litellm.test/global/spend' => Http::response(['spend' => 42.5], 200),
        'litellm.test/v1/chat/completions' => Http::response([
            'choices' => [['message' => ['content' => 'pong']]],
            'usage' => ['prompt_tokens' => 3, 'completion_tokens' => 1],
        ], 200),
    ]);
});

it('requires authentication for status', function () {
    $this->getJson('/api/llm-monitor/status')->assertUnauthorized();
});

it('returns llm monitor status for authenticated users', function () {
    $this->actingAs(User::factory()->create(), 'sanctum');

    $this->getJson('/api/llm-monitor/status')
        ->assertOk()
        ->assertJsonPath('success', true)
        ->assertJsonPath('gateway.ok', true)
        ->assertJsonPath('gateway.global_spend_usd', 42.5)
        ->assertJsonPath('governor.action', 'ok')
        ->assertJsonStructure([
            'checked_at',
            'overall',
            'providers',
            'limit_events_open',
            'pending_proposals',
            'recent_probes',
        ]);
});

it('returns provider detail for known provider', function () {
    $this->actingAs(User::factory()->create(), 'sanctum');

    LlmProviderSnapshot::query()->create([
        'provider' => 'zai',
        'model_alias' => 'zai-glm-5',
        'tier' => 'T3',
        'status' => 'ok',
        'captured_at' => now(),
    ]);

    $this->getJson('/api/llm-monitor/providers/zai')
        ->assertOk()
        ->assertJsonPath('provider', 'zai')
        ->assertJsonPath('canonical_model', 'zai-glm-5')
        ->assertJsonPath('latest_snapshot.status', 'ok');
});

it('returns 404 for unknown provider', function () {
    $this->actingAs(User::factory()->create(), 'sanctum');

    $this->getJson('/api/llm-monitor/providers/not-a-real-provider')
        ->assertNotFound()
        ->assertJsonPath('success', false);
});

it('runs live probe when requested', function () {
    $this->actingAs(User::factory()->create(), 'sanctum');

    $this->getJson('/api/llm-monitor/providers/zai?live=1')
        ->assertOk()
        ->assertJsonPath('live_probe.result', 'ok')
        ->assertJsonPath('live_probe.model', 'zai-glm-5');
});

it('ingests governor state via api key', function () {
    $state = json_decode(
        (string) file_get_contents(base_path('../config/monitoring/quota-governor-state.example.json')),
        true,
    );

    $this->withHeader('X-API-Key', 'llm-monitor-test-key')
        ->postJson('/api/llm-monitor/ingest', $state)
        ->assertOk()
        ->assertJsonPath('success', true);

    expect(LlmProviderSnapshot::query()->count())->toBeGreaterThan(0);
});

it('dispatches probe job via api key', function () {
    \Illuminate\Support\Facades\Queue::fake();

    $this->withHeader('X-API-Key', 'llm-monitor-test-key')
        ->postJson('/api/llm-monitor/probe', ['probe_type' => 'simple', 'model' => 'glm-4.7-flash'])
        ->assertAccepted()
        ->assertJsonPath('success', true);

    \Illuminate\Support\Facades\Queue::assertPushed(\App\Jobs\RunLlmProbeJob::class);
});

it('creates tier b proposal via api key', function () {
    $this->withHeader('X-API-Key', 'llm-monitor-test-key')
        ->postJson('/api/llm-monitor/proposals', [
            'tier' => 'B',
            'reason' => 'Fallback free-tier no LiteLLM',
            'diff' => ['model' => 'glm-4.7-flash'],
        ])
        ->assertCreated()
        ->assertJsonPath('proposal.status', 'pending')
        ->assertJsonPath('proposal.tier', 'B');
});

it('approves pending proposal for authenticated user', function () {
    \Illuminate\Support\Facades\Queue::fake();

    $user = User::factory()->create(['email' => 'ops@aglz.io']);
    $proposal = \App\Models\LlmConfigChangeProposal::query()->create([
        'diff' => ['alias' => 'agl-primary'],
        'reason' => 'Test Tier B',
        'tier' => 'B',
        'status' => 'pending',
    ]);

    $this->actingAs($user, 'sanctum')
        ->postJson("/api/llm-monitor/proposals/{$proposal->id}/approve")
        ->assertOk()
        ->assertJsonPath('proposal.status', 'approved')
        ->assertJsonPath('proposal.approved_by', 'ops@aglz.io');

    \Illuminate\Support\Facades\Queue::assertPushed(\App\Jobs\ApplyLlmConfigChangeProposalJob::class);
});

it('rejects pending proposal for authenticated user', function () {
    $user = User::factory()->create(['email' => 'ops@aglz.io']);
    $proposal = \App\Models\LlmConfigChangeProposal::query()->create([
        'diff' => ['alias' => 'agl-primary'],
        'reason' => 'Test reject',
        'tier' => 'B',
        'status' => 'pending',
    ]);

    $this->actingAs($user, 'sanctum')
        ->postJson("/api/llm-monitor/proposals/{$proposal->id}/reject")
        ->assertOk()
        ->assertJsonPath('proposal.status', 'rejected');
});
