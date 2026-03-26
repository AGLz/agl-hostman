<?php

declare(strict_types=1);

namespace App\DTO;

use JsonSerializable;

/**
 * Container Metrics Data Transfer Object
 *
 * Represents real-time metrics for a Proxmox LXC container.
 * Immutable value object for type-safe metric handling.
 */
final readonly class ContainerMetrics implements JsonSerializable
{
    /**
     * @param  string  $vmid  Container ID
     * @param  string  $name  Container name
     * @param  string  $status  Container status (running, stopped, etc)
     * @param  float  $cpuUsage  CPU usage percentage (0-100)
     * @param  int  $memoryUsed  Memory used in bytes
     * @param  int  $memoryTotal  Total memory in bytes
     * @param  int  $diskUsed  Disk space used in bytes
     * @param  int  $diskTotal  Total disk space in bytes
     * @param  int|null  $networkRx  Network received in bytes
     * @param  int|null  $networkTx  Network transmitted in bytes
     * @param  int  $uptime  Uptime in seconds
     * @param  array<string, mixed>  $additionalMetrics  Additional custom metrics
     * @param  \DateTimeImmutable  $timestamp  Metric collection timestamp
     */
    public function __construct(
        public string $vmid,
        public string $name,
        public string $status,
        public float $cpuUsage,
        public int $memoryUsed,
        public int $memoryTotal,
        public int $diskUsed,
        public int $diskTotal,
        public ?int $networkRx = null,
        public ?int $networkTx = null,
        public int $uptime = 0,
        public array $additionalMetrics = [],
        public \DateTimeImmutable $timestamp = new \DateTimeImmutable,
    ) {}

    /**
     * Create from Proxmox API response
     *
     * @param  array<string, mixed>  $data
     */
    public static function fromProxmoxData(array $data): self
    {
        return new self(
            vmid: (string) ($data['vmid'] ?? ''),
            name: (string) ($data['name'] ?? ''),
            status: (string) ($data['status'] ?? 'unknown'),
            cpuUsage: (float) ($data['cpu'] ?? 0) * 100,
            memoryUsed: (int) ($data['mem'] ?? 0),
            memoryTotal: (int) ($data['maxmem'] ?? 0),
            diskUsed: (int) ($data['disk'] ?? 0),
            diskTotal: (int) ($data['maxdisk'] ?? 0),
            networkRx: isset($data['netin']) ? (int) $data['netin'] : null,
            networkTx: isset($data['netout']) ? (int) $data['netout'] : null,
            uptime: (int) ($data['uptime'] ?? 0),
            additionalMetrics: array_diff_key($data, array_flip([
                'vmid', 'name', 'status', 'cpu', 'mem', 'maxmem',
                'disk', 'maxdisk', 'netin', 'netout', 'uptime',
            ])),
            timestamp: new \DateTimeImmutable,
        );
    }

    /**
     * Get memory usage percentage
     */
    public function getMemoryUsagePercent(): float
    {
        if ($this->memoryTotal === 0) {
            return 0.0;
        }

        return round(($this->memoryUsed / $this->memoryTotal) * 100, 2);
    }

    /**
     * Get disk usage percentage
     */
    public function getDiskUsagePercent(): float
    {
        if ($this->diskTotal === 0) {
            return 0.0;
        }

        return round(($this->diskUsed / $this->diskTotal) * 100, 2);
    }

    /**
     * Check if container is healthy
     */
    public function isHealthy(): bool
    {
        return $this->status === 'running'
            && $this->cpuUsage < 90
            && $this->getMemoryUsagePercent() < 85
            && $this->getDiskUsagePercent() < 90;
    }

    /**
     * Get health status
     */
    public function getHealthStatus(): string
    {
        if (! $this->isHealthy()) {
            if ($this->status !== 'running') {
                return 'critical';
            }
            if ($this->cpuUsage > 95 || $this->getMemoryUsagePercent() > 95) {
                return 'critical';
            }

            return 'warning';
        }

        return 'healthy';
    }

    /**
     * Format memory for human reading
     */
    public function getFormattedMemory(): string
    {
        return sprintf(
            '%s / %s (%s%%)',
            $this->formatBytes($this->memoryUsed),
            $this->formatBytes($this->memoryTotal),
            number_format($this->getMemoryUsagePercent(), 1)
        );
    }

    /**
     * Format disk for human reading
     */
    public function getFormattedDisk(): string
    {
        return sprintf(
            '%s / %s (%s%%)',
            $this->formatBytes($this->diskUsed),
            $this->formatBytes($this->diskTotal),
            number_format($this->getDiskUsagePercent(), 1)
        );
    }

    /**
     * Format bytes to human readable format
     */
    private function formatBytes(int $bytes, int $precision = 2): string
    {
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];

        for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
            $bytes /= 1024;
        }

        return round($bytes, $precision).' '.$units[$i];
    }

    /**
     * Get uptime in human readable format
     */
    public function getFormattedUptime(): string
    {
        $days = floor($this->uptime / 86400);
        $hours = floor(($this->uptime % 86400) / 3600);
        $minutes = floor(($this->uptime % 3600) / 60);

        if ($days > 0) {
            return sprintf('%dd %dh %dm', $days, $hours, $minutes);
        }

        if ($hours > 0) {
            return sprintf('%dh %dm', $hours, $minutes);
        }

        return sprintf('%dm', $minutes);
    }

    /**
     * Convert to array
     *
     * @return array<string, mixed>
     */
    public function toArray(): array
    {
        return [
            'vmid' => $this->vmid,
            'name' => $this->name,
            'status' => $this->status,
            'cpu_usage' => $this->cpuUsage,
            'memory' => [
                'used' => $this->memoryUsed,
                'total' => $this->memoryTotal,
                'percent' => $this->getMemoryUsagePercent(),
                'formatted' => $this->getFormattedMemory(),
            ],
            'disk' => [
                'used' => $this->diskUsed,
                'total' => $this->diskTotal,
                'percent' => $this->getDiskUsagePercent(),
                'formatted' => $this->getFormattedDisk(),
            ],
            'network' => [
                'rx' => $this->networkRx,
                'tx' => $this->networkTx,
            ],
            'uptime' => $this->uptime,
            'uptime_formatted' => $this->getFormattedUptime(),
            'health_status' => $this->getHealthStatus(),
            'is_healthy' => $this->isHealthy(),
            'additional_metrics' => $this->additionalMetrics,
            'timestamp' => $this->timestamp->format(\DateTimeInterface::ATOM),
        ];
    }

    /**
     * JSON serialization
     *
     * @return array<string, mixed>
     */
    public function jsonSerialize(): array
    {
        return $this->toArray();
    }
}
