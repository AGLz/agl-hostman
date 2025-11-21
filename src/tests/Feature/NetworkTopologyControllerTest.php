<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class NetworkTopologyControllerTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();

        $this->user = User::factory()->create();
    }

    public function test_topology_page_requires_authentication()
    {
        $response = $this->get(route('network.topology'));

        $response->assertRedirect(route('login'));
    }

    public function test_authenticated_user_can_access_topology_page()
    {
        $response = $this->actingAs($this->user)->get(route('network.topology'));

        $response->assertOk();
        $response->assertInertia(fn($page) => $page->component('Network/Topology'));
    }

    public function test_can_get_network_graph()
    {
        $response = $this->actingAs($this->user)->getJson('/api/network/graph');

        $response->assertOk();
        $response->assertJsonStructure([
            'nodes' => [
                '*' => [
                    'id',
                    'name',
                    'type',
                    'ips',
                    'status',
                    'health',
                ],
            ],
            'edges' => [
                '*' => [
                    'id',
                    'source',
                    'target',
                    'type',
                    'latency_ms',
                    'status',
                ],
            ],
            'metadata' => [
                'total_nodes',
                'online_nodes',
                'total_edges',
                'avg_latency_ms',
                'network_health_score',
            ],
            'timestamp',
        ]);
    }

    public function test_can_get_node_details()
    {
        $response = $this->actingAs($this->user)->getJson('/api/network/nodes/aglsrv1');

        $response->assertOk();
        $response->assertJsonStructure([
            'node_id',
            'metrics' => [
                'status',
                'health',
                'cpu_percent',
                'ram_percent',
                'network_io_mbps',
            ],
            'timestamp',
        ]);
    }

    public function test_can_get_connection_details()
    {
        $response = $this->actingAs($this->user)->getJson('/api/network/connections/aglsrv1/ct179');

        $response->assertOk();
        $response->assertJsonStructure([
            'source_id',
            'target_id',
            'health' => [
                'latency_ms',
                'packet_loss_percent',
                'status',
                'health',
            ],
            'timestamp',
        ]);
    }

    public function test_can_get_network_health()
    {
        $response = $this->actingAs($this->user)->getJson('/api/network/health');

        $response->assertOk();
        $response->assertJsonStructure([
            'metadata' => [
                'total_nodes',
                'online_nodes',
                'avg_latency_ms',
                'network_health_score',
            ],
            'timestamp',
        ]);
    }

    public function test_can_detect_network_issues()
    {
        $response = $this->actingAs($this->user)->getJson('/api/network/issues');

        $response->assertOk();
        $response->assertJsonStructure([
            '*' => [
                'severity',
                'type',
                'message',
                'timestamp',
            ],
        ]);
    }

    public function test_can_calculate_network_path()
    {
        $response = $this->actingAs($this->user)->postJson('/api/network/path', [
            'from' => 'aglsrv1',
            'to' => 'ct179',
        ]);

        $response->assertOk();
        $response->assertJsonStructure([
            'found',
            'path',
            'total_latency_ms',
            'hops',
        ]);
    }

    public function test_path_calculation_requires_from_and_to()
    {
        $response = $this->actingAs($this->user)->postJson('/api/network/path', [
            'from' => 'aglsrv1',
        ]);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors('to');
    }

    public function test_can_get_wireguard_peers()
    {
        $response = $this->actingAs($this->user)->getJson('/api/network/wireguard/peers');

        $response->assertOk();
        $response->assertJsonStructure([
            '*' => [
                'id',
                'name',
                'wg_ip',
            ],
        ]);
    }

    public function test_all_network_endpoints_require_authentication()
    {
        $endpoints = [
            '/api/network/graph',
            '/api/network/nodes/aglsrv1',
            '/api/network/connections/aglsrv1/ct179',
            '/api/network/health',
            '/api/network/issues',
            '/api/network/wireguard/peers',
        ];

        foreach ($endpoints as $endpoint) {
            $response = $this->getJson($endpoint);
            $response->assertUnauthorized();
        }
    }

    public function test_network_graph_returns_valid_data_types()
    {
        $response = $this->actingAs($this->user)->getJson('/api/network/graph');

        $data = $response->json();

        $this->assertIsArray($data['nodes']);
        $this->assertIsArray($data['edges']);
        $this->assertIsArray($data['metadata']);
        $this->assertIsString($data['timestamp']);

        // Check first node
        if (count($data['nodes']) > 0) {
            $node = $data['nodes'][0];
            $this->assertIsString($node['id']);
            $this->assertIsString($node['name']);
            $this->assertIsString($node['type']);
            $this->assertIsInt($node['health']) || $this->assertIsFloat($node['health']);
        }
    }

    public function test_node_metrics_include_performance_data()
    {
        $response = $this->actingAs($this->user)->getJson('/api/network/nodes/aglsrv1');

        $metrics = $response->json('metrics');

        $this->assertArrayHasKey('cpu_percent', $metrics);
        $this->assertArrayHasKey('ram_percent', $metrics);
        $this->assertArrayHasKey('network_io_mbps', $metrics);
        $this->assertArrayHasKey('disk_io_mbps', $metrics);

        // Validate ranges
        $this->assertGreaterThanOrEqual(0, $metrics['cpu_percent']);
        $this->assertLessThanOrEqual(100, $metrics['cpu_percent']);
    }

    public function test_connection_health_includes_latency_data()
    {
        $response = $this->actingAs($this->user)->getJson('/api/network/connections/aglsrv1/ct179');

        $health = $response->json('health');

        $this->assertArrayHasKey('latency_ms', $health);
        $this->assertArrayHasKey('packet_loss_percent', $health);
        $this->assertArrayHasKey('last_handshake', $health);

        $this->assertGreaterThan(0, $health['latency_ms']);
        $this->assertGreaterThanOrEqual(0, $health['packet_loss_percent']);
    }

    public function test_network_issues_are_categorized_by_severity()
    {
        $response = $this->actingAs($this->user)->getJson('/api/network/issues');

        $issues = $response->json();

        if (count($issues) > 0) {
            foreach ($issues as $issue) {
                $this->assertContains($issue['severity'], ['critical', 'warning', 'info']);
            }
        }
    }

    public function test_calculated_path_is_valid()
    {
        $response = $this->actingAs($this->user)->postJson('/api/network/path', [
            'from' => 'aglsrv1',
            'to' => 'ct179',
        ]);

        $path = $response->json();

        if ($path['found']) {
            $this->assertIsArray($path['path']);
            $this->assertGreaterThan(0, count($path['path']));
            $this->assertEquals('aglsrv1', $path['path'][0]);
            $this->assertEquals('ct179', $path['path'][count($path['path']) - 1]);
        }
    }
}
