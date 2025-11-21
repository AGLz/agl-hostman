<?php

declare(strict_types=1);

namespace App\DTOs\Archon;

readonly class KnowledgeSearchResultDTO
{
    public function __construct(
        public ?string $pageId,
        public ?string $url,
        public ?string $title,
        public ?string $content,
        public ?string $preview,
        public ?float $similarity,
        public ?int $wordCount,
        public ?int $chunkMatches,
        public ?array $metadata,
    ) {}

    public static function fromArray(array $data): self
    {
        return new self(
            pageId: $data['page_id'] ?? null,
            url: $data['url'] ?? null,
            title: $data['title'] ?? null,
            content: $data['content'] ?? null,
            preview: $data['preview'] ?? null,
            similarity: isset($data['similarity']) ? (float) $data['similarity'] : null,
            wordCount: $data['word_count'] ?? null,
            chunkMatches: $data['chunk_matches'] ?? null,
            metadata: $data['metadata'] ?? null,
        );
    }

    public function toArray(): array
    {
        return [
            'page_id' => $this->pageId,
            'url' => $this->url,
            'title' => $this->title,
            'content' => $this->content,
            'preview' => $this->preview,
            'similarity' => $this->similarity,
            'word_count' => $this->wordCount,
            'chunk_matches' => $this->chunkMatches,
            'metadata' => $this->metadata,
        ];
    }
}
