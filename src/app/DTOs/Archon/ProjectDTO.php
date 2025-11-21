<?php

declare(strict_types=1);

namespace App\DTOs\Archon;

use Carbon\Carbon;

readonly class ProjectDTO
{
    public function __construct(
        public string $id,
        public string $title,
        public ?string $description,
        public ?string $githubRepo,
        public ?string $organizationId,
        public Carbon $createdAt,
        public ?Carbon $updatedAt = null,
    ) {}

    public static function fromArray(array $data): self
    {
        return new self(
            id: $data['id'],
            title: $data['title'],
            description: $data['description'] ?? null,
            githubRepo: $data['github_repo'] ?? null,
            organizationId: $data['organization_id'] ?? null,
            createdAt: Carbon::parse($data['created_at']),
            updatedAt: isset($data['updated_at']) ? Carbon::parse($data['updated_at']) : null,
        );
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'description' => $this->description,
            'github_repo' => $this->githubRepo,
            'organization_id' => $this->organizationId,
            'created_at' => $this->createdAt->toIso8601String(),
            'updated_at' => $this->updatedAt?->toIso8601String(),
        ];
    }
}
