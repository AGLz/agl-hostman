<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\LxcContainer;
use App\Models\ProxmoxServer;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * MetricsCollector - Aggregate metrics from all infrastructure sources
 *
 * Provides centralized metrics collection with intelligent caching
 * Implements fail-fast pattern with graceful degradation
 *
 * Cache Strategy:
 * - Server metrics: 10 seconds (configurable)
 * - Container metrics: 10 seconds (configurable)
 * - Network metrics: 30 seconds (less frequently changing)
 * - Storage metrics: 60 seconds (least frequently changing)
 *
 * @see docs/MONITORING-DASHBOARD.md
 */
class MetricsCollector
{
    protected int $cacheTtl;

    protected int $apiTimeout;

    protected int $retryAttempts;

    public function __construct()
    {
        $this->cacheTtl = (int) config('monitoring.cache_ttl', 10);
        $this->apiTimeout = (int) config('monitoring.api_timeout', 5);
        $this->retryAttempts = (int) config('monitoring.retry_attempts', 3);
    }

    /**
     * Collect server metrics (CPU, RAM, uptime, load)
     *
     * @param  string  $serverCode  Server code (e.g., 'aglsrv1')
     * @return array{
     *   success: bool,
     *   server: ?array,
     *   metrics: ?array,
     *   health_status: string,
     *   error: ?string
     * }
     */
    public function collectServerMetrics(string $serverCode): array
    {
        $cacheKey = "metrics:server:{$serverCode}";

        return Cache::remember($cacheKey, $this->cacheTtl, function () use ($serverCode) {
            try {
                $server = ProxmoxServer::where('code', $serverCode)->first();

                if (! $server) {
                    return [
                        'success' => false,
                        'server' => null,
                        'metrics' => null,
                        'health_status' => 'unknown',
                        'error' => "Server {$serverCode} not found",
                    ];
                }

                // Check if server is offline
                if (! $server->isOnline()) {
                    return [
                        'success' => true,
                        'server' => $this->formatServerInfo($server),
                        'metrics' => null,
                        'health_status' => 'offline',
                        'error' => 'Server is offline',
                    ];
                }

                // Create API client
                $apiConfig = $server->getApiConfig();
                $apiClient = new ProxmoxApiClient(
                    $apiConfig['host'],
                    $apiConfig['port'],
                    $apiConfig['username'],
                    $apiConfig['password'],
                    $apiConfig['verify_ssl']
                );

                // Get node name (typically first part of FQDN)
                $nodeName = strtok($server->name, '.');

                // Fetch metrics from Proxmox API
                $response = $apiClient->getNodeStatus($nodeName);

                if (! $response->success) {
                    return [
                        'success' => false,
                        'server' => $this->formatServerInfo($server),
                        'metrics' => null,
                        'health_status' => 'error',
                        'error' => $response->error ?? 'Failed to fetch metrics',
                    ];
                }

                $metrics = $this->formatServerMetrics($response->data);
                $healthStatus = $this->calculateServerHealthStatus($metrics);

                // Update server last_seen_at
                $server->markOnline();

                return [
                    'success' => true,
                    'server' => $this->formatServerInfo($server),
                    'metrics' => $metrics,
                    'health_status' => $healthStatus,
                    'error' => null,
                ];

            } catch (\Exception $e) {
                Log::error("Failed to collect server metrics for {$serverCode}", [
                    'error' => $e->getMessage(),
                    'trace' => $e->getTraceAsString(),
                ]);

                return [
                    'success' => false,
                    'server' => null,
                    'metrics' => null,
                    'health_status' => 'error',
                    'error' => $e->getMessage(),
                ];
            }
        });
    }

    /**
     * Collect container metrics for all containers on a server
     *
     * @param  string  $serverId  Server ID or code
     * @return Collection<int, array>
     */
    public function collectContainerMetrics(string $serverId): Collection
    {
        $cacheKey = "metrics:containers:{$serverId}";

        return Cache::remember($cacheKey, $this->cacheTtl, function () use ($serverId) {
            try {
                // Find server by ID or code
                $server = is_numeric($serverId)
                    ? ProxmoxServer::find($serverId)
                    : ProxmoxServer::where('code', $serverId)->first();

                if (! $server) {
                    return collect([]);
                }

                // Get all containers for this server
                $containers = LxcContainer::where('proxmox_server_id', $server->id)
                    ->orderBy('vmid')
                    ->get();

                if ($containers->isEmpty()) {
                    return collect([]);
                }

                // Check if server is online
                if (! $server->isOnline()) {
                    return $containers->map(function ($container) {
                        return $this->formatContainerOffline($container);
                    });
                }

                // Create API client
                $apiConfig = $server->getApiConfig();
                $apiClient = new ProxmoxApiClient(
                    $apiConfig['host'],
                    $apiConfig['port'],
                    $apiConfig['username'],
                    $apiConfig['password'],
                    $apiConfig['verify_ssl']
                );

                $nodeName = strtok($server->name, '.');

                // Fetch metrics for all containers
                return $containers->map(function ($container) use ($apiClient, $nodeName) {
                    return $this->collectSingleContainerMetrics($container, $apiClient, $nodeName);
                });

            } catch (\Exception $e) {
                Log::error("Failed to collect container metrics for server {$serverId}", [
                    'error' => $e->getMessage(),
                ]);

                return collect([]);
            }
        });
    }

    /**
     * Collect network metrics (WireGuard mesh status)
     *
     * @return array{
     *   success: bool,
     *   peers: array,
     *   health_status: string,
     *   summary: array
     * }
     */
    public function collectNetworkMetrics(): array
    {
        $cacheKey = 'metrics:network';

        return Cache::remember($cacheKey, 30, function () {
            try {
                // This is a placeholder - actual implementation would query WireGuard
                // For now, we'll return a structure based on known infrastructure

                $peers = [
                    ['ip' => '10.6.0.5', 'name' => 'fgsrv6', 'status' => 'connected', 'latency_ms' => 2],
                    ['ip' => '10.6.0.12', 'name' => 'aglsrv6', 'status' => 'connected', 'latency_ms' => 45],
                    ['ip' => '10.6.0.15', 'name' => 'ct179', 'status' => 'connected', 'latency_ms' => 1],
                    ['ip' => '10.6.0.21', 'name' => 'ct183', 'status' => 'connected', 'latency_ms' => 1],
                ];

                $connected = collect($peers)->where('status', 'connected')->count();
                $totalPeers = count($peers);
                $avgLatency = collect($peers)->avg('latency_ms');

                $healthStatus = $this->calculateNetworkHealthStatus($connected, $totalPeers, $avgLatency);

                return [
                    'success' => true,
                    'peers' => $peers,
                    'health_status' => $healthStatus,
                    'summary' => [
                        'total_peers' => $totalPeers,
                        'connected_peers' => $connected,
                        'disconnected_peers' => $totalPeers - $connected,
                        'avg_latency_ms' => round($avgLatency, 2),
                    ],
                ];

            } catch (\Exception $e) {
                Log::error('Failed to collect network metrics', [
                    'error' => $e->getMessage(),
                ]);

                return [
                    'success' => false,
                    'peers' => [],
                    'health_status' => 'error',
                    'summary' => [
                        'total_peers' => 0,
                        'connected_peers' => 0,
                        'disconnected_peers' => 0,
                        'avg_latency_ms' => 0,
                    ],
                ];
            }
        });
    }

    /**
     * Collect storage metrics (NFS mount usage)
     *
     * @return array{
     *   success: bool,
     *   mounts: array,
     *   health_status: string,
     *   summary: array
     * }
     */
    public function collectStorageMetrics(): array
    {
        $cacheKey = 'metrics:storage';

        return Cache::remember($cacheKey, 60, function () {
            try {
                // Query storage from Proxmox servers
                $servers = ProxmoxServer::online()->get();
                $storageSummary = [];

                foreach ($servers as $server) {
                    try {
                        $apiConfig = $server->getApiConfig();
                        $apiClient = new ProxmoxApiClient(
                            $apiConfig['host'],
                            $apiConfig['port'],
                            $apiConfig['username'],
                            $apiConfig['password'],
                            $apiConfig['verify_ssl']
                        );

                        $nodeName = strtok($server->name, '.');
                        $response = $apiClient->get("/nodes/{$nodeName}/storage");

                        if (isset($response['data'])) {
                            foreach ($response['data'] as $storage) {
                                $storageSummary[] = [
                                    'server' => $server->code,
                                    'name' => $storage['storage'] ?? 'unknown',
                                    'type' => $storage['type'] ?? 'unknown',
                                    'used_gb' => isset($storage['used']) ? round($storage['used'] / (1024 ** 3), 2) : 0,
                                    'total_gb' => isset($storage['total']) ? round($storage['total'] / (1024 ** 3), 2) : 0,
                                    'available_gb' => isset($storage['avail']) ? round($storage['avail'] / (1024 ** 3), 2) : 0,
                                    'percent_used' => isset($storage['used'], $storage['total']) && $storage['total'] > 0
                                        ? round(($storage['used'] / $storage['total']) * 100, 1)
                                        : 0,
                                    'active' => $storage['active'] ?? false,
                                ];
                            }
                        }
                    } catch (\Exception $e) {
                        Log::warning("Failed to collect storage metrics for {$server->code}", [
                            'error' => $e->getMessage(),
                        ]);
                    }
                }

                $healthStatus = $this->calculateStorageHealthStatus($storageSummary);

                $totalCapacity = collect($storageSummary)->sum('total_gb');
                $totalUsed = collect($storageSummary)->sum('used_gb');
                $avgUsage = $totalCapacity > 0 ? round(($totalUsed / $totalCapacity) * 100, 1) : 0;

                return [
                    'success' => true,
                    'mounts' => $storageSummary,
                    'health_status' => $healthStatus,
                    'summary' => [
                        'total_capacity_gb' => round($totalCapacity, 2),
                        'total_used_gb' => round($totalUsed, 2),
                        'total_available_gb' => round($totalCapacity - $totalUsed, 2),
                        'avg_usage_percent' => $avgUsage,
                        'mount_count' => count($storageSummary),
                    ],
                ];

            } catch (\Exception $e) {
                Log::error('Failed to collect storage metrics', [
                    'error' => $e->getMessage(),
                ]);

                return [
                    'success' => false,
                    'mounts' => [],
                    'health_status' => 'error',
                    'summary' => [
                        'total_capacity_gb' => 0,
                        'total_used_gb' => 0,
                        'total_available_gb' => 0,
                        'avg_usage_percent' => 0,
                        'mount_count' => 0,
                    ],
                ];
            }
        });
    }

    /**
     * Aggregate all metrics (complete infrastructure snapshot)
     *
     * @return array{
     *   success: bool,
     *   servers: array,
     *   containers: Collection,
     *   network: array,
     *   storage: array,
     *   summary: array,
     *   timestamp: string
     * }
     */
    public function aggregateAllMetrics(): array
    {
        $servers = [];
        $allContainers = collect([]);

        // Collect metrics for all servers
        $serverModels = ProxmoxServer::all();
        foreach ($serverModels as $server) {
            $serverMetrics = $this->collectServerMetrics($server->code);
            $servers[] = $serverMetrics;

            // Collect containers for this server
            $containerMetrics = $this->collectContainerMetrics($server->id);
            $allContainers = $allContainers->merge($containerMetrics);
        }

        // Collect network and storage metrics
        $network = $this->collectNetworkMetrics();
        $storage = $this->collectStorageMetrics();

        // Calculate summary statistics
        $summary = [
            'total_servers' => count($servers),
            'online_servers' => collect($servers)->where('health_status', '!=', 'offline')->count(),
            'total_containers' => $allContainers->count(),
            'running_containers' => $allContainers->where('status', 'running')->count(),
            'stopped_containers' => $allContainers->where('status', 'stopped')->count(),
            'warning_containers' => $allContainers->where('health_status', 'warning')->count(),
            'critical_containers' => $allContainers->where('health_status', 'critical')->count(),
            'overall_health' => $this->calculateOverallHealth($servers, $allContainers, $network, $storage),
        ];

        return [
            'success' => true,
            'servers' => $servers,
            'containers' => $allContainers,
            'network' => $network,
            'storage' => $storage,
            'summary' => $summary,
            'timestamp' => now()->toIso8601String(),
        ];
    }

    /**
     * Format server information
     */
    protected function formatServerInfo(ProxmoxServer $server): array
    {
        return [
            'id' => $server->id,
            'name' => $server->name,
            'code' => $server->code,
            'ip_address' => $server->ip_address,
            'status' => $server->status,
            'location' => $server->location?->name,
        ];
    }

    /**
     * Format server metrics from Proxmox API response
     */
    protected function formatServerMetrics(array $data): array
    {
        $cpuCores = $data['cpuinfo']['cpus'] ?? 1;
        $cpuUsage = ($data['cpu'] ?? 0) * 100;
        $memTotal = $data['memory']['total'] ?? 0;
        $memUsed = $data['memory']['used'] ?? 0;
        $memPercent = $memTotal > 0 ? ($memUsed / $memTotal) * 100 : 0;
        $loadAvg = $data['loadavg'] ?? [0, 0, 0];

        return [
            'cpu' => [
                'cores' => $cpuCores,
                'usage_percent' => round($cpuUsage, 1),
                'model' => $data['cpuinfo']['model'] ?? 'Unknown',
            ],
            'memory' => [
                'total_gb' => round($memTotal / (1024 ** 3), 2),
                'used_gb' => round($memUsed / (1024 ** 3), 2),
                'free_gb' => round(($memTotal - $memUsed) / (1024 ** 3), 2),
                'usage_percent' => round($memPercent, 1),
            ],
            'load' => [
                '1min' => $loadAvg[0] ?? 0,
                '5min' => $loadAvg[1] ?? 0,
                '15min' => $loadAvg[2] ?? 0,
            ],
            'uptime' => [
                'seconds' => $data['uptime'] ?? 0,
                'formatted' => $this->formatUptime($data['uptime'] ?? 0),
            ],
        ];
    }

    /**
     * Collect metrics for a single container
     */
    protected function collectSingleContainerMetrics(LxcContainer $container, ProxmoxApiClient $apiClient, string $nodeName): array
    {
        try {
            $response = $apiClient->getContainerStatus($nodeName, (int) $container->vmid);

            if (! $response->success) {
                return $this->formatContainerError($container, $response->error);
            }

            $metrics = $this->formatContainerMetrics($response->data, $container);
            $healthStatus = $this->calculateContainerHealthStatus($metrics);

            return array_merge($metrics, [
                'health_status' => $healthStatus,
                'error' => null,
            ]);

        } catch (\Exception $e) {
            return $this->formatContainerError($container, $e->getMessage());
        }
    }

    /**
     * Format container metrics
     */
    protected function formatContainerMetrics(array $data, LxcContainer $container): array
    {
        $cpuUsage = ($data['cpu'] ?? 0) * 100;
        $memTotal = $data['maxmem'] ?? 0;
        $memUsed = $data['mem'] ?? 0;
        $memPercent = $memTotal > 0 ? ($memUsed / $memTotal) * 100 : 0;

        return [
            'id' => $container->id,
            'vmid' => $container->vmid,
            'name' => $container->name,
            'hostname' => $container->hostname,
            'status' => $data['status'] ?? 'unknown',
            'uptime' => $data['uptime'] ?? 0,
            'uptime_formatted' => $this->formatUptime($data['uptime'] ?? 0),
            'cpu' => [
                'usage_percent' => round($cpuUsage, 1),
                'cores' => $container->cores,
            ],
            'memory' => [
                'total_mb' => round($memTotal / (1024 ** 2), 0),
                'used_mb' => round($memUsed / (1024 ** 2), 0),
                'usage_percent' => round($memPercent, 1),
            ],
            'disk' => [
                'total_gb' => $container->disk_gb,
                'used_gb' => isset($data['disk']) ? round($data['disk'] / (1024 ** 3), 2) : 0,
                'usage_percent' => isset($data['disk'], $data['maxdisk']) && $data['maxdisk'] > 0
                    ? round(($data['disk'] / $data['maxdisk']) * 100, 1)
                    : 0,
            ],
            'network' => [
                'in_bytes' => $data['netin'] ?? 0,
                'out_bytes' => $data['netout'] ?? 0,
            ],
        ];
    }

    /**
     * Format container when server is offline
     */
    protected function formatContainerOffline(LxcContainer $container): array
    {
        return [
            'id' => $container->id,
            'vmid' => $container->vmid,
            'name' => $container->name,
            'hostname' => $container->hostname,
            'status' => 'offline',
            'health_status' => 'offline',
            'error' => 'Server is offline',
        ];
    }

    /**
     * Format container error
     */
    protected function formatContainerError(LxcContainer $container, ?string $error): array
    {
        return [
            'id' => $container->id,
            'vmid' => $container->vmid,
            'name' => $container->name,
            'hostname' => $container->hostname,
            'status' => 'error',
            'health_status' => 'error',
            'error' => $error ?? 'Unknown error',
        ];
    }

    /**
     * Calculate server health status
     *
     * Green: CPU <70%, RAM <80%, load <cores
     * Yellow: CPU 70-85%, RAM 80-90%, load = cores
     * Red: CPU >85%, RAM >90%, load >cores
     */
    protected function calculateServerHealthStatus(array $metrics): string
    {
        $cpuUsage = $metrics['cpu']['usage_percent'];
        $memUsage = $metrics['memory']['usage_percent'];
        $cpuCores = $metrics['cpu']['cores'];
        $load1min = $metrics['load']['1min'];

        if ($cpuUsage > 85 || $memUsage > 90 || $load1min > $cpuCores) {
            return 'critical';
        }

        if ($cpuUsage > 70 || $memUsage > 80 || $load1min >= $cpuCores) {
            return 'warning';
        }

        return 'healthy';
    }

    /**
     * Calculate container health status
     */
    protected function calculateContainerHealthStatus(array $metrics): string
    {
        if ($metrics['status'] !== 'running') {
            return 'stopped';
        }

        $cpuUsage = $metrics['cpu']['usage_percent'];
        $memUsage = $metrics['memory']['usage_percent'];

        if ($cpuUsage > 80 || $memUsage > 90) {
            return 'critical';
        }

        if ($cpuUsage > 60 || $memUsage > 75) {
            return 'warning';
        }

        return 'healthy';
    }

    /**
     * Calculate network health status
     */
    protected function calculateNetworkHealthStatus(int $connected, int $total, float $avgLatency): string
    {
        $connectionRate = $total > 0 ? ($connected / $total) * 100 : 0;

        if ($connectionRate < 80 || $avgLatency > 150) {
            return 'critical';
        }

        if ($connectionRate < 95 || $avgLatency > 50) {
            return 'warning';
        }

        return 'healthy';
    }

    /**
     * Calculate storage health status
     */
    protected function calculateStorageHealthStatus(array $mounts): string
    {
        $criticalMounts = collect($mounts)->where('percent_used', '>', 85)->count();
        $warningMounts = collect($mounts)->where('percent_used', '>', 70)->count();

        if ($criticalMounts > 0) {
            return 'critical';
        }

        if ($warningMounts > 0) {
            return 'warning';
        }

        return 'healthy';
    }

    /**
     * Calculate overall infrastructure health
     */
    protected function calculateOverallHealth(array $servers, Collection $containers, array $network, array $storage): string
    {
        $healthScores = [
            collect($servers)->pluck('health_status'),
            collect([$network['health_status']]),
            collect([$storage['health_status']]),
        ];

        $allStatuses = collect($healthScores)->flatten();

        if ($allStatuses->contains('critical')) {
            return 'critical';
        }

        if ($allStatuses->contains('warning')) {
            return 'warning';
        }

        if ($allStatuses->contains('offline')) {
            return 'degraded';
        }

        return 'healthy';
    }

    /**
     * Format uptime in human-readable format
     */
    protected function formatUptime(int $seconds): string
    {
        $days = floor($seconds / 86400);
        $hours = floor(($seconds % 86400) / 3600);
        $minutes = floor(($seconds % 3600) / 60);

        if ($days > 0) {
            return sprintf('%dd %dh %dm', $days, $hours, $minutes);
        }

        if ($hours > 0) {
            return sprintf('%dh %dm', $hours, $minutes);
        }

        return sprintf('%dm', $minutes);
    }

    /**
     * Force refresh all metrics (bypass cache)
     */
    public function refreshAllMetrics(): void
    {
        // Clear all metrics caches
        $servers = ProxmoxServer::all();
        foreach ($servers as $server) {
            Cache::forget("metrics:server:{$server->code}");
            Cache::forget("metrics:containers:{$server->id}");
        }

        Cache::forget('metrics:network');
        Cache::forget('metrics:storage');

        Log::info('All metrics caches cleared');
    }
}
