<?php

declare(strict_types=1);

namespace App\Repositories;

use App\DTO\ContainerMetrics;
use App\DTO\ProxmoxApiResponse;
use App\Services\Proxmox\ProxmoxApiClient;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;
use Psr\Log\LoggerInterface;

/**
 * Proxmox Container Repository
 *
 * Repository pattern for Proxmox LXC container operations.
 * Provides data layer abstraction with caching and error handling.
 *
 * @package App\Repositories
 */
class ProxmoxContainerRepository
{
    private const CACHE_TTL = 60; // 1 minute
    private const CACHE_PREFIX = 'proxmox_containers_';

    public function __construct(
        private readonly ProxmoxApiClient $client,
        private readonly LoggerInterface $logger,
    ) {
    }

    /**
     * Get all containers on a node
     *
     * @param string $node Node name
     * @param bool $withMetrics Include real-time metrics
     * @return Collection<int, ContainerMetrics>
     */
    public function getAllContainers(string $node, bool $withMetrics = true): Collection
    {
        $cacheKey = self::CACHE_PREFIX . "{$node}_all";

        return Cache::remember($cacheKey, self::CACHE_TTL, function () use ($node, $withMetrics) {
            $response = $this->client->get("/nodes/{$node}/lxc");

            if (!$response->success) {
                $this->logger->error('Failed to fetch containers', [
                    'node' => $node,
                    'error' => $response->error,
                ]);
                return collect();
            }

            $containers = collect($response->data);

            if (!$withMetrics) {
                return $containers->map(fn($container) => ContainerMetrics::fromProxmoxData($container));
            }

            // Fetch detailed metrics for each container
            return $containers->map(function ($container) use ($node) {
                $vmid = $container['vmid'];
                $metrics = $this->getContainerMetrics($node, (string)$vmid);
                return $metrics ?? ContainerMetrics::fromProxmoxData($container);
            })->filter();
        });
    }

    /**
     * Get container by VMID
     *
     * @param string $node Node name
     * @param string $vmid Container VMID
     * @return ContainerMetrics|null
     */
    public function getContainer(string $node, string $vmid): ?ContainerMetrics
    {
        $cacheKey = self::CACHE_PREFIX . "{$node}_{$vmid}";

        return Cache::remember($cacheKey, self::CACHE_TTL, function () use ($node, $vmid) {
            $response = $this->client->get("/nodes/{$node}/lxc/{$vmid}/status/current");

            if (!$response->success) {
                $this->logger->warning('Failed to fetch container', [
                    'node' => $node,
                    'vmid' => $vmid,
                    'error' => $response->error,
                ]);
                return null;
            }

            return ContainerMetrics::fromProxmoxData($response->data);
        });
    }

    /**
     * Get real-time metrics for container
     *
     * @param string $node Node name
     * @param string $vmid Container VMID
     * @return ContainerMetrics|null
     */
    public function getContainerMetrics(string $node, string $vmid): ?ContainerMetrics
    {
        return $this->getContainer($node, $vmid);
    }

    /**
     * Start container
     *
     * @param string $node Node name
     * @param string $vmid Container VMID
     * @return ProxmoxApiResponse
     */
    public function startContainer(string $node, string $vmid): ProxmoxApiResponse
    {
        $response = $this->client->post("/nodes/{$node}/lxc/{$vmid}/status/start");

        if ($response->success) {
            $this->invalidateCache($node, $vmid);
            $this->logger->info('Container started', ['node' => $node, 'vmid' => $vmid]);
        }

        return $response;
    }

    /**
     * Stop container
     *
     * @param string $node Node name
     * @param string $vmid Container VMID
     * @return ProxmoxApiResponse
     */
    public function stopContainer(string $node, string $vmid): ProxmoxApiResponse
    {
        $response = $this->client->post("/nodes/{$node}/lxc/{$vmid}/status/stop");

        if ($response->success) {
            $this->invalidateCache($node, $vmid);
            $this->logger->info('Container stopped', ['node' => $node, 'vmid' => $vmid]);
        }

        return $response;
    }

    /**
     * Restart container
     *
     * @param string $node Node name
     * @param string $vmid Container VMID
     * @return ProxmoxApiResponse
     */
    public function restartContainer(string $node, string $vmid): ProxmoxApiResponse
    {
        $response = $this->client->post("/nodes/{$node}/lxc/{$vmid}/status/reboot");

        if ($response->success) {
            $this->invalidateCache($node, $vmid);
            $this->logger->info('Container restarted', ['node' => $node, 'vmid' => $vmid]);
        }

        return $response;
    }

    /**
     * Shutdown container gracefully
     *
     * @param string $node Node name
     * @param string $vmid Container VMID
     * @param int $timeout Shutdown timeout in seconds
     * @return ProxmoxApiResponse
     */
    public function shutdownContainer(string $node, string $vmid, int $timeout = 60): ProxmoxApiResponse
    {
        $response = $this->client->post("/nodes/{$node}/lxc/{$vmid}/status/shutdown", [
            'timeout' => $timeout,
        ]);

        if ($response->success) {
            $this->invalidateCache($node, $vmid);
            $this->logger->info('Container shutdown initiated', [
                'node' => $node,
                'vmid' => $vmid,
                'timeout' => $timeout,
            ]);
        }

        return $response;
    }

    /**
     * Get container configuration
     *
     * @param string $node Node name
     * @param string $vmid Container VMID
     * @return ProxmoxApiResponse
     */
    public function getContainerConfig(string $node, string $vmid): ProxmoxApiResponse
    {
        return $this->client->get("/nodes/{$node}/lxc/{$vmid}/config");
    }

    /**
     * Update container configuration
     *
     * @param string $node Node name
     * @param string $vmid Container VMID
     * @param array<string, mixed> $config
     * @return ProxmoxApiResponse
     */
    public function updateContainerConfig(string $node, string $vmid, array $config): ProxmoxApiResponse
    {
        $response = $this->client->put("/nodes/{$node}/lxc/{$vmid}/config", $config);

        if ($response->success) {
            $this->invalidateCache($node, $vmid);
            $this->logger->info('Container config updated', [
                'node' => $node,
                'vmid' => $vmid,
                'config' => $config,
            ]);
        }

        return $response;
    }

    /**
     * Get container snapshots
     *
     * @param string $node Node name
     * @param string $vmid Container VMID
     * @return ProxmoxApiResponse
     */
    public function getContainerSnapshots(string $node, string $vmid): ProxmoxApiResponse
    {
        return $this->client->get("/nodes/{$node}/lxc/{$vmid}/snapshot");
    }

    /**
     * Create container snapshot
     *
     * @param string $node Node name
     * @param string $vmid Container VMID
     * @param string $snapname Snapshot name
     * @param string|null $description Snapshot description
     * @return ProxmoxApiResponse
     */
    public function createSnapshot(
        string $node,
        string $vmid,
        string $snapname,
        ?string $description = null
    ): ProxmoxApiResponse {
        $data = ['snapname' => $snapname];

        if ($description) {
            $data['description'] = $description;
        }

        $response = $this->client->post("/nodes/{$node}/lxc/{$vmid}/snapshot", $data);

        if ($response->success) {
            $this->logger->info('Snapshot created', [
                'node' => $node,
                'vmid' => $vmid,
                'snapname' => $snapname,
            ]);
        }

        return $response;
    }

    /**
     * Clone container
     *
     * @param string $node Node name
     * @param string $vmid Source container VMID
     * @param string $newid New container VMID
     * @param array<string, mixed> $options Clone options
     * @return ProxmoxApiResponse
     */
    public function cloneContainer(
        string $node,
        string $vmid,
        string $newid,
        array $options = []
    ): ProxmoxApiResponse {
        $data = array_merge(['newid' => $newid], $options);

        $response = $this->client->post("/nodes/{$node}/lxc/{$vmid}/clone", $data);

        if ($response->success) {
            $this->invalidateCache($node);
            $this->logger->info('Container cloned', [
                'node' => $node,
                'source_vmid' => $vmid,
                'new_vmid' => $newid,
            ]);
        }

        return $response;
    }

    /**
     * Get containers by status
     *
     * @param string $node Node name
     * @param string $status Status filter (running, stopped)
     * @return Collection<int, ContainerMetrics>
     */
    public function getContainersByStatus(string $node, string $status): Collection
    {
        return $this->getAllContainers($node)
            ->filter(fn(ContainerMetrics $container) => $container->status === $status);
    }

    /**
     * Get unhealthy containers
     *
     * @param string $node Node name
     * @return Collection<int, ContainerMetrics>
     */
    public function getUnhealthyContainers(string $node): Collection
    {
        return $this->getAllContainers($node)
            ->filter(fn(ContainerMetrics $container) => !$container->isHealthy());
    }

    /**
     * Search containers by name
     *
     * @param string $node Node name
     * @param string $search Search term
     * @return Collection<int, ContainerMetrics>
     */
    public function searchContainers(string $node, string $search): Collection
    {
        return $this->getAllContainers($node)
            ->filter(fn(ContainerMetrics $container) =>
                str_contains(strtolower($container->name), strtolower($search))
            );
    }

    /**
     * Get aggregate statistics
     *
     * @param string $node Node name
     * @return array<string, mixed>
     */
    public function getAggregateStats(string $node): array
    {
        $containers = $this->getAllContainers($node);

        $running = $containers->filter(fn($c) => $c->status === 'running')->count();
        $stopped = $containers->filter(fn($c) => $c->status === 'stopped')->count();
        $healthy = $containers->filter(fn($c) => $c->isHealthy())->count();

        $totalCpu = $containers->sum(fn($c) => $c->cpuUsage);
        $totalMemUsed = $containers->sum(fn($c) => $c->memoryUsed);
        $totalMemTotal = $containers->sum(fn($c) => $c->memoryTotal);
        $totalDiskUsed = $containers->sum(fn($c) => $c->diskUsed);
        $totalDiskTotal = $containers->sum(fn($c) => $c->diskTotal);

        return [
            'total_containers' => $containers->count(),
            'running' => $running,
            'stopped' => $stopped,
            'healthy' => $healthy,
            'unhealthy' => $containers->count() - $healthy,
            'avg_cpu_usage' => $containers->isNotEmpty() ? round($totalCpu / $containers->count(), 2) : 0,
            'total_memory_used' => $totalMemUsed,
            'total_memory_total' => $totalMemTotal,
            'memory_usage_percent' => $totalMemTotal > 0 ? round(($totalMemUsed / $totalMemTotal) * 100, 2) : 0,
            'total_disk_used' => $totalDiskUsed,
            'total_disk_total' => $totalDiskTotal,
            'disk_usage_percent' => $totalDiskTotal > 0 ? round(($totalDiskUsed / $totalDiskTotal) * 100, 2) : 0,
        ];
    }

    /**
     * Invalidate cache for container
     */
    private function invalidateCache(string $node, ?string $vmid = null): void
    {
        Cache::forget(self::CACHE_PREFIX . "{$node}_all");

        if ($vmid) {
            Cache::forget(self::CACHE_PREFIX . "{$node}_{$vmid}");
        }
    }

    /**
     * Clear all cache
     */
    public function clearCache(): void
    {
        Cache::flush();
    }
}
