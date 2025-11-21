<?php

declare(strict_types=1);

namespace App\DTO;

/**
 * Container Creation Configuration DTO
 *
 * Immutable data transfer object for container creation parameters.
 * Uses PHP 8.4 readonly classes for type-safe configuration.
 *
 * @package App\DTO
 */
readonly class ContainerCreateDTO
{
    /**
     * @param string $hostname Container hostname (required)
     * @param string|null $osTemplate OS template (e.g., 'local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst')
     * @param int $cores CPU cores (default: 2)
     * @param int $memoryMb Memory in MB (default: 2048)
     * @param int $diskGb Root disk size in GB (default: 8)
     * @param string $rootfsStorage Storage for root filesystem (default: 'local-lvm')
     * @param string $networkInterface Network interface config (default: 'name=eth0,bridge=vmbr0,ip=dhcp')
     * @param bool $unprivileged Create unprivileged container (default: true)
     * @param bool $autoStart Auto-start on boot (default: false)
     * @param bool $startAfterCreate Start container after creation (default: false)
     * @param string|null $description Container description
     * @param array<string, mixed> $features Container features (nesting, keyctl, etc.)
     * @param array<string, mixed> $mountPoints Additional mount points
     * @param array<string, string> $metadata Custom metadata tags
     */
    public function __construct(
        public string $hostname,
        public ?string $osTemplate = null,
        public int $cores = 2,
        public int $memoryMb = 2048,
        public int $diskGb = 8,
        public string $rootfsStorage = 'local-lvm',
        public string $networkInterface = 'name=eth0,bridge=vmbr0,ip=dhcp',
        public bool $unprivileged = true,
        public bool $autoStart = false,
        public bool $startAfterCreate = false,
        public ?string $description = null,
        public array $features = [],
        public array $mountPoints = [],
        public array $metadata = [],
    ) {
        $this->validate();
    }

    /**
     * Create from array
     *
     * @param array<string, mixed> $data
     * @return self
     */
    public static function fromArray(array $data): self
    {
        return new self(
            hostname: $data['hostname'] ?? throw new \InvalidArgumentException('hostname is required'),
            osTemplate: $data['os_template'] ?? $data['ostemplate'] ?? null,
            cores: (int)($data['cores'] ?? 2),
            memoryMb: (int)($data['memory'] ?? $data['memory_mb'] ?? 2048),
            diskGb: (int)($data['disk'] ?? $data['disk_gb'] ?? 8),
            rootfsStorage: $data['storage'] ?? $data['rootfs_storage'] ?? 'local-lvm',
            networkInterface: $data['net0'] ?? $data['network_interface'] ?? 'name=eth0,bridge=vmbr0,ip=dhcp',
            unprivileged: (bool)($data['unprivileged'] ?? true),
            autoStart: (bool)($data['auto_start'] ?? $data['onboot'] ?? false),
            startAfterCreate: (bool)($data['start'] ?? $data['start_after_create'] ?? false),
            description: $data['description'] ?? null,
            features: $data['features'] ?? [],
            mountPoints: $data['mount_points'] ?? $data['mountpoints'] ?? [],
            metadata: $data['metadata'] ?? [],
        );
    }

    /**
     * Convert to Proxmox API parameters
     *
     * @return array<string, mixed>
     */
    public function toProxmoxParams(): array
    {
        $params = [
            'hostname' => $this->hostname,
            'ostemplate' => $this->osTemplate ?? 'local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst',
            'cores' => $this->cores,
            'memory' => $this->memoryMb,
            'rootfs' => "{$this->rootfsStorage}:{$this->diskGb}",
            'net0' => $this->networkInterface,
            'unprivileged' => $this->unprivileged ? 1 : 0,
            'onboot' => $this->autoStart ? 1 : 0,
            'start' => $this->startAfterCreate ? 1 : 0,
        ];

        if ($this->description) {
            $params['description'] = $this->description;
        }

        // Add features (nesting, keyctl, fuse, etc.)
        if (!empty($this->features)) {
            $params['features'] = $this->formatFeatures($this->features);
        }

        // Add mount points
        foreach ($this->mountPoints as $key => $mountPoint) {
            $params[$key] = $mountPoint;
        }

        return $params;
    }

    /**
     * Convert to database attributes
     *
     * @return array<string, mixed>
     */
    public function toDatabaseAttributes(): array
    {
        return [
            'hostname' => $this->hostname,
            'os_template' => $this->osTemplate,
            'cores' => $this->cores,
            'memory_mb' => $this->memoryMb,
            'disk_gb' => $this->diskGb,
            'network_config' => [
                'net0' => $this->networkInterface,
            ],
            'description' => $this->description,
            'auto_start' => $this->autoStart,
            'metadata' => array_merge($this->metadata, [
                'created_via' => 'api',
                'created_at' => now()->toIso8601String(),
            ]),
        ];
    }

    /**
     * Validate configuration
     *
     * @throws \InvalidArgumentException
     */
    private function validate(): void
    {
        // Validate hostname format (RFC 1123)
        if (!preg_match('/^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/i', $this->hostname)) {
            throw new \InvalidArgumentException(
                "Invalid hostname format: {$this->hostname}. Must be RFC 1123 compliant."
            );
        }

        // Validate resource limits
        if ($this->cores < 1 || $this->cores > 256) {
            throw new \InvalidArgumentException("CPU cores must be between 1 and 256, got {$this->cores}");
        }

        if ($this->memoryMb < 128 || $this->memoryMb > 524288) {
            throw new \InvalidArgumentException("Memory must be between 128MB and 524288MB, got {$this->memoryMb}");
        }

        if ($this->diskGb < 1 || $this->diskGb > 16384) {
            throw new \InvalidArgumentException("Disk size must be between 1GB and 16384GB, got {$this->diskGb}");
        }
    }

    /**
     * Format features for Proxmox API
     *
     * @param array<string, mixed> $features
     * @return string
     */
    private function formatFeatures(array $features): string
    {
        $formatted = [];
        foreach ($features as $key => $value) {
            if (is_bool($value)) {
                $formatted[] = $key . '=' . ($value ? '1' : '0');
            } else {
                $formatted[] = $key . '=' . $value;
            }
        }
        return implode(',', $formatted);
    }

    /**
     * Get resource summary
     *
     * @return array<string, mixed>
     */
    public function getResourceSummary(): array
    {
        return [
            'cores' => $this->cores,
            'memory_mb' => $this->memoryMb,
            'memory_gb' => round($this->memoryMb / 1024, 2),
            'disk_gb' => $this->diskGb,
            'total_cost' => $this->calculateCost(),
        ];
    }

    /**
     * Calculate estimated resource cost (arbitrary units)
     *
     * @return float
     */
    private function calculateCost(): float
    {
        return ($this->cores * 10) + ($this->memoryMb / 1024 * 5) + ($this->diskGb * 1);
    }
}
