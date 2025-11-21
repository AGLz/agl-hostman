<?php

declare(strict_types=1);

use App\Services\ProxmoxApiClient;
use Illuminate\Support\Facades\Http;

describe('ProxmoxApiClient', function () {
    beforeEach(function () {
        $this->client = new ProxmoxApiClient(
            host: config('proxmox.host'),
            port: config('proxmox.port'),
            user: config('proxmox.user'),
            password: config('proxmox.password')
        );
    });

    it('authenticates and caches token', function () {
        // Arrange
        Http::fake([
            '*/api2/json/access/ticket' => Http::response([
                'data' => [
                    'ticket' => 'test-ticket',
                    'CSRFPreventionToken' => 'test-csrf',
                ],
            ], 200),
        ]);

        // Act: Make 3 requests
        $this->client->get('/nodes');
        $this->client->get('/pools');
        $this->client->get('/storage');

        // Assert: Should only authenticate once
        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/access/ticket');
        }, 1);
    });

    it('implements circuit breaker on consecutive failures', function () {
        // Arrange: Mock 5 failures
        Http::fake([
            '*/api2/json/*' => Http::sequence([
                Http::response([], 500), // Failure 1
                Http::response([], 500), // Failure 2
                Http::response([], 500), // Failure 3
                Http::response([], 500), // Failure 4
                Http::response([], 500), // Failure 5
                Http::response(['data' => 'success'], 200), // Should not reach
            ]),
        ]);

        // Act & Assert: After 5 failures, circuit should open
        for ($i = 0; $i < 5; $i++) {
            try {
                $this->client->get('/test');
            } catch (\Exception $e) {
                // Expected failures
            }
        }

        // Circuit should now be open
        expect(fn () => $this->client->get('/test'))
            ->toThrow(\Exception::class, 'Circuit breaker open');

        // Should have made only 5 requests (circuit breaker blocked 6th)
        Http::assertSentCount(5);
    });

    it('implements rate limiting', function () {
        // Arrange
        Http::fake([
            '*/api2/json/*' => Http::response(['data' => 'success'], 200),
        ]);

        $startTime = microtime(true);

        // Act: Make 150 requests (limit is 100/min = 600ms between bursts)
        for ($i = 0; $i < 150; $i++) {
            $this->client->get('/test');
        }

        $elapsedTime = microtime(true) - $startTime;

        // Assert: Should take at least 600ms due to rate limiting
        expect($elapsedTime)->toBeGreaterThan(0.6);
    });

    it('retries failed requests with exponential backoff', function () {
        // Arrange: Mock 2 failures then success
        Http::fake([
            '*/api2/json/*' => Http::sequence([
                Http::response([], 503), // Failure 1 (retry after 100ms)
                Http::response([], 503), // Failure 2 (retry after 200ms)
                Http::response(['data' => 'success'], 200), // Success
            ]),
        ]);

        $startTime = microtime(true);

        // Act
        $response = $this->client->get('/test');

        $elapsedTime = (microtime(true) - $startTime) * 1000;

        // Assert: Should have retried and eventually succeeded
        expect($response['data'])->toBe('success')
            ->and($elapsedTime)->toBeGreaterThan(300); // At least 300ms for backoff

        Http::assertSentCount(3);
    });

    it('parses container list correctly', function () {
        // Arrange
        Http::fake([
            '*/api2/json/nodes/*/lxc' => Http::response(mockProxmoxResponse([
                ['vmid' => '100', 'name' => 'ct100', 'status' => 'running'],
                ['vmid' => '101', 'name' => 'ct101', 'status' => 'stopped'],
            ])),
        ]);

        // Act
        $containers = $this->client->getContainers('aglsrv1');

        // Assert
        expect($containers)->toHaveCount(2)
            ->and($containers[0]['vmid'])->toBe('100')
            ->and($containers[0]['status'])->toBe('running')
            ->and($containers[1]['status'])->toBe('stopped');
    });
});
