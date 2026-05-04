<?php

declare(strict_types=1);

use App\Models\User;
use App\Services\Broadcasting\WebSocketBroadcastService;
use App\Services\Container\ContainerLifecycleService;
use App\Services\ProxmoxApiClient;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;

uses(RefreshDatabase::class);

describe('Container Lifecycle Operations', function () {
    beforeEach(function () {
        $this->user = User::factory()->create();

        // Mock WebSocketBroadcastService
        $this->broadcast = Mockery::mock(WebSocketBroadcastService::class);
        $this->broadcast->shouldReceive('broadcastContainerStatus')->andReturn(null)->byDefault();
        $this->app->instance(WebSocketBroadcastService::class, $this->broadcast);

        // Create ProxmoxApiClient with test credentials (will use Http::fake())
        $this->proxmox = new ProxmoxApiClient(
            host: '192.168.0.245',
            port: 8006,
            username: 'root@pam',
            password: 'test-password'
        );

        // Mock authentication response
        Http::fake([
            '*/access/ticket' => Http::response(mockProxmoxResponse([
                'ticket' => 'PVE:test-ticket',
                'CSRFPreventionToken' => 'test-csrf-token',
            ]), 200),
        ]);

        // Authenticate the client for tests
        $this->proxmox->authenticate();

        // Bind to container so service uses our client
        $this->app->instance(ProxmoxApiClient::class, $this->proxmox);

        $this->service = app(ContainerLifecycleService::class);
    });

    describe('Operation 1: Create Container', function () {
        it('creates a new container successfully', function () {
            Http::fake([
                '*/nodes/AGLSRV1/lxc' => Http::response(mockProxmoxResponse([
                    'UPID:AGLSRV1:00001234:00005678:12345678:vzcreate:199:root@pam:',
                ]), 200),
            ]);

            $result = $this->service->createContainer(
                node: 'AGLSRV1',
                vmid: 199,
                config: [
                    'hostname' => 'test-container',
                    'cores' => 4,
                    'memory' => 4096,
                ]
            );

            expect($result['success'])->toBeTrue()
                ->and($result['vmid'])->toBe(199)
                ->and($result)->toHaveKey('task');

            Http::assertSent(function ($request) {
                return $request->url() === 'https://192.168.0.245:8006/api2/json/nodes/AGLSRV1/lxc'
                    && $request['vmid'] === 199
                    && $request['hostname'] === 'test-container';
            });
        });

        it('validates required configuration fields', function () {
            $result = $this->service->createContainer(
                node: 'AGLSRV1',
                vmid: 199,
                config: [] // Missing hostname
            );

            expect($result['success'])->toBeFalse()
                ->and($result['error'])->toContain('hostname');
        });

        it('validates hostname format', function () {
            $result = $this->service->createContainer(
                node: 'AGLSRV1',
                vmid: 199,
                config: ['hostname' => 'Invalid_Hostname!']
            );

            expect($result['success'])->toBeFalse()
                ->and($result['error'])->toContain('hostname format');
        });
    });

    describe('Operation 2: Clone Container', function () {
        it('clones container successfully', function () {
            Http::fake([
                '*/nodes/AGLSRV1/lxc/179/clone' => Http::response(mockProxmoxResponse([
                    'UPID:AGLSRV1:00001234:00005678:12345678:vzclone:200:root@pam:',
                ]), 200),
            ]);

            $result = $this->service->cloneContainer(
                node: 'AGLSRV1',
                vmid: 179,
                newVmid: 200,
                options: ['hostname' => 'cloned-container']
            );

            expect($result['success'])->toBeTrue()
                ->and($result['source_vmid'])->toBe(179)
                ->and($result['target_vmid'])->toBe(200);
        });
    });

    describe('Operation 3: Migrate Container', function () {
        it('migrates container between nodes', function () {
            Http::fake([
                '*/nodes/AGLSRV1/lxc/179/migrate' => Http::response(mockProxmoxResponse([
                    'UPID:AGLSRV1:00001234:00005678:12345678:vzmigrate:179:root@pam:',
                ]), 200),
            ]);

            $result = $this->service->migrateContainer(
                sourceNode: 'AGLSRV1',
                targetNode: 'AGLSRV6',
                vmid: 179,
                options: ['online' => 0]
            );

            expect($result['success'])->toBeTrue()
                ->and($result['source_node'])->toBe('AGLSRV1')
                ->and($result['target_node'])->toBe('AGLSRV6');
        });
    });

    describe('Operation 4: Backup Container', function () {
        it('creates container backup', function () {
            Http::fake([
                '*/nodes/AGLSRV1/vzdump' => Http::response(mockProxmoxResponse([
                    'UPID:AGLSRV1:00001234:00005678:12345678:vzdump:179:root@pam:',
                ]), 200),
            ]);

            $result = $this->service->backupContainer(
                node: 'AGLSRV1',
                vmid: 179,
                options: [
                    'mode' => 'snapshot',
                    'compress' => 'zstd',
                    'storage' => 'local',
                ]
            );

            expect($result['success'])->toBeTrue()
                ->and($result['vmid'])->toBe(179)
                ->and($result['storage'])->toBe('local');
        });
    });

    describe('Operation 5: Restore Container', function () {
        it('restores container from backup', function () {
            Http::fake([
                '*/nodes/AGLSRV1/lxc' => Http::response(mockProxmoxResponse([
                    'UPID:AGLSRV1:00001234:00005678:12345678:vzrestore:199:root@pam:',
                ]), 200),
            ]);

            $result = $this->service->restoreContainer(
                node: 'AGLSRV1',
                storage: 'local',
                volume: 'vzdump-lxc-179-2025_01_11-00_00_00.tar.zst',
                vmid: 199
            );

            expect($result['success'])->toBeTrue()
                ->and($result['vmid'])->toBe(199)
                ->and($result['volume'])->toContain('vzdump-lxc-179');
        });
    });

    describe('Operation 6: Snapshot Container', function () {
        it('creates container snapshot', function () {
            Http::fake([
                '*/nodes/AGLSRV1/lxc/179/snapshot' => Http::response(mockProxmoxResponse([]), 200),
            ]);

            $result = $this->service->snapshotContainer(
                node: 'AGLSRV1',
                vmid: 179,
                snapname: 'pre-update-snapshot',
                options: ['description' => 'Before major update']
            );

            expect($result['success'])->toBeTrue()
                ->and($result['snapname'])->toBe('pre-update-snapshot');
        });

        it('lists container snapshots', function () {
            Http::fake([
                '*/nodes/AGLSRV1/lxc/179/snapshot' => Http::response(mockProxmoxResponse([
                    ['name' => 'pre-update-snapshot', 'snaptime' => 1736553600],
                    ['name' => 'before-migration', 'snaptime' => 1736467200],
                ]), 200),
            ]);

            $result = $this->service->listSnapshots('AGLSRV1', 179);

            expect($result['success'])->toBeTrue()
                ->and($result['snapshots'])->toHaveCount(2);
        });
    });

    describe('Operation 7: Rollback Container', function () {
        it('rolls back container to snapshot', function () {
            Http::fake([
                '*/nodes/AGLSRV1/lxc/179/snapshot/pre-update-snapshot/rollback' => Http::response(
                    mockProxmoxResponse(['UPID:AGLSRV1:00001234:00005678:12345678:vzrollback:179:root@pam:']),
                    200
                ),
            ]);

            $result = $this->service->rollbackContainer(
                node: 'AGLSRV1',
                vmid: 179,
                snapname: 'pre-update-snapshot'
            );

            expect($result['success'])->toBeTrue()
                ->and($result['snapname'])->toBe('pre-update-snapshot');
        });
    });

    describe('API Integration', function () {
        it('creates container via API endpoint', function () {
            Http::fake([
                '*/nodes/AGLSRV1/lxc' => Http::response(mockProxmoxResponse(['task' => 'UPID:...']), 200),
            ]);

            $response = $this->actingAs($this->user)
                ->postJson('/api/containers/create', [
                    'node' => 'AGLSRV1',
                    'vmid' => 199,
                    'hostname' => 'api-test-container',
                    'cores' => 2,
                    'memory' => 2048,
                ]);

            $response->assertStatus(201)
                ->assertJson(['success' => true, 'vmid' => 199]);
        });

        it('validates API request parameters', function () {
            $response = $this->actingAs($this->user)
                ->postJson('/api/containers/create', [
                    'node' => 'AGLSRV1',
                    // Missing vmid and hostname
                ]);

            $response->assertStatus(422)
                ->assertJsonValidationErrors(['vmid', 'hostname']);
        });

        it('requires authentication for lifecycle operations', function () {
            $response = $this->postJson('/api/containers/create', [
                'node' => 'AGLSRV1',
                'vmid' => 199,
                'hostname' => 'test',
            ]);

            $response->assertStatus(401);
        });
    });

    describe('Error Handling', function () {
        it('handles Proxmox API errors gracefully', function () {
            Http::fake([
                '*/nodes/AGLSRV1/lxc' => Http::response(['errors' => 'VM already exists'], 500),
            ]);

            $result = $this->service->createContainer(
                node: 'AGLSRV1',
                vmid: 179, // Already exists
                config: ['hostname' => 'duplicate']
            );

            expect($result['success'])->toBeFalse()
                ->and($result)->toHaveKey('error');
        });
    });
});
