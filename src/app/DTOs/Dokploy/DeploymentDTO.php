<?php

declare(strict_types=1);

namespace App\DTOs\Dokploy;

/**
 * Dokploy Deployment Data Transfer Object
 *
 * Represents deployment metadata and status
 */
readonly class DeploymentDTO
{
    public function __construct(
        public ?string $deploymentId = null,
        public ?string $applicationId = null,
        public ?string $status = null, // pending, building, deploying, success, failed
        public ?string $title = null,
        public ?string $description = null,
        public ?string $commitHash = null,
        public ?string $branch = null,
        public ?string $tag = null,
        public ?string $triggeredBy = null,
        public ?string $startedAt = null,
        public ?string $completedAt = null,
        public ?string $errorMessage = null,
        public ?array $metadata = null,
    ) {}

    public static function fromArray(array $data): self
    {
        return new self(
            deploymentId: $data['deploymentId'] ?? null,
            applicationId: $data['applicationId'] ?? null,
            status: $data['status'] ?? null,
            title: $data['title'] ?? null,
            description: $data['description'] ?? null,
            commitHash: $data['commitHash'] ?? null,
            branch: $data['branch'] ?? null,
            tag: $data['tag'] ?? null,
            triggeredBy: $data['triggeredBy'] ?? null,
            startedAt: $data['startedAt'] ?? null,
            completedAt: $data['completedAt'] ?? null,
            errorMessage: $data['errorMessage'] ?? null,
            metadata: $data['metadata'] ?? null,
        );
    }

    public function toArray(): array
    {
        return array_filter([
            'deploymentId' => $this->deploymentId,
            'applicationId' => $this->applicationId,
            'status' => $this->status,
            'title' => $this->title,
            'description' => $this->description,
            'commitHash' => $this->commitHash,
            'branch' => $this->branch,
            'tag' => $this->tag,
            'triggeredBy' => $this->triggeredBy,
            'startedAt' => $this->startedAt,
            'completedAt' => $this->completedAt,
            'errorMessage' => $this->errorMessage,
            'metadata' => $this->metadata,
        ], fn ($value) => $value !== null);
    }

    public static function forDeploy(
        string $applicationId,
        ?string $title = null,
        ?string $description = null
    ): self {
        return new self(
            applicationId: $applicationId,
            title: $title,
            description: $description,
        );
    }

    public function isSuccessful(): bool
    {
        return $this->status === 'success';
    }

    public function isFailed(): bool
    {
        return $this->status === 'failed';
    }

    public function isInProgress(): bool
    {
        return in_array($this->status, ['pending', 'building', 'deploying']);
    }
}
