<?php

namespace Database\Seeders;

use App\Models\PhysicalLocation;
use Illuminate\Database\Seeder;

class PhysicalLocationsSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * Seed the 5 physical locations from .env configuration:
     * - AGLHQ11: Headquarters (Windows WSL2)
     * - AGLSRV1: Primary datacenter (Proxmox host)
     * - AGLSRV6: Secondary datacenter (Proxmox host)
     * - CT179: Development container (agldv03)
     * - CT183: Archon AI Command Center (agldv04)
     */
    public function run(): void
    {
        $locations = [
            [
                'code' => 'AGLHQ11',
                'name' => 'AGL Headquarters - AGLHQ11',
                'description' => 'Main headquarters office with WSL2 development environment. Remote access via Tailscale only.',
                'address' => 'Office Location',
                'city' => 'City',
                'state' => 'ST',
                'country' => 'US',
                'latitude' => null,
                'longitude' => null,
                'type' => 'headquarters',
                'ip_range' => '100.75.205.122/32', // Tailscale IP
                'metadata' => [
                    'tailscale_ip' => '100.75.205.122',
                    'networks' => ['tailscale'],
                    'environment' => 'wsl2',
                    'limitations' => ['no_wireguard', 'no_lan', 'no_docker'],
                    'typical_use' => 'Remote work, Windows-based development',
                ],
                'is_active' => true,
            ],
            [
                'code' => 'AGLSRV1',
                'name' => 'Primary Datacenter - AGLSRV1',
                'description' => 'Main Proxmox VE host with 68 containers/VMs. Triple network stack with LAN, WireGuard, and Tailscale.',
                'address' => 'Datacenter Location',
                'city' => 'City',
                'state' => 'ST',
                'country' => 'US',
                'latitude' => null,
                'longitude' => null,
                'type' => 'datacenter',
                'ip_range' => '192.168.0.245/32,10.6.0.5/32,100.107.113.33/32', // LAN, WireGuard, Tailscale
                'metadata' => [
                    'lan_ip' => '192.168.0.245',
                    'wireguard_ip' => '10.6.0.5',
                    'tailscale_ip' => '100.107.113.33',
                    'networks' => ['lan', 'wireguard', 'tailscale'],
                    'proxmox_version' => '8.x',
                    'containers' => 68,
                    'role' => 'primary_host',
                    'connection_priority' => ['wireguard', 'lan', 'tailscale'],
                ],
                'is_active' => true,
            ],
            [
                'code' => 'AGLSRV6',
                'name' => 'Secondary Datacenter - AGLSRV6',
                'description' => 'Secondary Proxmox VE host for remote operations. Accessible via WireGuard mesh.',
                'address' => 'Remote Datacenter Location',
                'city' => 'City',
                'state' => 'ST',
                'country' => 'US',
                'latitude' => null,
                'longitude' => null,
                'type' => 'datacenter',
                'ip_range' => '10.6.0.12/32', // WireGuard only
                'metadata' => [
                    'wireguard_ip' => '10.6.0.12',
                    'networks' => ['wireguard'],
                    'proxmox_version' => '8.x',
                    'role' => 'secondary_host',
                    'connection_priority' => ['wireguard'],
                ],
                'is_active' => true,
            ],
            [
                'code' => 'CT179',
                'name' => 'Development Container - CT179 (agldv03)',
                'description' => 'Full-stack development container with 48GB RAM, Docker, and triple network stack. Primary development environment.',
                'address' => 'Virtual Container on AGLSRV1',
                'city' => 'City',
                'state' => 'ST',
                'country' => 'US',
                'latitude' => null,
                'longitude' => null,
                'type' => 'container',
                'ip_range' => '192.168.0.179/32,10.6.0.8/32,100.94.221.87/32', // LAN, WireGuard, Tailscale
                'metadata' => [
                    'lan_ip' => '192.168.0.179',
                    'wireguard_ip' => '10.6.0.8',
                    'tailscale_ip' => '100.94.221.87',
                    'networks' => ['lan', 'wireguard', 'tailscale'],
                    'ram' => '48GB',
                    'docker_enabled' => true,
                    'role' => 'primary_development',
                    'connection_priority' => ['wireguard', 'lan', 'tailscale'],
                    'best_for' => 'High-performance local operations, WireGuard mesh access',
                ],
                'is_active' => true,
            ],
            [
                'code' => 'CT183',
                'name' => 'Archon AI Command Center - CT183 (agldv04)',
                'description' => 'Archon MCP server providing task management, knowledge base, and RAG capabilities. API endpoint for AI-driven infrastructure management.',
                'address' => 'Virtual Container on AGLSRV1',
                'city' => 'City',
                'state' => 'ST',
                'country' => 'US',
                'latitude' => null,
                'longitude' => null,
                'type' => 'container',
                'ip_range' => '192.168.0.183/32,10.6.0.21/32,100.80.30.59/32', // LAN, WireGuard, Tailscale
                'metadata' => [
                    'lan_ip' => '192.168.0.183',
                    'wireguard_ip' => '10.6.0.21',
                    'tailscale_ip' => '100.80.30.59',
                    'networks' => ['lan', 'wireguard', 'tailscale'],
                    'public_dns' => 'archon.aglz.io',
                    'mcp_port' => 8051,
                    'web_port' => 3737,
                    'role' => 'ai_command_center',
                    'connection_priority' => ['wireguard', 'lan', 'tailscale'],
                    'services' => ['archon-mcp', 'archon-web', 'rag-engine'],
                ],
                'is_active' => true,
            ],
        ];

        foreach ($locations as $location) {
            PhysicalLocation::updateOrCreate(
                ['code' => $location['code']],
                $location
            );
        }

        $this->command->info('Physical locations seeded successfully!');
        $this->command->info('Created 5 locations: AGLHQ11, AGLSRV1, AGLSRV6, CT179, CT183');
    }
}
