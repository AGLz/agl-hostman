<?php

namespace Database\Seeders;

use App\Models\PhysicalLocation;
use Illuminate\Database\Seeder;

class PhysicalLocationSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $locations = [
            [
                'code' => 'AGLHQ',
                'name' => 'AGL Headquarters',
                'description' => 'Sede principal da AGL',
                'type' => 'headquarters',
                'city' => 'São Paulo',
                'state' => 'SP',
                'country' => 'BR',
                'ip_range' => '192.168.0.0/24',
                'metadata' => [
                    'main_server' => 'AGLSRV1',
                    'backup_server' => 'AGLSRV6',
                ],
            ],
            [
                'code' => 'AGLSRV1',
                'name' => 'AGL Server 1 - Main Proxmox',
                'description' => 'Servidor Proxmox principal com 68 containers',
                'type' => 'datacenter',
                'ip_range' => '192.168.0.245/32',
                'metadata' => [
                    'containers' => 68,
                    'ram' => '128GB',
                    'storage' => '4TB',
                ],
            ],
            [
                'code' => 'AGLSRV2',
                'name' => 'AGL Server 2',
                'description' => 'Servidor secundário',
                'type' => 'datacenter',
                'ip_range' => '192.168.0.246/32',
            ],
            [
                'code' => 'AGLSRV3',
                'name' => 'AGL Server 3',
                'description' => 'Servidor de desenvolvimento',
                'type' => 'datacenter',
                'ip_range' => '192.168.0.247/32',
            ],
            [
                'code' => 'AGLSRV4',
                'name' => 'AGL Server 4',
                'description' => 'Servidor de testes',
                'type' => 'datacenter',
                'ip_range' => '192.168.0.248/32',
            ],
            [
                'code' => 'AGLSRV5',
                'name' => 'AGL Server 5',
                'description' => 'Servidor de backup',
                'type' => 'datacenter',
                'ip_range' => '192.168.0.249/32',
            ],
            [
                'code' => 'AGLSRV6',
                'name' => 'AGL Server 6 - Remote Proxmox',
                'description' => 'Servidor Proxmox remoto via WireGuard',
                'type' => 'datacenter',
                'ip_range' => '10.6.0.12/32',
                'metadata' => [
                    'wireguard' => true,
                    'location' => 'remote',
                ],
            ],
            [
                'code' => 'CT179',
                'name' => 'Container 179 - Development',
                'description' => 'Container principal de desenvolvimento com Docker',
                'type' => 'container',
                'ip_range' => '192.168.0.179/32',
                'metadata' => [
                    'ram' => '48GB',
                    'docker' => true,
                    'networks' => ['LAN', 'WireGuard', 'Tailscale'],
                ],
            ],
            [
                'code' => 'CT180',
                'name' => 'Container 180 - Dokploy',
                'description' => 'Plataforma de deployment Dokploy',
                'type' => 'container',
                'ip_range' => '192.168.0.180/32',
                'metadata' => [
                    'url' => 'https://dok.aglz.io',
                ],
            ],
            [
                'code' => 'CT183',
                'name' => 'Container 183 - Archon',
                'description' => 'Archon AI Command Center com MCP',
                'type' => 'container',
                'ip_range' => '192.168.0.183/32',
                'metadata' => [
                    'wireguard' => '10.6.0.21',
                    'tailscale' => '100.80.30.59',
                    'url' => 'https://archon.aglz.io',
                ],
            ],
            [
                'code' => 'REMOTE',
                'name' => 'Remote Access',
                'description' => 'Acesso remoto via VPN',
                'type' => 'remote',
                'ip_range' => '100.0.0.0/8',
                'metadata' => [
                    'vpn' => ['WireGuard', 'Tailscale'],
                ],
            ],
        ];

        foreach ($locations as $location) {
            PhysicalLocation::create($location);
        }
    }
}
