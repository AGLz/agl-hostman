<?php

namespace App\DTOs;

use Carbon\Carbon;

/**
 * ContainerMetrics - Data Transfer Object for LXC container metrics
 *
 * Provides type-safe container metrics with automatic calculations
 * Based on IMPLEMENTATION-SUMMARY.md recommendations
 */
class ContainerMetrics
{
    /**
     * Create container metrics DTO
     *
     * @param  int  $vmid  Container ID
     * @param  string  $name  Container name
     * @param  string  $status  Container status (running, stopped)
     * @param  float  $cpuUsagePercent  CPU usage percentage (0-100)
     * @param  int  $memoryUsedBytes  Memory used in bytes
     * @param  int  $memoryTotalBytes  Total memory in bytes
     * @param  int  $diskUsedBytes  Disk used in bytes
     * @param  int  $diskTotalBytes  Total disk in bytes
     * @param  int  $uptimeSeconds  Uptime in seconds
     * @param  array  $networkInterfaces  Network interfaces data
     * @param  Carbon|null  $timestamp  Timestamp of metrics collection
     */
    public function __construct(
        public readonly int $vmid,
        public readonly string $name,
        public readonly string $status,
        public readonly float $cpuUsagePercent,
        public readonly int $memoryUsedBytes,
        public readonly int $memoryTotalBytes,
        public readonly int $diskUsedBytes,
        public readonly int $diskTotalBytes,
        public readonly int $uptimeSeconds,
        public readonly array $networkInterfaces = [],
        public readonly ?Carbon $timestamp = null
    ) {}

    /**
     * Create from Proxmox API response
     */
    public static function fromProxmoxResponse(array $data): self
    {
        return new self(
            vmid: (int) ($data['vmid'] ?? 0),
            name: $data['name'] ?? 'unknown',
            status: $data['status'] ?? 'unknown',
            cpuUsagePercent: ((float) ($data['cpu'] ?? 0)) * 100,
            memoryUsedBytes: (int) ($data['mem'] ?? 0),
            memoryTotalBytes: (int) ($data['maxmem'] ?? 0),
            diskUsedBytes: (int) ($data['disk'] ?? 0),
            diskTotalBytes: (int) ($data['maxdisk'] ?? 0),
            uptimeSeconds: (int) ($data['uptime'] ?? 0),
            networkInterfaces: $data['network'] ?? [],
            timestamp: now()
        );
    }

    /**
     * Get memory usage percentage
     */
    public function getMemoryUsagePercent(): float
    {
        if ($this->memoryTotalBytes === 0) {
            return 0.0;
        }

        return round(($this->memoryUsedBytes / $this->memoryTotalBytes) * 100, 2);
    }

    /**
     * Get disk usage percentage
     */
    public function getDiskUsagePercent(): float
    {
        if ($this->diskTotalBytes === 0) {
            return 0.0;
        }

        return round(($this->diskUsedBytes / $this->diskTotalBytes) * 100, 2);
    }

    /**
     * Get memory used in human-readable format
     */
    public function getMemoryUsedHuman(): string
    {
        return $this->formatBytes($this->memoryUsedBytes);
    }

    /**
     * Get memory total in human-readable format
     */
    public function getMemoryTotalHuman(): string
    {
        return $this->formatBytes($this->memoryTotalBytes);
    }

    /**
     * Get disk used in human-readable format
     */
    public function getDiskUsedHuman(): string
    {
        return $this->formatBytes($this->diskUsedBytes);
    }

    /**
     * Get disk total in human-readable format
     */
    public function getDiskTotalHuman(): string
    {
        return $this->formatBytes($this->diskTotalBytes);
    }

    /**
     * Get uptime in human-readable format
     */
    public function getUptimeHuman(): string
    {
        $seconds = $this->uptimeSeconds;

        $days = floor($seconds / 86400);
        $hours = floor(($seconds % 86400) / 3600);
        $minutes = floor(($seconds % 3600) / 60);

        if ($days > 0) {
            return "{$days}d {$hours}h {$minutes}m";
        }

        if ($hours > 0) {
            return "{$hours}h {$minutes}m";
        }

        return "{$minutes}m";
    }

    /**
     * Check if container is running
     */
    public function isRunning(): bool
    {
        return $this->status === 'running';
    }

    /**
     * Check if container is stopped
     */
    public function isStopped(): bool
    {
        return $this->status === 'stopped';
    }

    /**
     * Check if CPU usage is critical (>90%)
     */
    public function isCpuCritical(): bool
    {
        return $this->cpuUsagePercent > 90;
    }

    /**
     * Check if memory usage is critical (>85%)
     */
    public function isMemoryCritical(): bool
    {
        return $this->getMemoryUsagePercent() > 85;
    }

    /**
     * Check if disk usage is critical (>80%)
     */
    public function isDiskCritical(): bool
    {
        return $this->getDiskUsagePercent() > 80;
    }

    /**
     * Get health status (healthy, warning, critical)
     */
    public function getHealthStatus(): string
    {
        if (! $this->isRunning()) {
            return 'stopped';
        }

        if ($this->isCpuCritical() || $this->isMemoryCritical() || $this->isDiskCritical()) {
            return 'critical';
        }

        if ($this->cpuUsagePercent > 70 || $this->getMemoryUsagePercent() > 70 || $this->getDiskUsagePercent() > 60) {
            return 'warning';
        }

        return 'healthy';
    }

    /**
     * Convert to array
     */
    public function toArray(): array
    {
        return [
            'vmid' => $this->vmid,
            'name' => $this->name,
            'status' => $this->status,
            'cpu_usage_percent' => $this->cpuUsagePercent,
            'memory_used_bytes' => $this->memoryUsedBytes,
            'memory_total_bytes' => $this->memoryTotalBytes,
            'memory_usage_percent' => $this->getMemoryUsagePercent(),
            'memory_used_human' => $this->getMemoryUsedHuman(),
            'memory_total_human' => $this->getMemoryTotalHuman(),
            'disk_used_bytes' => $this->diskUsedBytes,
            'disk_total_bytes' => $this->diskTotalBytes,
            'disk_usage_percent' => $this->getDiskUsagePercent(),
            'disk_used_human' => $this->getDiskUsedHuman(),
            'disk_total_human' => $this->getDiskTotalHuman(),
            'uptime_seconds' => $this->uptimeSeconds,
            'uptime_human' => $this->getUptimeHuman(),
            'health_status' => $this->getHealthStatus(),
            'network_interfaces' => $this->networkInterfaces,
            'timestamp' => $this->timestamp?->toIso8601String(),
        ];
    }

    /**
     * Convert to JSON
     */
    public function toJson(): string
    {
        return json_encode($this->toArray(), JSON_PRETTY_PRINT);
    }

    /**
     * Format bytes to human-readable format
     */
    protected function formatBytes(int $bytes): string
    {
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];
        $bytes = max($bytes, 0);
        $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
        $pow = min($pow, count($units) - 1);
        $bytes /= (1 << (10 * $pow));

        return round($bytes, 2).' '.$units[$pow];
    }
}
