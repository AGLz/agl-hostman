<?php

declare(strict_types=1);

namespace App\DTOs\Harbor;

use Illuminate\Contracts\Arrayable;

/**
 * Harbor Project DTO
 *
 * Data Transfer Object for Harbor projects
 */
class HarborProjectDTO implements Arrayable
{
    public function __construct(
        public readonly ?int $projectId = null,
        public readonly ?string $name = null,
        public readonly ?int $ownerId = null,
        public readonly ?string $ownerName = null,
        public readonly ?bool $public = false,
        public readonly ?array $metadata = null,
        public readonly ?array $cveAllowlist = null,
        public readonly ?bool $preventVul = false,
        public readonly ?string $severity = 'medium',
        public readonly ?bool $autoScan = true,
        public readonly ?bool $enableContentTrust = false,
        public readonly ?bool $enableContentTrustCI = false,
        public readonly ?int $storageQuota = null,
        public readonly ?int $storageUsed = null,
        public readonly ?string $createdAt = null,
        public readonly ?string $updatedAt = null,
    ) {}

    /**
     * Create from array
     */
    public static function fromArray(array $data): self
    {
        return new self(
            projectId: $data['project_id'] ?? $data['id'] ?? null,
            name: $data['name'] ?? null,
            ownerId: $data['owner_id'] ?? null,
            ownerName: $data['owner_name'] ?? null,
            public: $data['public'] ?? false,
            metadata: $data['metadata'] ?? null,
            cveAllowlist: $data['cve_allowlist'] ?? null,
            preventVul: $data['prevent_vul'] ?? false,
            severity: $data['metadata']['severity'] ?? 'medium',
            autoScan: $data['metadata']['auto_scan'] ?? true,
            enableContentTrust: $data['metadata']['enable_content_trust'] ?? false,
            enableContentTrustCI: $data['metadata']['enable_content_trust_ci'] ?? false,
            storageQuota: $data['storage_quota']['hard']['value'] ?? null,
            storageUsed: null, // Not returned in list view
            createdAt: $data['creation_time'] ?? null,
            updatedAt: $data['update_time'] ?? null,
        );
    }

    /**
     * Convert to array
     */
    public function toArray(): array
    {
        return array_filter([
            'project_id' => $this->projectId,
            'id' => $this->projectId,
            'name' => $this->name,
            'owner_id' => $this->ownerId,
            'owner_name' => $this->ownerName,
            'public' => $this->public,
            'metadata' => $this->metadata,
            'cve_allowlist' => $this->cveAllowlist,
            'prevent_vul' => $this->preventVul,
            'severity' => $this->severity,
            'auto_scan' => $this->autoScan,
            'enable_content_trust' => $this->enableContentTrust,
            'enable_content_trust_ci' => $this->enableContentTrustCI,
            'storage_quota' => $this->storageQuota,
            'storage_used' => $this->storageUsed,
            'creation_time' => $this->createdAt,
            'update_time' => $this->updatedAt,
        ], fn ($value) => $value !== null);
    }
}
