<?php

declare(strict_types=1);

namespace App\DTOs\Dokploy;

use Illuminate\Support\Collection;

/**
 * Dokploy Project Data Transfer Object
 *
 * Represents a project in Dokploy with all its configuration
 */
readonly class ProjectDTO
{
    public function __construct(
        public ?string $projectId = null,
        public string $name = '',
        public ?string $description = null,
        public ?Collection $environmentIds = null,
        public ?string $createdAt = null,
        public ?string $organizationId = null,
        public ?string $env = null,
    ) {}

    /**
     * Create DTO from array data
     */
    public static function fromArray(array $data): self
    {
        return new self(
            projectId: $data['projectId'] ?? null,
            name: $data['name'] ?? '',
            description: $data['description'] ?? null,
            environmentIds: isset($data['environmentIds'])
                ? collect($data['environmentIds'])
                : null,
            createdAt: $data['createdAt'] ?? null,
            organizationId: $data['organizationId'] ?? null,
            env: $data['env'] ?? null,
        );
    }

    /**
     * Convert DTO to array for API requests
     */
    public function toArray(): array
    {
        return array_filter([
            'projectId' => $this->projectId,
            'name' => $this->name,
            'description' => $this->description,
            'environmentIds' => $this->environmentIds?->toArray(),
            'createdAt' => $this->createdAt,
            'organizationId' => $this->organizationId,
            'env' => $this->env,
        ], fn ($value) => $value !== null);
    }

    /**
     * Create DTO for project creation
     */
    public static function forCreate(
        string $name,
        ?string $description = null,
        ?string $env = null
    ): self {
        return new self(
            name: $name,
            description: $description,
            env: $env,
        );
    }

    /**
     * Create DTO for project update
     */
    public static function forUpdate(
        string $projectId,
        ?string $name = null,
        ?string $description = null,
        ?string $env = null
    ): self {
        return new self(
            projectId: $projectId,
            name: $name ?? '',
            description: $description,
            env: $env,
        );
    }
}
