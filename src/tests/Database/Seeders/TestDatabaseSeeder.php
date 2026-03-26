<?php

declare(strict_types=1);

namespace Tests\Database\Seeders;

use App\Models\ContainerHealthLog;
use App\Models\LxcContainer;
use App\Models\ProxmoxServer;
use App\Models\User;
use Illuminate\Database\Seeder;

class TestDatabaseSeeder extends Seeder
{
    /**
     * Seed the test database with realistic data
     */
    public function run(): void
    {
        // Create admin user
        $admin = User::factory()->create([
            'name' => 'Test Admin',
            'email' => 'admin@test.local',
        ]);

        // Create regular users
        $users = User::factory()->count(5)->create();

        // Create Proxmox servers
        $server1 = ProxmoxServer::factory()
            ->active()
            ->clusterMember('production')
            ->create(['name' => 'pve-node1']);

        $server2 = ProxmoxServer::factory()
            ->active()
            ->clusterMember('production')
            ->create(['name' => 'pve-node2']);

        $server3 = ProxmoxServer::factory()
            ->standalone()
            ->create(['name' => 'pve-dev']);

        // Create containers for server1 (production)
        LxcContainer::factory()
            ->count(20)
            ->running()
            ->create(['proxmox_server_id' => $server1->id]);

        LxcContainer::factory()
            ->count(5)
            ->stopped()
            ->create(['proxmox_server_id' => $server1->id]);

        // Create containers for server2 (production)
        LxcContainer::factory()
            ->count(15)
            ->running()
            ->create(['proxmox_server_id' => $server2->id]);

        LxcContainer::factory()
            ->count(10)
            ->stopped()
            ->create(['proxmox_server_id' => $server2->id]);

        // Create development containers
        LxcContainer::factory()
            ->count(10)
            ->running()
            ->create(['proxmox_server_id' => $server3->id]);

        // Create some templates
        LxcContainer::factory()
            ->count(3)
            ->template()
            ->create(['proxmox_server_id' => $server1->id]);

        // Create high resource containers
        LxcContainer::factory()
            ->count(5)
            ->highResource()
            ->running()
            ->create(['proxmox_server_id' => $server1->id]);

        // Create protected containers
        LxcContainer::factory()
            ->count(3)
            ->protected()
            ->running()
            ->create(['proxmox_server_id' => $server2->id]);

        // Create health logs for some containers
        $containers = LxcContainer::running()->take(10)->get();
        foreach ($containers as $container) {
            ContainerHealthLog::factory()
                ->count(50)
                ->create(['lxc_container_id' => $container->id]);
        }
    }
}
