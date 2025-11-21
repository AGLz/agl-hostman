<?php

declare(strict_types=1);

namespace App\DTOs\Archon;

use Carbon\Carbon;

readonly class TaskDTO
{
    public function __construct(
        public string $id,
        public string $projectId,
        public string $title,
        public ?string $description,
        public string $status, // todo, doing, review, done
        public ?string $assignee,
        public ?int $taskOrder,
        public ?string $feature,
        public Carbon $createdAt,
        public ?Carbon $updatedAt = null,
    ) {}

    public static function fromArray(array $data): self
    {
        return new self(
            id: $data['id'],
            projectId: $data['project_id'],
            title: $data['title'],
            description: $data['description'] ?? null,
            status: $data['status'],
            assignee: $data['assignee'] ?? null,
            taskOrder: $data['task_order'] ?? null,
            feature: $data['feature'] ?? null,
            createdAt: Carbon::parse($data['created_at']),
            updatedAt: isset($data['updated_at']) ? Carbon::parse($data['updated_at']) : null,
        );
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'project_id' => $this->projectId,
            'title' => $this->title,
            'description' => $this->description,
            'status' => $this->status,
            'assignee' => $this->assignee,
            'task_order' => $this->taskOrder,
            'feature' => $this->feature,
            'created_at' => $this->createdAt->toIso8601String(),
            'updated_at' => $this->updatedAt?->toIso8601String(),
        ];
    }

    public function isTodo(): bool
    {
        return $this->status === 'todo';
    }

    public function isDoing(): bool
    {
        return $this->status === 'doing';
    }

    public function isInReview(): bool
    {
        return $this->status === 'review';
    }

    public function isDone(): bool
    {
        return $this->status === 'done';
    }
}
