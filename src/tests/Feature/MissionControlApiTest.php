<?php

declare(strict_types=1);

use App\DTO\ProxmoxApiResponse;
use App\Http\Controllers\Api\MissionControlHostController;
use App\Models\User;
use App\Services\Proxmox\ProxmoxApiClient;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
uses(RefreshDatabase::class);

covers(MissionControlHostController::class);

beforeEach(function () {
    Cache::flush();
    config([
        'mission-control.cache_ttl' => 60,
        'mission-control.probe_health' => true,
        'mission-control.probe_proxmox' => true,
        'mission-control.health_timeout' => 1,
    ]);

    $this->mock(ProxmoxApiClient::class, function ($mock) {
        $mock->shouldReceive('get')
            ->with('/cluster/resources', \Mockery::any())
            ->andReturn(ProxmoxApiResponse::error('Proxmox offline in test', 503));
    });

    Http::fake([
        'http://100.125.249.8:4000/*' => Http::response(['status' => 'ok'], 200),
        'http://192.168.0.187:*' => Http::response('ok', 200),
        'http://100.81.225.22:*' => Http::response(['ok' => true], 200),
        'http://192.168.0.192:*' => Http::response([], 404),
        'https://harbor.aglz.io/*' => Http::response('', 401),
        'http://192.168.0.180:*' => Http::response(['status' => 'ok'], 200),
        'https://ah.aglz.io/*' => Http::response('ok', 200),
        'http://192.168.0.183:*' => Http::response(['ok' => true], 200),
        'http://192.168.0.184:*' => Http::response(['ok' => true], 200),
        'http://192.168.0.200:*' => Http::response(['models' => []], 200),
        'http://192.168.0.202:*' => Http::response('ok', 200),
        '*' => Http::response('down', 500),
    ]);
});

it('requires authentication for host snapshot', function () {
    $this->getJson('/api/mission-control/hosts/aglsrv1/snapshot')
        ->assertUnauthorized();
});

it('returns aglsrv1 snapshot with guests services and runbooks', function () {
    $this->actingAs(User::factory()->create(), 'sanctum');

    $response = $this->getJson('/api/mission-control/hosts/aglsrv1/snapshot')
        ->assertOk()
        ->assertJsonPath('host.code', 'aglsrv1')
        ->assertJsonStructure([
            'checked_at',
            'host' => ['code', 'name'],
            'summary' => [
                'guests_total',
                'services_total',
                'services_ok',
                'alerts_total',
                'semaphore',
            ],
            'guests',
            'services',
            'alerts',
            'sources',
            'poll_interval_ms',
        ]);

    $json = $response->json();

    expect($json['summary']['guests_total'])->toBeGreaterThanOrEqual(20);
    expect($json['summary']['services_total'])->toBeGreaterThanOrEqual(10);
    expect($json['services'])->toHaveCount($json['summary']['services_total']);
    expect(collect($json['services'])->where('health', 'ok')->count())
        ->toBeGreaterThanOrEqual(10);

    // meshagent_vm104 dispara com guest unknown/running
    expect(collect($json['alerts'])->pluck('id'))->toContain('meshagent_vm104');
    expect(count($json['alerts']))->toBeGreaterThanOrEqual(1);
});

it('returns 404 for unknown host', function () {
    $this->actingAs(User::factory()->create(), 'sanctum');

    $this->getJson('/api/mission-control/hosts/unknown-host/snapshot')
        ->assertNotFound()
        ->assertJsonPath('error', 'Host não encontrado no registry');
});

it('lists guests endpoint', function () {
    $this->actingAs(User::factory()->create(), 'sanctum');

    $count = $this->getJson('/api/mission-control/hosts/aglsrv1/guests')
        ->assertOk()
        ->assertJsonPath('host', 'aglsrv1')
        ->json('count');

    expect($count)->toBeGreaterThanOrEqual(20);
});

it('refresh rebuilds snapshot bypassing cache', function () {
    $this->actingAs(User::factory()->create(), 'sanctum');

    Cache::put('mission_control_host_aglsrv1', [
        'checked_at' => 'stale',
        'host' => ['code' => 'aglsrv1'],
        'summary' => ['guests_total' => 0],
        'guests' => [],
        'services' => [],
        'alerts' => [],
    ], 60);

    $this->postJson('/api/mission-control/hosts/aglsrv1/refresh')
        ->assertOk()
        ->assertJsonPath('host.code', 'aglsrv1')
        ->assertJsonPath('checked_at', fn ($v) => $v !== 'stale')
        ->assertJsonPath('summary.guests_total', fn ($n) => $n >= 20);
});

it('marks litellm_down runbook when liteLLM is down', function () {
    Cache::flush();
    config([
        'mission-control.services.litellm.health_url' => 'http://litellm.test/health/down',
        'mission-control.services.litellm.accept_statuses' => [200],
    ]);
    Http::fake([
        'http://litellm.test/*' => Http::response('fail', 503),
        '*' => Http::response('ok', 200),
    ]);

    $this->actingAs(User::factory()->create(), 'sanctum');

    $response = $this->getJson('/api/mission-control/hosts/aglsrv1/snapshot')->assertOk();
    $litellm = collect($response->json('services'))->firstWhere('key', 'litellm');

    expect($litellm['health'] ?? null)->toBe('down');
    expect(collect($response->json('alerts'))->pluck('id'))->toContain('litellm_down');
});

it('serves cached snapshot under two seconds', function () {
    $this->actingAs(User::factory()->create(), 'sanctum');

    $this->getJson('/api/mission-control/hosts/aglsrv1/snapshot')->assertOk();

    $start = hrtime(true);
    $this->getJson('/api/mission-control/hosts/aglsrv1/snapshot')->assertOk();
    $elapsedMs = (hrtime(true) - $start) / 1_000_000;

    expect($elapsedMs)->toBeLessThan(2000);
});
