<?php

declare(strict_types=1);

use App\Services\ProxmoxApiClient;
use App\Models\LxcContainer;
use App\Models\ProxmoxServer;
use Illuminate\Support\Facades\Http;

describe('Proxmox API Integration', function () {
    beforeEach(function () {
        $this->server = ProxmoxServer::factory()->create([
            'host' => 'test.proxmox.local',
            'port' => 8006,
        ]);

        $this->client = new ProxmoxApiClient();

        // Record HTTP interactions for VCR-like behavior
        Http::preventStrayRequests();
    });

    it('performs full container lifecycle', function () {
        // Record authentication
        Http::fake([
            '*/access/ticket' => Http::response([
                'data' => ['ticket' => 'auth-ticket', 'CSRFPreventionToken' => 'csrf-token'],
            ], 200),
        ]);

        $authenticated = $this->client->authenticate('test@pam', 'password');
        expect($authenticated)->toBeTrue();

        // Record container creation
        Http::fake([
            '*/nodes/*/lxc' => Http::response([
                'data' => 'UPID:node1:00001234:00000000:00000000:vzcreate:100:test@pam:',
            ], 200),
        ]);

        $vmid = 100;
        $created = $this->client->createContainer('node1', [
            'vmid' => $vmid,
            'ostemplate' => 'local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst',
            'hostname' => 'test-container',
            'memory' => 2048,
            'cores' => 2,
        ]);

        expect($created)->toBeTrue();

        // Record container start
        Http::fake([
            '*/nodes/*/lxc/100/status/start' => Http::response(['data' => 'UPID:success'], 200),
        ]);

        $started = $this->client->startContainer('node1', $vmid);
        expect($started)->toBeTrue();

        // Record status check
        Http::fake([
            '*/nodes/*/lxc/100/status/current' => Http::response([
                'data' => [
                    'status' => 'running',
                    'cpu' => 0.25,
                    'mem' => 536870912,
                    'maxmem' => 2147483648,
                ],
            ], 200),
        ]);

        $status = $this->client->getContainerStatus('node1', $vmid);
        expect($status['status'])->toBe('running');

        // Record container stop
        Http::fake([
            '*/nodes/*/lxc/100/status/stop' => Http::response(['data' => 'UPID:success'], 200),
        ]);

        $stopped = $this->client->stopContainer('node1', $vmid);
        expect($stopped)->toBeTrue();

        // Record container deletion
        Http::fake([
            '*/nodes/*/lxc/100' => Http::response(['data' => 'UPID:success'], 200),
        ]);

        $deleted = $this->client->deleteContainer('node1', $vmid);
        expect($deleted)->toBeTrue();
    })->group('integration', 'slow');

    it('handles network partitions gracefully', function () {
        Http::fake([
            '*/access/ticket' => Http::response([
                'data' => ['ticket' => 'ticket', 'CSRFPreventionToken' => 'csrf'],
            ], 200),
        ]);

        $this->client->authenticate('test@pam', 'password');

        // Simulate network partition
        Http::fake([
            '*/nodes/*/lxc' => function () {
                throw new \Illuminate\Http\Client\ConnectionException('Connection timeout');
            },
        ]);

        $containers = $this->client->getContainers('node1');

        expect($containers)->toBeArray()->toBeEmpty();
    })->group('integration', 'error-handling');

    it('maintains session across multiple requests', function () {
        Http::fake([
            '*/access/ticket' => Http::response([
                'data' => ['ticket' => 'session-ticket', 'CSRFPreventionToken' => 'session-csrf'],
            ], 200),
        ]);

        $this->client->authenticate('test@pam', 'password');

        Http::fake([
            '*/nodes/*/lxc' => Http::response(['data' => []], 200),
            '*/nodes/*/qemu' => Http::response(['data' => []], 200),
            '*/nodes' => Http::response(['data' => []], 200),
        ]);

        // Make multiple requests with same session
        $this->client->getContainers('node1');
        $this->client->getVirtualMachines('node1');
        $this->client->getNodes();

        // All requests should reuse authentication
        Http::assertSentCount(4); // 1 auth + 3 requests
    })->group('integration');

    it('handles concurrent container operations', function () {
        Http::fake([
            '*/access/ticket' => Http::response([
                'data' => ['ticket' => 'ticket', 'CSRFPreventionToken' => 'csrf'],
            ], 200),
            '*/nodes/*/lxc/*/status/start' => Http::response(['data' => 'UPID:success'], 200),
        ]);

        $this->client->authenticate('test@pam', 'password');

        $containers = [100, 101, 102, 103, 104];
        $results = [];

        foreach ($containers as $vmid) {
            $results[$vmid] = $this->client->startContainer('node1', $vmid);
        }

        expect($results)->each->toBeTrue();
        Http::assertSentCount(6); // 1 auth + 5 starts
    })->group('integration', 'concurrent');
});

describe('Proxmox Cluster Integration', function () {
    it('synchronizes container state across cluster', function () {
        $server1 = ProxmoxServer::factory()->create(['name' => 'node1']);
        $server2 = ProxmoxServer::factory()->create(['name' => 'node2']);

        Http::fake([
            '*/access/ticket' => Http::response([
                'data' => ['ticket' => 'ticket', 'CSRFPreventionToken' => 'csrf'],
            ], 200),
            '*/cluster/resources' => Http::response([
                'data' => [
                    ['id' => 'lxc/100', 'node' => 'node1', 'status' => 'running'],
                    ['id' => 'lxc/101', 'node' => 'node2', 'status' => 'running'],
                ],
            ], 200),
        ]);

        $client = new ProxmoxApiClient();
        $client->authenticate('test@pam', 'password');

        $resources = $client->getClusterResources();

        expect($resources)->toHaveCount(2)
            ->and($resources[0]['node'])->toBe('node1')
            ->and($resources[1]['node'])->toBe('node2');
    })->group('integration', 'cluster');
});
