<?php

declare(strict_types=1);

namespace App\DTOs\Archon;

use Carbon\Carbon;

readonly class DocumentDTO
{
    public function __construct(
        public string $id,
        public string $projectId,
        public string $title,
        public string $documentType, // spec, design, note, prp, api, guide
        public mixed $content,
        public ?array $tags,
        public ?string $author,
        public Carbon $createdAt,
        public ?Carbon $updatedAt = null,
    ) {}

    public static function fromArray(array $data): self
    {
        return new self(
            id: $data['id'],
            projectId: $data['project_id'],
            title: $data['title'],
            documentType: $data['document_type'],
            content: $data['content'],
            tags: $data['tags'] ?? null,
            author: $data['author'] ?? null,
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
            'document_type' => $this->documentType,
            'content' => $this->content,
            'tags' => $this->tags,
            'author' => $this->author,
            'created_at' => $this->createdAt->toIso8601String(),
            'updated_at' => $this->updatedAt?->toIso8601String(),
        ];
    }
}
