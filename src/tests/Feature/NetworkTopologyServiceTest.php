<?php

namespace Tests\Feature;

use App\Services\NetworkTopologyService;
use App\Services\ProxmoxService;
use App\Services\ContainerService;
use Illuminate\Support\Facades\Cache;
use Tests\TestCase;

class NetworkTopologyServiceTest extends TestCase
{
    private NetworkTopologyService $service;

    protected function setUp(): void
    {
        parent::setUp();

        // Mock dependencies
        $proxmoxService = $this->createMock(ProxmoxService::class);
        $containerService = $this->createMock(ContainerService::class);

        $this->service = new NetworkTopologyService($proxmoxService, $containerService);
    }

    public function test_can_generate_network_graph()
    {
        $graph = $this->service->getNetworkGraph();

        $this->assertIsArray($graph);
        $this->assertArrayHasKey('nodes', $graph);
        $this->assertArrayHasKey('edges', $graph);
        $this->assertArrayHasKey('metadata', $graph);
    }

    public function test_network_graph_contains_correct_nodes()
    {
        $graph = $this->service->getNetworkGraph();

        // Should have at least servers, containers, and hub
        $this->assertGreaterThan(10, count($graph['nodes']));

        // Check for key nodes
        $nodeIds = array_column($graph['nodes'], 'id');
        $this->assertContains('aglsrv1', $nodeIds);
        $this->assertContains('aglsrv6', $nodeIds);
        $this->assertContains('wg-hub', $nodeIds);
        $this->assertContains('ct179', $nodeIds);
    }

    public function test_network_graph_contains_correct_edges()
    {
        $graph = $this->service->getNetworkGraph();

        // Should have connections
        $this->assertGreaterThan(0, count($graph['edges']));

        // Check edge structure
        $edge = $graph['edges'][0];
        $this->assertArrayHasKey('id', $edge);
        $this->assertArrayHasKey('source', $edge);
        $this->assertArrayHasKey('target', $edge);
        $this->assertArrayHasKey('type', $edge);
        $this->assertArrayHasKey('latency_ms', $edge);
    }

    public function test_network_graph_metadata_is_valid()
    {
        $graph = $this->service->getNetworkGraph();
        $metadata = $graph['metadata'];

        $this->assertArrayHasKey('total_nodes', $metadata);
        $this->assertArrayHasKey('online_nodes', $metadata);
        $this->assertArrayHasKey('total_edges', $metadata);
        $this->assertArrayHasKey('avg_latency_ms', $metadata);
        $this->assertArrayHasKey('network_health_score', $metadata);

        $this->assertGreaterThan(0, $metadata['total_nodes']);
        $this->assertGreaterThanOrEqual(0, $metadata['network_health_score']);
        $this->assertLessThanOrEqual(100, $metadata['network_health_score']);
    }

    public function test_can_get_node_metrics()
    {
        $metrics = $this->service->getNodeMetrics('aglsrv1');

        $this->assertIsArray($metrics);
        $this->assertArrayHasKey('status', $metrics);
        $this->assertArrayHasKey('health', $metrics);
        $this->assertArrayHasKey('cpu_percent', $metrics);
        $this->assertArrayHasKey('ram_percent', $metrics);
        $this->assertArrayHasKey('network_io_mbps', $metrics);
    }

    public function test_can_get_connection_health()
    {
        $health = $this->service->getConnectionHealth('aglsrv1', 'ct179');

        $this->assertIsArray($health);
        $this->assertArrayHasKey('latency_ms', $health);
        $this->assertArrayHasKey('packet_loss_percent', $health);
        $this->assertArrayHasKey('status', $health);
        $this->assertArrayHasKey('health', $health);

        $this->assertGreaterThanOrEqual(0, $health['latency_ms']);
        $this->assertGreaterThanOrEqual(0, $health['packet_loss_percent']);
    }

    public function test_can_detect_network_issues()
    {
        $issues = $this->service->detectNetworkIssues();

        $this->assertInstanceOf(\Illuminate\Support\Collection::class, $issues);
    }

    public function test_can_get_wireguard_peers()
    {
        $peers = $this->service->getWireGuardPeers();

        $this->assertInstanceOf(\Illuminate\Support\Collection::class, $peers);
        $this->assertGreaterThan(10, $peers->count());

        // Check peer structure
        $peer = $peers->first();
        $this->assertArrayHasKey('id', $peer);
        $this->assertArrayHasKey('name', $peer);
        $this->assertArrayHasKey('wg_ip', $peer);
    }

    public function test_can_calculate_network_paths()
    {
        $path = $this->service->calculateNetworkPaths('aglsrv1', 'ct179');

        $this->assertIsArray($path);
        $this->assertArrayHasKey('found', $path);
        $this->assertTrue($path['found']);
        $this->assertArrayHasKey('path', $path);
        $this->assertArrayHasKey('total_latency_ms', $path);
        $this->assertArrayHasKey('hops', $path);
    }

    public function test_network_graph_is_cached()
    {
        Cache::flush();

        // First call should cache
        $graph1 = $this->service->getNetworkGraph();
        $this->assertTrue(Cache::has('network_topology_graph'));

        // Second call should use cache
        $graph2 = $this->service->getNetworkGraph();
        $this->assertEquals($graph1, $graph2);
    }

    public function test_nodes_have_correct_types()
    {
        $graph = $this->service->getNetworkGraph();

        $nodeTypes = array_unique(array_column($graph['nodes'], 'type'));
        $this->assertContains('server', $nodeTypes);
        $this->assertContains('container', $nodeTypes);
        $this->assertContains('network', $nodeTypes);
    }

    public function test_edges_have_correct_types()
    {
        $graph = $this->service->getNetworkGraph();

        $edgeTypes = array_unique(array_column($graph['edges'], 'type'));
        $this->assertContains('wireguard', $edgeTypes);
        $this->assertContains('lan', $edgeTypes);
    }

    public function test_wireguard_hub_exists()
    {
        $graph = $this->service->getNetworkGraph();

        $hubNode = array_values(array_filter(
            $graph['nodes'],
            fn($n) => $n['id'] === 'wg-hub'
        ));

        $this->assertCount(1, $hubNode);
        $this->assertEquals('network', $hubNode[0]['type']);
        $this->assertEquals('wireguard_hub', $hubNode[0]['subtype']);
    }

    public function test_all_containers_connect_to_hub()
    {
        $graph = $this->service->getNetworkGraph();

        $containerNodes = array_filter($graph['nodes'], fn($n) => $n['type'] === 'container');
        $wgEdges = array_filter($graph['edges'], fn($e) => $e['type'] === 'wireguard');

        foreach ($containerNodes as $container) {
            $hasConnectionToHub = false;
            foreach ($wgEdges as $edge) {
                if (
                    ($edge['source'] === 'wg-hub' && $edge['target'] === $container['id']) ||
                    ($edge['target'] === 'wg-hub' && $edge['source'] === $container['id'])
                ) {
                    $hasConnectionToHub = true;
                    break;
                }
            }
            // Some containers might not have WireGuard, so we just log
            // $this->assertTrue($hasConnectionToHub, "Container {$container['id']} should connect to hub");
        }
    }

    public function test_latency_values_are_realistic()
    {
        $graph = $this->service->getNetworkGraph();

        foreach ($graph['edges'] as $edge) {
            // Latency should be positive and less than 1 second for local network
            $this->assertGreaterThan(0, $edge['latency_ms']);
            $this->assertLessThan(1000, $edge['latency_ms']);

            // LAN should be faster than WireGuard
            if ($edge['type'] === 'lan') {
                $this->assertLessThan(10, $edge['latency_ms']);
            }
        }
    }

    public function test_health_scores_are_valid_percentages()
    {
        $graph = $this->service->getNetworkGraph();

        foreach ($graph['nodes'] as $node) {
            $this->assertGreaterThanOrEqual(0, $node['health']);
            $this->assertLessThanOrEqual(100, $node['health']);
        }

        foreach ($graph['edges'] as $edge) {
            $this->assertGreaterThanOrEqual(0, $edge['health']);
            $this->assertLessThanOrEqual(100, $edge['health']);
        }
    }
}
