<?php

declare(strict_types=1);

use App\Models\LxcContainer;
use App\Models\ProxmoxServer;

describe('LxcContainer Model', function () {
    it('has correct fillable attributes', function () {
        $container = new LxcContainer;

        expect($container->getFillable())->toContain('vmid', 'name', 'status', 'proxmox_server_id');
    });

    it('belongs to a Proxmox server', function () {
        $server = ProxmoxServer::factory()->create();
        $container = LxcContainer::factory()->create(['proxmox_server_id' => $server->id]);

        expect($container->server)->toBeInstanceOf(ProxmoxServer::class)
            ->and($container->server->id)->toBe($server->id);
    });

    it('casts attributes correctly', function () {
        $container = LxcContainer::factory()->create([
            'vmid' => '100',
            'is_active' => 1,
            'created_at' => now(),
        ]);

        expect($container->vmid)->toBeInt()
            ->and($container->is_active)->toBeBool()
            ->and($container->created_at)->toBeInstanceOf(\Illuminate\Support\Carbon::class);
    });

    it('has health logs relationship', function () {
        $container = LxcContainer::factory()->create();

        expect($container->healthLogs())->toBeInstanceOf(\Illuminate\Database\Eloquent\Relations\HasMany::class);
    });

    it('scopes running containers', function () {
        LxcContainer::factory()->create(['status' => 'running']);
        LxcContainer::factory()->create(['status' => 'stopped']);
        LxcContainer::factory()->create(['status' => 'running']);

        $running = LxcContainer::running()->get();

        expect($running)->toHaveCount(2)
            ->each->status->toBe('running');
    });

    it('determines if container is running', function () {
        $running = LxcContainer::factory()->create(['status' => 'running']);
        $stopped = LxcContainer::factory()->create(['status' => 'stopped']);

        expect($running->isRunning())->toBeTrue()
            ->and($stopped->isRunning())->toBeFalse();
    });

    it('generates unique VMID automatically', function () {
        $container1 = LxcContainer::factory()->create();
        $container2 = LxcContainer::factory()->create();

        expect($container1->vmid)->not->toBe($container2->vmid)
            ->and($container1->vmid)->toBeInt()
            ->and($container2->vmid)->toBeInt();
    });
});
