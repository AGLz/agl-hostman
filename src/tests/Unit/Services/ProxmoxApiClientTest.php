<?php

declare(strict_types=1);

use App\Services\ProxmoxApiClient;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

describe('ProxmoxApiClient', function () {
    beforeEach(function () {
        $this->client = new ProxmoxApiClient;
        $this->baseUrl = 'https://test.proxmox.local:8006/api2/json';

        // Mock successful authentication
        Http::fake([
            '*/access/ticket' => Http::response([
                'data' => [
                    'ticket' => 'test-ticket',
                    'CSRFPreventionToken' => 'test-csrf-token',
                ],
            ], 200),
        ]);
    });

    it('authenticates successfully with valid credentials', function () {
        Http::fake([
            '*/access/ticket' => Http::response([
                'data' => [
                    'ticket' => 'valid-ticket',
                    'CSRFPreventionToken' => 'valid-csrf',
                ],
            ], 200),
        ]);

        $result = $this->client->authenticate('test@pam', 'password');

        expect($result)->toBeTrue()
            ->and($this->client->isAuthenticated())->toBeTrue();

        Http::assertSent(function ($request) {
            return $request->url() === $this->baseUrl.'/access/ticket'
                && $request->data()['username'] === 'test@pam';
        });
    });

    it('fails authentication with invalid credentials', function () {
        Http::fake([
            '*/access/ticket' => Http::response(['errors' => 'Invalid credentials'], 401),
        ]);

        $result = $this->client->authenticate('wrong@pam', 'wrong-pass');

        expect($result)->toBeFalse()
            ->and($this->client->isAuthenticated())->toBeFalse();
    });

    it('retrieves list of containers successfully', function () {
        $mockContainers = [
            ['vmid' => 100, 'name' => 'test-ct', 'status' => 'running'],
            ['vmid' => 101, 'name' => 'dev-ct', 'status' => 'stopped'],
        ];

        Http::fake([
            '*/nodes/*/lxc' => Http::response(['data' => $mockContainers], 200),
        ]);

        $containers = $this->client->getContainers('node1');

        expect($containers)
            ->toBeArray()
            ->toHaveCount(2)
            ->and($containers[0])
            ->toHaveKey('vmid', 100)
            ->toHaveKey('status', 'running');
    });

    it('handles API errors gracefully', function () {
        Http::fake([
            '*/nodes/*/lxc' => Http::response(['errors' => 'Server error'], 500),
        ]);

        $containers = $this->client->getContainers('node1');

        expect($containers)->toBeArray()->toBeEmpty();
    });

    it('gets container status by VMID', function () {
        Http::fake([
            '*/nodes/*/lxc/100/status/current' => Http::response([
                'data' => [
                    'status' => 'running',
                    'cpu' => 0.45,
                    'mem' => 1073741824,
                    'maxmem' => 2147483648,
                ],
            ], 200),
        ]);

        $status = $this->client->getContainerStatus('node1', 100);

        expect($status)
            ->toBeArray()
            ->toHaveKey('status', 'running')
            ->toHaveKey('cpu')
            ->and($status['cpu'])->toBe(0.45);
    });

    it('starts a container successfully', function () {
        Http::fake([
            '*/nodes/*/lxc/100/status/start' => Http::response(['data' => 'UPID:success'], 200),
        ]);

        $result = $this->client->startContainer('node1', 100);

        expect($result)->toBeTrue();

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/status/start')
                && $request->method() === 'POST';
        });
    });

    it('stops a container successfully', function () {
        Http::fake([
            '*/nodes/*/lxc/100/status/stop' => Http::response(['data' => 'UPID:success'], 200),
        ]);

        $result = $this->client->stopContainer('node1', 100);

        expect($result)->toBeTrue();
    });

    it('retrieves container configuration', function () {
        $mockConfig = [
            'hostname' => 'test-container',
            'memory' => 2048,
            'cores' => 2,
            'net0' => 'name=eth0,bridge=vmbr0',
        ];

        Http::fake([
            '*/nodes/*/lxc/100/config' => Http::response(['data' => $mockConfig], 200),
        ]);

        $config = $this->client->getContainerConfig('node1', 100);

        expect($config)
            ->toHaveKey('hostname', 'test-container')
            ->toHaveKey('memory', 2048)
            ->toHaveKey('cores', 2);
    });

    it('retries on network timeout', function () {
        Http::fake([
            '*/nodes/*/lxc' => Http::sequence()
                ->push(['errors' => 'Timeout'], 408)
                ->push(['data' => []], 200),
        ]);

        $containers = $this->client->getContainers('node1');

        expect($containers)->toBeArray();

        // Should have made 2 requests (1 failed + 1 retry)
        Http::assertSentCount(2);
    });

    it('caches API responses when enabled', function () {
        Http::fake([
            '*/nodes/*/lxc' => Http::response(['data' => [['vmid' => 100]]], 200),
        ]);

        $this->client->enableCache();

        // First call
        $containers1 = $this->client->getContainers('node1');
        // Second call (should use cache)
        $containers2 = $this->client->getContainers('node1');

        expect($containers1)->toEqual($containers2);

        // Should only make 1 HTTP request due to caching
        Http::assertSentCount(1);
    });

    it('validates node existence before operations', function () {
        Http::fake([
            '*/nodes' => Http::response(['data' => [['node' => 'node1'], ['node' => 'node2']]], 200),
        ]);

        $result = $this->client->validateNode('node1');

        expect($result)->toBeTrue();

        $invalid = $this->client->validateNode('non-existent');

        expect($invalid)->toBeFalse();
    });

    it('logs errors for debugging', function () {
        Log::spy();

        Http::fake([
            '*/nodes/*/lxc' => Http::response(['errors' => 'Critical error'], 500),
        ]);

        $this->client->getContainers('node1');

        Log::shouldHaveReceived('error')
            ->once()
            ->with(\Mockery::on(function ($message) {
                return str_contains($message, 'Critical error');
            }));
    });
});
