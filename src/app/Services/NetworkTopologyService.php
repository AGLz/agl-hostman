<?php

namespace App\Services;

use App\Services\Proxmox\ProxmoxApiClient;
use App\Services\Container\ContainerLifecycleService;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

class NetworkTopologyService
{
    private ProxmoxApiClient $proxmoxService;
    private ContainerLifecycleService $containerService;
    private const CACHE_TTL = 300; // 5 minutes

    public function __construct(
        ProxmoxApiClient $proxmoxService,
        ContainerLifecycleService $containerService
    ) {
        $this->proxmoxService = $proxmoxService;
        $this->containerService = $containerService;
    }

    /**
     * Build complete network graph structure (nodes + edges)
     */
    public function getNetworkGraph(): array
    {
        return Cache::remember('network_topology_graph', self::CACHE_TTL, function () {
            $nodes = $this->buildNodes();
            $edges = $this->buildEdges($nodes);

            return [
                'nodes' => $nodes,
                'edges' => $edges,
                'metadata' => $this->getGraphMetadata($nodes, $edges),
            ];
        });
    }

    /**
     * Build all network nodes (servers, containers, network devices)
     */
    private function buildNodes(): array
    {
        $nodes = [];

        // Add Proxmox servers
        $nodes = array_merge($nodes, $this->buildServerNodes());

        // Add containers
        $nodes = array_merge($nodes, $this->buildContainerNodes());

        // Add WireGuard hub
        $nodes[] = $this->buildWireGuardHubNode();

        // Add network devices (if discovered)
        $nodes = array_merge($nodes, $this->buildNetworkDeviceNodes());

        return $nodes;
    }

    /**
     * Build server nodes (Proxmox hosts)
     */
    private function buildServerNodes(): array
    {
        $servers = [
            [
                'id' => 'aglsrv1',
                'name' => 'AGLSRV1',
                'type' => 'server',
                'subtype' => 'proxmox',
                'ips' => [
                    'lan' => '192.168.0.245',
                    'wireguard' => '10.6.0.10',
                    'tailscale' => '100.107.113.33',
                ],
                'location' => 'AGL Headquarters',
                'role' => 'Primary Proxmox Host',
                'specs' => [
                    'cpu_cores' => 32,
                    'ram_gb' => 256,
                    'storage_tb' => 8,
                ],
            ],
            [
                'id' => 'aglsrv6',
                'name' => 'AGLSRV6',
                'type' => 'server',
                'subtype' => 'proxmox',
                'ips' => [
                    'lan' => '192.168.100.6',
                    'wireguard' => '10.6.0.12',
                    'tailscale' => '100.94.221.87',
                ],
                'location' => 'Remote Site',
                'role' => 'Secondary Proxmox Host',
                'specs' => [
                    'cpu_cores' => 16,
                    'ram_gb' => 128,
                    'storage_tb' => 4,
                ],
            ],
        ];

        $nodes = [];
        foreach ($servers as $server) {
            $metrics = $this->getNodeMetrics($server['id']);
            $nodes[] = array_merge($server, [
                'status' => $metrics['status'],
                'health' => $metrics['health'],
                'metrics' => $metrics,
            ]);
        }

        return $nodes;
    }

    /**
     * Build container nodes (LXC)
     */
    private function buildContainerNodes(): array
    {
        $containers = $this->getWireGuardPeers()->toArray();
        $nodes = [];

        foreach ($containers as $container) {
            $metrics = $this->getNodeMetrics($container['id']);
            $nodes[] = [
                'id' => $container['id'],
                'name' => $container['name'],
                'type' => 'container',
                'subtype' => 'lxc',
                'ips' => [
                    'lan' => $container['lan_ip'] ?? null,
                    'wireguard' => $container['wg_ip'],
                    'tailscale' => $container['tailscale_ip'] ?? null,
                ],
                'location' => $container['location'] ?? 'AGL Headquarters',
                'role' => $container['role'] ?? 'General Purpose',
                'parent' => $container['parent'] ?? 'aglsrv1',
                'specs' => [
                    'cpu_cores' => $container['cpu_cores'] ?? 4,
                    'ram_gb' => $container['ram_gb'] ?? 8,
                    'storage_gb' => $container['storage_gb'] ?? 100,
                ],
                'status' => $metrics['status'],
                'health' => $metrics['health'],
                'metrics' => $metrics,
            ];
        }

        return $nodes;
    }

    /**
     * Build WireGuard hub node
     */
    private function buildWireGuardHubNode(): array
    {
        return [
            'id' => 'wg-hub',
            'name' => 'WireGuard Hub (CT111)',
            'type' => 'network',
            'subtype' => 'wireguard_hub',
            'ips' => [
                'wireguard' => '10.6.0.5',
                'lan' => '192.168.0.111',
            ],
            'location' => 'AGL Headquarters',
            'role' => 'Central Hub & Fileserver',
            'parent' => 'aglsrv1',
            'status' => 'online',
            'health' => 100,
            'metrics' => [
                'peers_connected' => 14,
                'total_bandwidth_mbps' => 1000,
                'avg_latency_ms' => 25,
            ],
        ];
    }

    /**
     * Build network device nodes (switches, routers)
     */
    private function buildNetworkDeviceNodes(): array
    {
        // Currently no managed switches discovered
        // This is a placeholder for future expansion
        return [];
    }

    /**
     * Build all network edges (connections between nodes)
     */
    private function buildEdges(array $nodes): array
    {
        $edges = [];

        // Build WireGuard connections
        $edges = array_merge($edges, $this->buildWireGuardEdges($nodes));

        // Build LAN connections
        $edges = array_merge($edges, $this->buildLANEdges($nodes));

        // Build Tailscale connections
        $edges = array_merge($edges, $this->buildTailscaleEdges($nodes));

        // Build container-to-host connections
        $edges = array_merge($edges, $this->buildContainerHostEdges($nodes));

        return $edges;
    }

    /**
     * Build WireGuard mesh connections
     */
    private function buildWireGuardEdges(array $nodes): array
    {
        $edges = [];
        $wgNodes = array_filter($nodes, fn($n) => !empty($n['ips']['wireguard']));

        // Hub-and-spoke topology
        $hub = array_values(array_filter($nodes, fn($n) => $n['id'] === 'wg-hub'))[0] ?? null;
        if (!$hub) {
            return $edges;
        }

        foreach ($wgNodes as $node) {
            if ($node['id'] === 'wg-hub') {
                continue;
            }

            $health = $this->getConnectionHealth($hub['id'], $node['id']);
            $edges[] = [
                'id' => "wg_{$hub['id']}_{$node['id']}",
                'source' => $hub['id'],
                'target' => $node['id'],
                'type' => 'wireguard',
                'bidirectional' => true,
                'bandwidth_mbps' => 1000,
                'latency_ms' => $health['latency_ms'],
                'packet_loss_percent' => $health['packet_loss_percent'],
                'last_handshake' => $health['last_handshake'],
                'status' => $health['status'],
                'health' => $health['health'],
            ];
        }

        // Add mesh connections between critical nodes
        $meshPairs = [
            ['aglsrv1', 'aglsrv6'],
            ['ct179', 'ct180'],
            ['ct180', 'ct183'],
        ];

        foreach ($meshPairs as [$source, $target]) {
            $sourceNode = array_values(array_filter($nodes, fn($n) => $n['id'] === $source))[0] ?? null;
            $targetNode = array_values(array_filter($nodes, fn($n) => $n['id'] === $target))[0] ?? null;

            if ($sourceNode && $targetNode && !empty($sourceNode['ips']['wireguard']) && !empty($targetNode['ips']['wireguard'])) {
                $health = $this->getConnectionHealth($source, $target);
                $edges[] = [
                    'id' => "wg_{$source}_{$target}",
                    'source' => $source,
                    'target' => $target,
                    'type' => 'wireguard',
                    'bidirectional' => true,
                    'bandwidth_mbps' => 1000,
                    'latency_ms' => $health['latency_ms'],
                    'packet_loss_percent' => $health['packet_loss_percent'],
                    'last_handshake' => $health['last_handshake'],
                    'status' => $health['status'],
                    'health' => $health['health'],
                ];
            }
        }

        return $edges;
    }

    /**
     * Build LAN connections
     */
    private function buildLANEdges(array $nodes): array
    {
        $edges = [];
        $lanNodes = array_filter($nodes, fn($n) => !empty($n['ips']['lan']));

        // All LAN nodes connect to their parent server
        foreach ($lanNodes as $node) {
            if ($node['type'] === 'container' && !empty($node['parent'])) {
                $edges[] = [
                    'id' => "lan_{$node['parent']}_{$node['id']}",
                    'source' => $node['parent'],
                    'target' => $node['id'],
                    'type' => 'lan',
                    'bidirectional' => true,
                    'bandwidth_mbps' => 10000, // 10 Gbps
                    'latency_ms' => 1,
                    'packet_loss_percent' => 0,
                    'status' => 'online',
                    'health' => 100,
                ];
            }
        }

        return $edges;
    }

    /**
     * Build Tailscale overlay connections
     */
    private function buildTailscaleEdges(array $nodes): array
    {
        $edges = [];
        $tsNodes = array_filter($nodes, fn($n) => !empty($n['ips']['tailscale']));

        // Tailscale creates a full mesh, but we'll show only critical connections
        // to avoid cluttering the visualization
        $criticalPairs = [
            ['aglsrv1', 'aglsrv6'],
            ['ct179', 'ct108'],
        ];

        foreach ($criticalPairs as [$source, $target]) {
            $sourceNode = array_values(array_filter($nodes, fn($n) => $n['id'] === $source))[0] ?? null;
            $targetNode = array_values(array_filter($nodes, fn($n) => $n['id'] === $target))[0] ?? null;

            if ($sourceNode && $targetNode && !empty($sourceNode['ips']['tailscale']) && !empty($targetNode['ips']['tailscale'])) {
                $health = $this->getConnectionHealth($source, $target, 'tailscale');
                $edges[] = [
                    'id' => "ts_{$source}_{$target}",
                    'source' => $source,
                    'target' => $target,
                    'type' => 'tailscale',
                    'bidirectional' => true,
                    'bandwidth_mbps' => 100,
                    'latency_ms' => $health['latency_ms'],
                    'packet_loss_percent' => $health['packet_loss_percent'],
                    'status' => $health['status'],
                    'health' => $health['health'],
                ];
            }
        }

        return $edges;
    }

    /**
     * Build container-to-host physical connections
     */
    private function buildContainerHostEdges(array $nodes): array
    {
        // Already covered in LAN connections
        return [];
    }

    /**
     * Get graph metadata
     */
    private function getGraphMetadata(array $nodes, array $edges): array
    {
        $onlineNodes = count(array_filter($nodes, fn($n) => $n['status'] === 'online'));
        $totalNodes = count($nodes);

        $healthyEdges = count(array_filter($edges, fn($e) => $e['status'] === 'online'));
        $totalEdges = count($edges);

        $latencies = array_column($edges, 'latency_ms');
        $avgLatency = count($latencies) > 0 ? array_sum($latencies) / count($latencies) : 0;

        return [
            'total_nodes' => $totalNodes,
            'online_nodes' => $onlineNodes,
            'offline_nodes' => $totalNodes - $onlineNodes,
            'total_edges' => $totalEdges,
            'healthy_edges' => $healthyEdges,
            'degraded_edges' => $totalEdges - $healthyEdges,
            'avg_latency_ms' => round($avgLatency, 2),
            'network_health_score' => round(($onlineNodes / $totalNodes) * 100, 2),
        ];
    }

    /**
     * Get real-time metrics for a specific node
     */
    public function getNodeMetrics(string $nodeId): array
    {
        // This would integrate with Proxmox API for real metrics
        // For now, return simulated data based on node type
        $simulatedMetrics = [
            'aglsrv1' => [
                'status' => 'online',
                'health' => 95,
                'cpu_percent' => 45.2,
                'ram_percent' => 62.8,
                'network_io_mbps' => 125.5,
                'disk_io_mbps' => 45.2,
                'uptime_days' => 127,
            ],
            'aglsrv6' => [
                'status' => 'online',
                'health' => 92,
                'cpu_percent' => 38.5,
                'ram_percent' => 55.3,
                'network_io_mbps' => 85.3,
                'disk_io_mbps' => 32.1,
                'uptime_days' => 89,
            ],
            'ct179' => [
                'status' => 'online',
                'health' => 98,
                'cpu_percent' => 25.3,
                'ram_percent' => 45.2,
                'network_io_mbps' => 55.2,
                'disk_io_mbps' => 18.5,
                'uptime_days' => 45,
            ],
        ];

        return $simulatedMetrics[$nodeId] ?? [
            'status' => 'online',
            'health' => 90,
            'cpu_percent' => rand(20, 60),
            'ram_percent' => rand(30, 70),
            'network_io_mbps' => rand(10, 100),
            'disk_io_mbps' => rand(5, 50),
            'uptime_days' => rand(1, 100),
        ];
    }

    /**
     * Get connection health between two nodes
     */
    public function getConnectionHealth(string $sourceId, string $targetId, string $type = 'wireguard'): array
    {
        // This would use ping/iperf for real measurements
        // For now, return simulated data based on connection type
        $baseLatency = match ($type) {
            'lan' => 1,
            'wireguard' => 25,
            'tailscale' => 45,
            default => 25,
        };

        $latency = $baseLatency + rand(-5, 15);
        $packetLoss = rand(0, 2) / 10; // 0-0.2%

        $status = $latency < 100 && $packetLoss < 1 ? 'online' : 'degraded';
        $health = max(0, 100 - ($latency / 2) - ($packetLoss * 10));

        return [
            'latency_ms' => $latency,
            'packet_loss_percent' => $packetLoss,
            'last_handshake' => now()->subMinutes(rand(1, 5))->toISOString(),
            'status' => $status,
            'health' => round($health, 2),
        ];
    }

    /**
     * Detect network issues
     */
    public function detectNetworkIssues(): Collection
    {
        $issues = collect();
        $graph = $this->getNetworkGraph();

        // Check for offline nodes
        foreach ($graph['nodes'] as $node) {
            if ($node['status'] !== 'online') {
                $issues->push([
                    'severity' => 'critical',
                    'type' => 'node_offline',
                    'node_id' => $node['id'],
                    'message' => "Node {$node['name']} is offline",
                    'timestamp' => now()->toISOString(),
                ]);
            }
        }

        // Check for high latency connections
        foreach ($graph['edges'] as $edge) {
            if ($edge['latency_ms'] > 100) {
                $issues->push([
                    'severity' => 'warning',
                    'type' => 'high_latency',
                    'edge_id' => $edge['id'],
                    'source' => $edge['source'],
                    'target' => $edge['target'],
                    'latency_ms' => $edge['latency_ms'],
                    'message' => "High latency ({$edge['latency_ms']}ms) between {$edge['source']} and {$edge['target']}",
                    'timestamp' => now()->toISOString(),
                ]);
            }
        }

        // Check for packet loss
        foreach ($graph['edges'] as $edge) {
            if ($edge['packet_loss_percent'] > 5) {
                $issues->push([
                    'severity' => 'warning',
                    'type' => 'packet_loss',
                    'edge_id' => $edge['id'],
                    'source' => $edge['source'],
                    'target' => $edge['target'],
                    'packet_loss_percent' => $edge['packet_loss_percent'],
                    'message' => "Packet loss ({$edge['packet_loss_percent']}%) between {$edge['source']} and {$edge['target']}",
                    'timestamp' => now()->toISOString(),
                ]);
            }
        }

        return $issues;
    }

    /**
     * Get all WireGuard peers
     */
    public function getWireGuardPeers(): Collection
    {
        return collect([
            ['id' => 'ct111', 'name' => 'CT111', 'wg_ip' => '10.6.0.5', 'lan_ip' => '192.168.0.111', 'role' => 'Hub & Fileserver', 'cpu_cores' => 4, 'ram_gb' => 8],
            ['id' => 'ct179', 'name' => 'CT179', 'wg_ip' => '10.6.0.15', 'lan_ip' => '192.168.0.179', 'role' => 'Development', 'cpu_cores' => 16, 'ram_gb' => 48],
            ['id' => 'ct180', 'name' => 'CT180', 'wg_ip' => '10.6.0.16', 'lan_ip' => '192.168.0.180', 'role' => 'Dokploy', 'cpu_cores' => 8, 'ram_gb' => 16],
            ['id' => 'ct183', 'name' => 'CT183', 'wg_ip' => '10.6.0.21', 'lan_ip' => '192.168.0.183', 'role' => 'Archon MCP', 'cpu_cores' => 4, 'ram_gb' => 8],
            ['id' => 'ct200', 'name' => 'CT200', 'wg_ip' => '10.6.0.23', 'lan_ip' => '192.168.0.200', 'role' => 'Ollama GPU', 'cpu_cores' => 8, 'ram_gb' => 32],
            ['id' => 'ct108', 'name' => 'CT108', 'wg_ip' => '10.6.0.13', 'tailscale_ip' => '100.71.229.12', 'role' => 'Development', 'parent' => 'aglsrv6', 'cpu_cores' => 4, 'ram_gb' => 8],
            ['id' => 'ct135', 'name' => 'CT135', 'wg_ip' => '10.6.0.17', 'lan_ip' => '192.168.0.135', 'role' => 'MySQL5 Backup', 'cpu_cores' => 2, 'ram_gb' => 4],
            ['id' => 'ct138', 'name' => 'CT138', 'wg_ip' => '10.6.0.18', 'lan_ip' => '192.168.0.138', 'role' => 'Fileserver', 'cpu_cores' => 4, 'ram_gb' => 8],
            ['id' => 'ct181', 'name' => 'CT181', 'wg_ip' => '10.6.0.19', 'lan_ip' => '192.168.0.181', 'role' => 'SuperClaude', 'cpu_cores' => 8, 'ram_gb' => 16],
            ['id' => 'fgsrv6', 'name' => 'FGSRV6', 'wg_ip' => '10.6.0.14', 'lan_ip' => '192.168.100.14', 'role' => 'Storage Server', 'parent' => 'aglsrv6', 'cpu_cores' => 8, 'ram_gb' => 16],
            ['id' => 'omaysrv1', 'name' => 'OMAYSRV1', 'wg_ip' => '10.6.0.20', 'lan_ip' => '192.168.200.1', 'role' => 'Switch Discovery', 'location' => 'Omay Site', 'cpu_cores' => 4, 'ram_gb' => 8],
            ['id' => 'aglhq11', 'name' => 'AGLHQ11', 'wg_ip' => '10.6.0.11', 'tailscale_ip' => '100.75.205.122', 'role' => 'WSL2 Development', 'location' => 'AGL Headquarters', 'cpu_cores' => 8, 'ram_gb' => 16],
        ]);
    }

    /**
     * Calculate shortest network path between two nodes
     */
    public function calculateNetworkPaths(string $from, string $to): array
    {
        $graph = $this->getNetworkGraph();

        // Build adjacency list
        $adjacency = [];
        foreach ($graph['edges'] as $edge) {
            if (!isset($adjacency[$edge['source']])) {
                $adjacency[$edge['source']] = [];
            }
            if (!isset($adjacency[$edge['target']])) {
                $adjacency[$edge['target']] = [];
            }

            $adjacency[$edge['source']][] = [
                'node' => $edge['target'],
                'weight' => $edge['latency_ms'],
                'type' => $edge['type'],
            ];

            if ($edge['bidirectional']) {
                $adjacency[$edge['target']][] = [
                    'node' => $edge['source'],
                    'weight' => $edge['latency_ms'],
                    'type' => $edge['type'],
                ];
            }
        }

        // Dijkstra's algorithm
        $distances = [];
        $previous = [];
        $unvisited = [];

        foreach ($graph['nodes'] as $node) {
            $distances[$node['id']] = INF;
            $previous[$node['id']] = null;
            $unvisited[$node['id']] = true;
        }

        $distances[$from] = 0;

        while (!empty($unvisited)) {
            // Find unvisited node with minimum distance
            $minNode = null;
            $minDistance = INF;
            foreach ($unvisited as $nodeId => $val) {
                if ($distances[$nodeId] < $minDistance) {
                    $minDistance = $distances[$nodeId];
                    $minNode = $nodeId;
                }
            }

            if ($minNode === null || $minDistance === INF) {
                break;
            }

            unset($unvisited[$minNode]);

            if ($minNode === $to) {
                break; // Found shortest path to target
            }

            // Update distances to neighbors
            if (isset($adjacency[$minNode])) {
                foreach ($adjacency[$minNode] as $neighbor) {
                    $alt = $distances[$minNode] + $neighbor['weight'];
                    if ($alt < $distances[$neighbor['node']]) {
                        $distances[$neighbor['node']] = $alt;
                        $previous[$neighbor['node']] = $minNode;
                    }
                }
            }
        }

        // Reconstruct path
        $path = [];
        $current = $to;
        while ($current !== null) {
            array_unshift($path, $current);
            $current = $previous[$current];
        }

        if ($path[0] !== $from) {
            return [
                'found' => false,
                'message' => 'No path found',
            ];
        }

        return [
            'found' => true,
            'path' => $path,
            'total_latency_ms' => $distances[$to],
            'hops' => count($path) - 1,
        ];
    }
}
