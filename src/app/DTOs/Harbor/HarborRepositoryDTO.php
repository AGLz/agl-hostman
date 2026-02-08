<?php

declare(strict_types=1);

namespace App\DTOs\Harbor;

use Illuminate\Contracts\Arrayable;

/**
 * Harbor Repository DTO
 *
 * Data Transfer Object for Harbor repositories
 */
class HarborRepositoryDTO implements Arrayable
{
    public function __construct(
        public readonly ?int $id = null,
        public readonly ?string $name = null,
        public readonly ?string $projectName = null,
        public readonly ?string $description = null,
        public readonly ?int $pullCount = null,
        public readonly ?int $artifactCount = null,
        public readonly ?int $artifactSizeBytes = null,
        public readonly ?string $lastPushAt = null,
        public readonly ?array $metadata = null,
    ) {}

    /**
     * Create from array
     */
    public static function fromArray(array $data): self
    {
        return new self(
            id: $data['id'] ?? null,
            name: $data['name'] ?? null,
            projectName: $data['project_name'] ?? null,
            description: $data['description'] ?? null,
            pullCount: $data['pull_count'] ?? 0,
            artifactCount: $data['artifact_count'] ?? 0,
            artifactSizeBytes: null, // Not returned in list view
            lastPushAt: $data['creation_time'] ?? $data['update_time'] ?? null,
            metadata: $data['metadata'] ?? null,
        );
    }

    /**
     * Convert to array
     */
    public function toArray(): array
    {
        return array_filter([
            'id' => $this->id,
            'name' => $this->name,
            'project_name' => $this->projectName,
            'description' => $this->description,
            'pull_count' => $this->pullCount,
            'artifact_count' => $this->artifactCount,
            'artifact_size_bytes' => $this->artifactSizeBytes,
            'creation_time' => $this->lastPushAt,
            'metadata' => $this->metadata,
        ], fn($value) => $value !== null);
    }
}
