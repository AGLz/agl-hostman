<?php

declare(strict_types=1);

use App\Models\User;
use App\Models\LxcContainer;
use App\Models\ProxmoxServer;
use Illuminate\Support\Facades\Http;

describe('Infrastructure API', function () {
    beforeEach(function () {
        $this->user = User::factory()->create();
        $this->token = $this->user->createToken('test')->plainTextToken;
    });

    it('returns list of all containers', function () {
        LxcContainer::factory()->count(3)->create();

        $response = $this->withToken($this->token)
            ->getJson('/api/v1/infrastructure/containers');

        $response->assertOk()
            ->assertJsonStructure([
                'success',
                'data' => [
                    '*' => ['id', 'vmid', 'name', 'status'],
                ],
            ])
            ->assertJsonCount(3, 'data');
    });

    it('filters containers by status', function () {
        LxcContainer::factory()->create(['status' => 'running']);
        LxcContainer::factory()->create(['status' => 'running']);
        LxcContainer::factory()->create(['status' => 'stopped']);

        $response = $this->withToken($this->token)
            ->getJson('/api/v1/infrastructure/containers?status=running');

        $response->assertOk()
            ->assertJsonCount(2, 'data');
    });

    it('retrieves container details by VMID', function () {
        $container = LxcContainer::factory()->create(['vmid' => 100]);

        Http::fake([
            '*/nodes/*/lxc/100/status/current' => Http::response([
                'data' => containerMetrics(['status' => 'running']),
            ], 200),
        ]);

        $response = $this->withToken($this->token)
            ->getJson('/api/v1/infrastructure/containers/100');

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'vmid' => 100,
                ],
            ]);
    });

    it('requires authentication for all endpoints', function () {
        $response = $this->getJson('/api/v1/infrastructure/containers');

        $response->assertUnauthorized();
    });

    it('validates pagination parameters', function () {
        LxcContainer::factory()->count(25)->create();

        $response = $this->withToken($this->token)
            ->getJson('/api/v1/infrastructure/containers?per_page=10&page=2');

        $response->assertOk()
            ->assertJsonCount(10, 'data')
            ->assertJsonPath('meta.current_page', 2);
    });

    it('starts a container', function () {
        $container = LxcContainer::factory()->create(['vmid' => 100, 'status' => 'stopped']);

        Http::fake([
            '*/nodes/*/lxc/100/status/start' => Http::response(['data' => 'UPID:success'], 200),
        ]);

        $response = $this->withToken($this->token)
            ->postJson('/api/v1/infrastructure/containers/100/start');

        $response->assertOk()
            ->assertJson(['success' => true]);
    });

    it('stops a container', function () {
        $container = LxcContainer::factory()->create(['vmid' => 100, 'status' => 'running']);

        Http::fake([
            '*/nodes/*/lxc/100/status/stop' => Http::response(['data' => 'UPID:success'], 200),
        ]);

        $response = $this->withToken($this->token)
            ->postJson('/api/v1/infrastructure/containers/100/stop');

        $response->assertOk();
    });

    it('returns 404 for non-existent container', function () {
        $response = $this->withToken($this->token)
            ->getJson('/api/v1/infrastructure/containers/999');

        $response->assertNotFound();
    });

    it('validates container action permissions', function () {
        $unauthorizedUser = User::factory()->create();
        $token = $unauthorizedUser->createToken('test')->plainTextToken;

        $container = LxcContainer::factory()->create(['vmid' => 100]);

        $response = $this->withToken($token)
            ->postJson('/api/v1/infrastructure/containers/100/start');

        $response->assertForbidden();
    });

    it('returns metrics for all containers', function () {
        LxcContainer::factory()->count(2)->create();

        Http::fake([
            '*/nodes/*/lxc/*/status/current' => Http::response([
                'data' => containerMetrics(),
            ], 200),
        ]);

        $response = $this->withToken($this->token)
            ->getJson('/api/v1/infrastructure/metrics');

        $response->assertOk()
            ->assertJsonStructure([
                'success',
                'data' => [
                    '*' => ['vmid', 'cpu_usage', 'memory', 'disk'],
                ],
            ]);
    });
});

describe('Proxmox Server API', function () {
    beforeEach(function () {
        $this->user = User::factory()->create();
        $this->token = $this->user->createToken('test')->plainTextToken;
    });

    it('lists all Proxmox servers', function () {
        ProxmoxServer::factory()->count(2)->create();

        $response = $this->withToken($this->token)
            ->getJson('/api/v1/infrastructure/servers');

        $response->assertOk()
            ->assertJsonCount(2, 'data');
    });

    it('retrieves server health status', function () {
        $server = ProxmoxServer::factory()->create();

        Http::fake([
            '*/nodes/*/status' => Http::response([
                'data' => [
                    'cpu' => 0.45,
                    'memory' => ['used' => 8000000000, 'total' => 16000000000],
                ],
            ], 200),
        ]);

        $response = $this->withToken($this->token)
            ->getJson("/api/v1/infrastructure/servers/{$server->id}/health");

        $response->assertOk()
            ->assertJsonStructure([
                'success',
                'data' => ['cpu', 'memory'],
            ]);
    });
});
