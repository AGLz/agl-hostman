<?php

declare(strict_types=1);

namespace App\DTO;

/**
 * Container Clone Configuration DTO
 *
 * Immutable data transfer object for container cloning parameters.
 */
readonly class ContainerCloneDTO
{
    /**
     * @param  int  $sourceVmid  Source container VMID
     * @param  int  $targetVmid  Target container VMID
     * @param  string  $hostname  New hostname for cloned container
     * @param  bool  $full  Full clone (true) or linked clone (false)
     * @param  string|null  $storage  Target storage for full clone
     * @param  string|null  $description  Description for cloned container
     * @param  bool  $startAfterClone  Start container after clone completion
     * @param  array<string, mixed>  $metadata  Custom metadata tags
     */
    public function __construct(
        public int $sourceVmid,
        public int $targetVmid,
        public string $hostname,
        public bool $full = true,
        public ?string $storage = 'local-lvm',
        public ?string $description = null,
        public bool $startAfterClone = false,
        public array $metadata = [],
    ) {
        $this->validate();
    }

    /**
     * Create from array
     *
     * @param  array<string, mixed>  $data
     */
    public static function fromArray(array $data): self
    {
        return new self(
            sourceVmid: (int) ($data['source_vmid'] ?? $data['vmid'] ?? throw new \InvalidArgumentException('source_vmid is required')),
            targetVmid: (int) ($data['target_vmid'] ?? $data['newid'] ?? throw new \InvalidArgumentException('target_vmid is required')),
            hostname: $data['hostname'] ?? throw new \InvalidArgumentException('hostname is required'),
            full: (bool) ($data['full'] ?? $data['full_clone'] ?? true),
            storage: $data['storage'] ?? 'local-lvm',
            description: $data['description'] ?? null,
            startAfterClone: (bool) ($data['start'] ?? $data['start_after_clone'] ?? false),
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
            'newid' => $this->targetVmid,
            'hostname' => $this->hostname,
            'full' => $this->full ? 1 : 0,
        ];

        if ($this->full && $this->storage) {
            $params['storage'] = $this->storage;
        }

        if ($this->description) {
            $params['description'] = $this->description;
        }

        return $params;
    }

    /**
     * Validate configuration
     *
     * @throws \InvalidArgumentException
     */
    private function validate(): void
    {
        if ($this->sourceVmid === $this->targetVmid) {
            throw new \InvalidArgumentException("Source and target VMID cannot be the same: {$this->sourceVmid}");
        }

        if ($this->sourceVmid < 100 || $this->sourceVmid > 999999999) {
            throw new \InvalidArgumentException("Invalid source VMID: {$this->sourceVmid}");
        }

        if ($this->targetVmid < 100 || $this->targetVmid > 999999999) {
            throw new \InvalidArgumentException("Invalid target VMID: {$this->targetVmid}");
        }

        // Validate hostname format
        if (! preg_match('/^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/i', $this->hostname)) {
            throw new \InvalidArgumentException("Invalid hostname format: {$this->hostname}");
        }

        if ($this->full && ! $this->storage) {
            throw new \InvalidArgumentException('Storage is required for full clone');
        }
    }

    /**
     * Get clone type
     */
    public function getCloneType(): string
    {
        return $this->full ? 'full' : 'linked';
    }
}
