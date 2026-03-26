<?php

declare(strict_types=1);

namespace App\DTOs\Harbor;

use Illuminate\Contracts\Arrayable;

/**
 * Harbor Artifact DTO
 *
 * Data Transfer Object for Harbor artifacts (images)
 */
class HarborArtifactDTO implements Arrayable
{
    public function __construct(
        public readonly ?string $digest = null,
        public readonly ?string $tag = null,
        public readonly ?string $manifestMediaType = null,
        public readonly ?string $configMediaType = null,
        public readonly ?int $sizeBytes = null,
        public readonly ?string $pushedAt = null,
        public readonly ?string $pulledAt = null,
        public readonly ?array $scanOverview = null,
        public readonly ?string $scanStatus = null,
        public readonly ?array $labels = null,
        public readonly ?array $annotations = null,
        public readonly ?array $references = null,
        public readonly ?array $icon = null,
    ) {}

    /**
     * Create from array
     */
    public static function fromArray(array $data): self
    {
        return new self(
            digest: $data['digest'] ?? null,
            tag: isset($data['tags']) && ! empty($data['tags'])
                ? $data['tags'][0]['name']
                : 'latest',
            manifestMediaType: $data['manifest_media_type'] ?? null,
            configMediaType: $data['config_media_type'] ?? null,
            sizeBytes: $data['size'] ?? null,
            pushedAt: $data['push_time'] ?? null,
            pulledAt: $data['pull_time'] ?? null,
            scanOverview: $data['scan_overview'] ?? null,
            scanStatus: $data['scan_status'] ?? null,
            labels: $data['labels'] ?? null,
            annotations: $data['annotations'] ?? null,
            references: $data['references'] ?? null,
            icon: $data['icon'] ?? null,
        );
    }

    /**
     * Convert to array
     */
    public function toArray(): array
    {
        return array_filter([
            'digest' => $this->digest,
            'tag' => $this->tag,
            'manifest_media_type' => $this->manifestMediaType,
            'config_media_type' => $this->configMediaType,
            'size' => $this->sizeBytes,
            'push_time' => $this->pushedAt,
            'pull_time' => $this->pulledAt,
            'scan_overview' => $this->scanOverview,
            'scan_status' => $this->scanStatus,
            'labels' => $this->labels,
            'annotations' => $this->annotations,
            'references' => $this->references,
            'icon' => $this->icon,
        ], fn ($value) => $value !== null);
    }
}
