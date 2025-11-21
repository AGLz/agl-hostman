<?php

declare(strict_types=1);

namespace App\DTOs\Dokploy;

/**
 * Dokploy Log Data Transfer Object
 *
 * Represents deployment logs and container output
 */
readonly class LogDTO
{
    public function __construct(
        public ?string $applicationId = null,
        public ?string $deploymentId = null,
        public ?string $timestamp = null,
        public ?string $level = null, // info, warn, error, debug
        public ?string $message = null,
        public ?string $source = null, // build, runtime, system
        public ?array $metadata = null,
        public ?string $stream = null, // stdout, stderr
    ) {}

    public static function fromArray(array $data): self
    {
        return new self(
            applicationId: $data['applicationId'] ?? null,
            deploymentId: $data['deploymentId'] ?? null,
            timestamp: $data['timestamp'] ?? null,
            level: $data['level'] ?? null,
            message: $data['message'] ?? null,
            source: $data['source'] ?? null,
            metadata: $data['metadata'] ?? null,
            stream: $data['stream'] ?? null,
        );
    }

    public function toArray(): array
    {
        return array_filter([
            'applicationId' => $this->applicationId,
            'deploymentId' => $this->deploymentId,
            'timestamp' => $this->timestamp,
            'level' => $this->level,
            'message' => $this->message,
            'source' => $this->source,
            'metadata' => $this->metadata,
            'stream' => $this->stream,
        ], fn($value) => $value !== null);
    }

    public function isError(): bool
    {
        return $this->level === 'error' || $this->stream === 'stderr';
    }

    public function isWarning(): bool
    {
        return $this->level === 'warn';
    }

    public function isInfo(): bool
    {
        return $this->level === 'info';
    }
}
