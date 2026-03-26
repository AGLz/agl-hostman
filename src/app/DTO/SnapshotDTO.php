<?php

declare(strict_types=1);

namespace App\DTO;

/**
 * Container Snapshot DTO
 *
 * Immutable data transfer object for snapshot metadata.
 */
readonly class SnapshotDTO
{
    /**
     * @param  int  $vmid  Container VMID
     * @param  string  $name  Snapshot name
     * @param  string|null  $description  Snapshot description
     * @param  \DateTimeImmutable|null  $createdAt  Snapshot creation time
     * @param  array<string, mixed>  $config  Snapshot configuration
     * @param  int|null  $sizeMb  Snapshot size in MB
     * @param  string|null  $parentName  Parent snapshot name
     * @param  array<string, mixed>  $metadata  Additional metadata
     */
    public function __construct(
        public int $vmid,
        public string $name,
        public ?string $description = null,
        public ?\DateTimeImmutable $createdAt = null,
        public array $config = [],
        public ?int $sizeMb = null,
        public ?string $parentName = null,
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
            vmid: (int) ($data['vmid'] ?? throw new \InvalidArgumentException('vmid is required')),
            name: $data['name'] ?? $data['snapname'] ?? throw new \InvalidArgumentException('name is required'),
            description: $data['description'] ?? null,
            createdAt: isset($data['created_at']) ? new \DateTimeImmutable($data['created_at']) : null,
            config: $data['config'] ?? [],
            sizeMb: isset($data['size_mb']) ? (int) $data['size_mb'] : null,
            parentName: $data['parent'] ?? $data['parent_name'] ?? null,
            metadata: $data['metadata'] ?? [],
        );
    }

    /**
     * Create from Proxmox API response
     *
     * @param  array<string, mixed>  $data
     */
    public static function fromProxmoxResponse(int $vmid, array $data): self
    {
        return new self(
            vmid: $vmid,
            name: $data['name'] ?? throw new \InvalidArgumentException('name is required'),
            description: $data['description'] ?? null,
            createdAt: isset($data['snaptime']) ? new \DateTimeImmutable('@'.$data['snaptime']) : null,
            config: $data['config'] ?? [],
            sizeMb: isset($data['size']) ? (int) ($data['size'] / 1024 / 1024) : null,
            parentName: $data['parent'] ?? null,
            metadata: [],
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
            'snapname' => $this->name,
        ];

        if ($this->description) {
            $params['description'] = $this->description;
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
            'container_id' => null, // Set by caller
            'name' => $this->name,
            'description' => $this->description,
            'size_mb' => $this->sizeMb,
            'parent_name' => $this->parentName,
            'config' => $this->config,
            'metadata' => $this->metadata,
            'created_at' => $this->createdAt,
        ];
    }

    /**
     * Validate configuration
     *
     * @throws \InvalidArgumentException
     */
    private function validate(): void
    {
        // Validate snapshot name (no spaces, special chars)
        if (! preg_match('/^[a-zA-Z0-9_-]{1,40}$/', $this->name)) {
            throw new \InvalidArgumentException(
                "Invalid snapshot name: {$this->name}. Must be alphanumeric with hyphens/underscores, max 40 chars."
            );
        }

        if ($this->sizeMb !== null && $this->sizeMb < 0) {
            throw new \InvalidArgumentException("Size cannot be negative: {$this->sizeMb}");
        }
    }

    /**
     * Get age in days
     */
    public function getAgeDays(): ?int
    {
        if (! $this->createdAt) {
            return null;
        }

        return (new \DateTimeImmutable)->diff($this->createdAt)->days;
    }

    /**
     * Check if snapshot is recent (< 7 days)
     */
    public function isRecent(): bool
    {
        $age = $this->getAgeDays();

        return $age !== null && $age < 7;
    }

    /**
     * Check if snapshot is old (> 30 days)
     */
    public function isOld(): bool
    {
        $age = $this->getAgeDays();

        return $age !== null && $age > 30;
    }

    /**
     * Get formatted age
     */
    public function getFormattedAge(): ?string
    {
        if (! $this->createdAt) {
            return null;
        }

        $now = new \DateTimeImmutable;
        $diff = $now->diff($this->createdAt);

        if ($diff->days > 30) {
            return sprintf('%d months ago', (int) ($diff->days / 30));
        }

        if ($diff->days > 0) {
            return sprintf('%d days ago', $diff->days);
        }

        if ($diff->h > 0) {
            return sprintf('%d hours ago', $diff->h);
        }

        return sprintf('%d minutes ago', $diff->i);
    }
}
