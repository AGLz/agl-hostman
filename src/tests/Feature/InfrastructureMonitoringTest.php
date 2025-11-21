<?php

declare(strict_types=1);

use App\Models\User;
use App\Models\ProxmoxServer;
use Illuminate\Support\Facades\Http;

describe('Infrastructure Monitoring', function () {
    beforeEach(function () {
        $this->user = User::factory()->create(['role' => 'admin']);
    });

    it('fetches server list successfully', function () {
        // Arrange
        ProxmoxServer::factory()->count(3)->create();

        // Act
        $response = $this->actingAs($this->user)
            ->get('/api/infrastructure/servers');

        // Assert
        $response->assertOk()
            ->assertJsonCount(3, 'data')
            ->assertJsonStructure([
                'data' => [
                    '*' => ['id', 'code', 'name', 'status', 'cpu_usage', 'memory_usage'],
                ],
            ]);
    });

    it('fetches real-time server metrics', function () {
        // Arrange
        $server = ProxmoxServer::factory()->create(['code' => 'AGLSRV1']);

        Http::fake([
            '*/api2/json/nodes/AGLSRV1/status' => Http::response(mockProxmoxResponse([
                'cpu' => 0.45,
                'memory' => ['used' => 32 * 1024 * 1024 * 1024, 'total' => 128 * 1024 * 1024 * 1024],
                'uptime' => 864000,
            ])),
        ]);

        // Act
        $response = $this->actingAs($this->user)
            ->get("/api/infrastructure/servers/AGLSRV1/metrics");

        // Assert
        $response->assertOk()
            ->assertJson([
                'cpu_usage' => 45.0,
                'memory_usage_percent' => 25.0,
                'uptime_hours' => 240,
            ]);
    });

    it('lists containers for a server', function () {
        // Arrange
        Http::fake([
            '*/api2/json/nodes/*/lxc' => Http::response(mockProxmoxResponse([
                ['vmid' => '179', 'name' => 'CT179', 'status' => 'running', 'maxmem' => 48 * 1024 * 1024 * 1024],
                ['vmid' => '180', 'name' => 'CT180', 'status' => 'running', 'maxmem' => 16 * 1024 * 1024 * 1024],
            ])),
        ]);

        // Act
        $response = $this->actingAs($this->user)
            ->get('/api/infrastructure/servers/AGLSRV1/containers');

        // Assert
        $response->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.vmid', '179')
            ->assertJsonPath('data.1.name', 'CT180');
    });

    it('performs health check and caches result', function () {
        // Arrange
        Http::fake([
            '*/api2/json/nodes/*/status' => Http::response(mockProxmoxResponse(['status' => 'online']), 200),
        ]);

        // Act: First request
        $response1 = $this->actingAs($this->user)
            ->get('/api/infrastructure/health');

        // Act: Second request (should be cached)
        $response2 = $this->actingAs($this->user)
            ->get('/api/infrastructure/health');

        // Assert: Only 1 HTTP request made (second was cached)
        Http::assertSentCount(1);

        $response1->assertOk();
        $response2->assertOk();
    });

    it('returns 404 for non-existent server', function () {
        // Act & Assert
        $this->actingAs($this->user)
            ->get('/api/infrastructure/servers/INVALID')
            ->assertNotFound();
    });

    it('rate limits infrastructure API calls', function () {
        // Act: Make 101 requests (limit is 100/min)
        for ($i = 0; $i < 101; $i++) {
            $response = $this->actingAs($this->user)
                ->get('/api/infrastructure/servers');
        }

        // Assert: Last request should be rate limited
        $response->assertStatus(429);
    });
});
