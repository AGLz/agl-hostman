<?php

declare(strict_types=1);

use App\Http\Controllers\Api\HarnessController;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;

uses(RefreshDatabase::class);

covers(HarnessController::class);

beforeEach(function () {
    Cache::flush();
    $example = base_path('../config/monitoring/quota-governor-state.example.json');
    config([
        'harness.governor_state_path' => $example,
        'harness.governor_state_fallback' => $example,
        'harness.virtual_keys_manifest' => base_path('../config/litellm/virtual-keys-manifest.example.json'),
        'harness.repo_root' => base_path('..'),
        'harness.cache_ttl' => 1,
    ]);
});

it('requires authentication', function () {
    $this->getJson('/api/harness/snapshot')->assertUnauthorized();
});

it('returns harness snapshot for mission control', function () {
    $this->actingAs(User::factory()->create(), 'sanctum');

    $this->getJson('/api/harness/snapshot')
        ->assertOk()
        ->assertJsonPath('governor.action', 'ok')
        ->assertJsonPath('hermes.tier', 'paid')
        ->assertJsonStructure([
            'checked_at',
            'governor' => ['tiers' => ['T3', 'T4', 'T5']],
            'teams',
            'harnesses',
            'work_queue' => ['bd_ready', 'agent_os_specs'],
            'cursor',
        ]);

    expect(collect($this->getJson('/api/harness/snapshot')->json('teams'))->pluck('team_alias'))
        ->toContain('team-cursor', 'team-hermes');
});

it('falls back when governor state is missing', function () {
    $this->actingAs(User::factory()->create(), 'sanctum');
    config(['harness.governor_state_path' => '/tmp/nonexistent-governor-state.json']);

    $this->getJson('/api/harness/snapshot')
        ->assertOk()
        ->assertJsonPath('governor.action', 'ok');
});

it('lists agent-os specs with task counts', function () {
    $this->actingAs(User::factory()->create(), 'sanctum');
    $specs = $this->getJson('/api/harness/snapshot')->json('work_queue.agent_os_specs');

    expect($specs)->toBeArray();
    expect(collect($specs)->firstWhere('slug', 'wireguard-peer-setup'))->not->toBeNull();
});
